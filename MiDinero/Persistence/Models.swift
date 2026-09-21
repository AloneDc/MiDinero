import Foundation
import SwiftData

@Model
final class FinancialTransaction {
    @Attribute(.unique) var id: UUID
    var amountMinorUnits: Int64
    var currencyCode: String
    var currencyFractionDigits: Int
    var typeRawValue: String
    var categoryID: String
    var note: String?
    var date: Date
    var createdAt: Date

    init(id: UUID = UUID(), money: Money, type: TransactionType, categoryID: String,
         note: String?, date: Date, createdAt: Date = .now) {
        self.id = id
        amountMinorUnits = money.minorUnits
        currencyCode = money.currency.code
        currencyFractionDigits = money.currency.fractionDigits
        typeRawValue = type.rawValue
        self.categoryID = categoryID
        self.note = note
        self.date = date
        self.createdAt = createdAt
    }
}

@Model
final class Category {
    @Attribute(.unique) var id: String
    var name: String
    var symbol: String
    var sortOrder: Int
    var isBuiltIn: Bool

    init(info: CategoryInfo, isBuiltIn: Bool = true) {
        id = info.id
        name = info.name
        symbol = info.symbol
        sortOrder = info.sortOrder
        self.isBuiltIn = isBuiltIn
    }

    var info: CategoryInfo { .init(id: id, name: name, symbol: symbol, sortOrder: sortOrder) }
}
