import SwiftData
import XCTest
@testable import MiDinero

final class PersistenceTests: XCTestCase {
    @MainActor
    func testSavedIncomeAndExpenseFeedMonthlyBalance() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let repository = TransactionRepository(container: container)
        let date = try Fixtures.date("2026-09-15T12:00:00-05:00")
        try repository.save(TransactionDraft(amountText: "100", type: .income, categoryID: "other", date: date))
        try repository.save(TransactionDraft(amountText: "12.50", categoryID: "food", date: date))
        let records = try TransactionRepository(container: container).records()
        XCTAssertEqual(records.filter { $0.type == .income }.count, 1)
        let summary = MonthlySummary.build(records: records, month: date, calendar: Fixtures.calendar)
        XCTAssertEqual(summary.income, 100)
        XCTAssertEqual(summary.expense, Decimal(string: "12.50"))
        XCTAssertEqual(summary.balance, Decimal(string: "87.50"))
        XCTAssertEqual(summary.transactionCount, 2)
    }

    @MainActor
    func testIntentWriteSurvivesReopeningAndFeedsAllSummaries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let note = "Persistencia desde el intent"
        try autoreleasepool {
            let container = try PersistenceController.makeContainer(url: url)
            let repository = TransactionRepository(container: container)
            _ = try ExpenseIntentWriter.save(amount: "12,50", categoryID: "food", note: note, repository: repository)
        }
        let reopened = try PersistenceController.makeContainer(url: url)
        let repository = TransactionRepository(container: reopened)
        let records = try repository.records()
        XCTAssertEqual(records.count, 1)
        let saved = try XCTUnwrap(records.first)
        XCTAssertEqual(saved.money.minorUnits, 1250)
        XCTAssertEqual(saved.note, note)
        XCTAssertEqual(saved.type, .expense)
        let summary = MonthlySummary.build(records: records, month: saved.date)
        XCTAssertEqual(summary.expense, Decimal(string: "12.5"))
        XCTAssertEqual(summary.transactionCount, 1)
        XCTAssertEqual(summary.leadingCategory?.category.id, "food")
    }

    @MainActor
    func testEditingPreservesIdentityAndCreationDateThenDeletionPersists() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let repository = TransactionRepository(container: container)
        let id = try repository.save(TransactionDraft(amountText: "4", categoryID: "food"))
        let original = try XCTUnwrap(repository.records().first)
        let oldDate = try Fixtures.date("2025-12-01T12:00:00-05:00")
        try repository.save(TransactionDraft(amountText: "25.10", type: .income, categoryID: "other", note: " Cambio ", date: oldDate), editing: id)
        let edited = try XCTUnwrap(repository.records().first)
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.createdAt, original.createdAt)
        XCTAssertEqual(edited.date, oldDate)
        XCTAssertEqual(edited.money.minorUnits, 2510)
        XCTAssertEqual(edited.type, .income)
        XCTAssertEqual(edited.note, "Cambio")
        try repository.delete(id: id)
        XCTAssertTrue(try TransactionRepository(container: container).records().isEmpty)
        XCTAssertThrowsError(try repository.delete(id: id))
    }

    @MainActor
    func testSeedingIsIdempotentAndFreshContextsSeeWrites() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let app = TransactionRepository(container: container)
        let intent = TransactionRepository(container: container)
        try app.seedCategories()
        try intent.seedCategories()
        XCTAssertEqual(try app.categories().count, 10)
        XCTAssertTrue(try app.records().isEmpty)
        _ = try ExpenseIntentWriter.save(amount: "8", categoryID: "transport", note: nil, repository: intent)
        XCTAssertEqual(try app.records().count, 1)
    }

    @MainActor
    func testInvalidWritesDoNotCreateTransactions() throws {
        let repository = TransactionRepository(container: try PersistenceController.makeContainer(inMemory: true))
        XCTAssertThrowsError(try repository.save(TransactionDraft(amountText: "0", categoryID: "food")))
        XCTAssertThrowsError(try repository.save(TransactionDraft(amountText: "8", categoryID: "missing")))
        XCTAssertThrowsError(try repository.save(TransactionDraft(amountText: "8", categoryID: "food", note: String(repeating: "x", count: 501))))
        XCTAssertThrowsError(try ExpenseIntentWriter.save(amount: "1,000", categoryID: "food", note: nil, repository: repository))
        XCTAssertTrue(try repository.records().isEmpty)
    }

    @MainActor
    func testInvalidEditDoesNotAlterPreviouslySavedEntry() throws {
        let repository = TransactionRepository(container: try PersistenceController.makeContainer(inMemory: true))
        let id = try repository.save(TransactionDraft(amountText: "8", categoryID: "food"))
        XCTAssertThrowsError(try repository.save(TransactionDraft(amountText: "99", categoryID: "missing"), editing: id))
        XCTAssertEqual(try repository.records().first?.money.minorUnits, 800)
    }

    @MainActor
    func testStorageErrorPropagatesInsteadOfFallingBackToMemory() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try PersistenceController.makeContainer(url: file.appendingPathComponent("store")))
    }
}
