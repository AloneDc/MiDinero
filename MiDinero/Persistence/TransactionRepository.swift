import Foundation
import SwiftData

extension Notification.Name {
    static let ledgerDidChange = Notification.Name("MiDinero.ledgerDidChange")
}

@MainActor
final class TransactionRepository {
    private let container: ModelContainer

    init(container: ModelContainer) { self.container = container }

    // Contexts and models never leave the main actor. Fresh contexts also avoid stale
    // registered objects when the app resumes after an App Intent write.
    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    func seedCategories() throws {
        let context = makeContext()
        let existing = Set(try context.fetch(FetchDescriptor<Category>()).map(\.id))
        for info in CategoryInfo.defaults where !existing.contains(info.id) {
            context.insert(Category(info: info))
        }
        if context.hasChanges { try context.save() }
    }

    func categories() throws -> [CategoryInfo] {
        try seedCategories()
        let context = makeContext()
        return try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]))
            .map(\.info)
    }

    func records() throws -> [TransactionRecord] {
        let context = makeContext()
        let categories = try context.fetch(FetchDescriptor<Category>())
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.info) })
        let transactions = try context.fetch(FetchDescriptor<FinancialTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        ))
        return try transactions.map { model in
            guard let type = TransactionType(rawValue: model.typeRawValue),
                  let category = byID[model.categoryID],
                  (0...6).contains(model.currencyFractionDigits),
                  model.amountMinorUnits > 0, model.amountMinorUnits <= Money.maximumMinorUnits,
                  !model.currencyCode.isEmpty else { throw LedgerError.invalidStoredData }
            return TransactionRecord(
                id: model.id,
                money: Money(minorUnits: model.amountMinorUnits, currency: Currency(
                    code: model.currencyCode, fractionDigits: model.currencyFractionDigits
                )),
                type: type, category: category, note: model.note, date: model.date, createdAt: model.createdAt
            )
        }
    }

    @discardableResult
    func save(_ draft: TransactionDraft, editing id: UUID? = nil) throws -> UUID {
        let money = try draft.validatedMoney()
        try seedCategories()
        let context = makeContext()
        let categoryID = draft.categoryID
        var categoryRequest = FetchDescriptor<Category>(predicate: #Predicate { $0.id == categoryID })
        categoryRequest.fetchLimit = 1
        guard try context.fetch(categoryRequest).first != nil else { throw LedgerError.categoryNotFound }
        let model: FinancialTransaction
        if let id {
            var request = FetchDescriptor<FinancialTransaction>(predicate: #Predicate { $0.id == id })
            request.fetchLimit = 1
            guard let existing = try context.fetch(request).first else { throw LedgerError.transactionNotFound }
            model = existing
            model.amountMinorUnits = money.minorUnits
            model.currencyCode = money.currency.code
            model.currencyFractionDigits = money.currency.fractionDigits
            model.typeRawValue = draft.type.rawValue
            model.categoryID = categoryID
            model.note = draft.normalizedNote
            model.date = draft.date
        } else {
            model = FinancialTransaction(money: money, type: draft.type, categoryID: categoryID,
                                         note: draft.normalizedNote, date: draft.date)
            context.insert(model)
        }
        // Success is published only after the disk save. Failed isolated contexts are discarded.
        try context.save()
        NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
        return model.id
    }

    func delete(id: UUID) throws {
        let context = makeContext()
        var request = FetchDescriptor<FinancialTransaction>(predicate: #Predicate { $0.id == id })
        request.fetchLimit = 1
        guard let model = try context.fetch(request).first else { throw LedgerError.transactionNotFound }
        context.delete(model)
        try context.save()
        NotificationCenter.default.post(name: .ledgerDidChange, object: nil)
    }
}
