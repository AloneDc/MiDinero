import Foundation

enum FinanceCalendar {
    static var current: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }
}

struct CategorySpending: Identifiable, Equatable, Sendable {
    var id: String { category.id }
    let category: CategoryInfo
    let amount: Decimal
    let percentage: Decimal
}

struct MonthlySummary: Sendable {
    let expense: Decimal
    let income: Decimal
    let transactionCount: Int
    let expenseDayCount: Int
    let categories: [CategorySpending]
    let currency: Currency

    var balance: Decimal { income - expense }
    var averagePerExpenseDay: Decimal {
        expenseDayCount == 0 ? 0 : expense / Decimal(expenseDayCount)
    }
    var leadingCategory: CategorySpending? { categories.first }

    static func build(
        records: [TransactionRecord], month: Date, currency: Currency = .pen,
        calendar: Calendar = FinanceCalendar.current
    ) -> MonthlySummary {
        let interval = calendar.dateInterval(of: .month, for: month)
        // A half-open interval prevents the next month's midnight being included twice.
        let selected = records.filter { record in
            guard let interval else { return false }
            return record.money.currency == currency && record.date >= interval.start && record.date < interval.end
        }
        var expense: Decimal = 0
        var income: Decimal = 0
        var days = Set<Date>()
        var grouped: [CategoryInfo: Decimal] = [:]
        for record in selected {
            switch record.type {
            case .expense:
                expense += record.money.decimal
                days.insert(calendar.startOfDay(for: record.date))
                grouped[record.category, default: 0] += record.money.decimal
            case .income:
                income += record.money.decimal
            }
        }
        let categories = grouped.map { category, amount in
            CategorySpending(category: category, amount: amount, percentage: expense == 0 ? 0 : amount * 100 / expense)
        }.sorted {
            if $0.amount == $1.amount { return $0.category.id < $1.category.id }
            return $0.amount > $1.amount
        }
        return MonthlySummary(
            expense: expense, income: income, transactionCount: selected.count,
            expenseDayCount: days.count, categories: categories, currency: currency
        )
    }
}
