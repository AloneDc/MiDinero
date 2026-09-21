import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense, income
    var id: String { rawValue }
    var title: String { self == .expense ? "Gasto" : "Ingreso" }
    var symbol: String { self == .expense ? "arrow.up.right" : "arrow.down.left" }
    var sign: String { self == .expense ? "−" : "+" }
}

struct TransactionRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let money: Money
    let type: TransactionType
    let category: CategoryInfo
    let note: String?
    let date: Date
    let createdAt: Date
}

struct TransactionDraft: Sendable {
    var amountText: String
    var type: TransactionType = .expense
    var categoryID: String
    var note: String = ""
    var date: Date = .now
    var currency: Currency = .pen

    func validatedMoney() throws -> Money {
        guard note.count <= 500 else { throw LedgerError.noteTooLong }
        guard date.timeIntervalSinceReferenceDate.isFinite else { throw LedgerError.invalidDate }
        return try Money.parse(amountText, currency: currency)
    }

    var normalizedNote: String? {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

enum LedgerError: LocalizedError {
    case categoryNotFound, transactionNotFound, noteTooLong, invalidDate, invalidStoredData

    var errorDescription: String? {
        switch self {
        case .categoryNotFound: "La categoría ya no está disponible. Elige otra categoría."
        case .transactionNotFound: "No se encontró el movimiento. Actualiza el historial."
        case .noteTooLong: "La descripción admite hasta 500 caracteres."
        case .invalidDate: "La fecha no es válida."
        case .invalidStoredData: "No se pudieron interpretar los datos guardados. No se han modificado."
        }
    }
}
