import Foundation
#if SWIFT_PACKAGE
@testable import MiDineroCore
#else
@testable import MiDinero
#endif

enum Fixtures {
    static let food = CategoryInfo(id: "food", name: "Comida", symbol: "fork.knife", sortOrder: 0)
    static let transport = CategoryInfo(id: "transport", name: "Transporte", symbol: "bus", sortOrder: 1)

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }

    static func date(_ text: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: text) else { throw FixtureError.invalidDate }
        return date
    }

    static func record(_ amount: String, type: TransactionType = .expense,
                       category: CategoryInfo = food, date: String = "2026-09-15T12:00:00-05:00",
                       note: String? = nil, currency: Currency = .pen) throws -> TransactionRecord {
        let day = try self.date(date)
        return TransactionRecord(id: UUID(), money: try Money.parse(amount, currency: currency),
                                 type: type, category: category, note: note, date: day, createdAt: day)
    }

    enum FixtureError: Error { case invalidDate }
}
