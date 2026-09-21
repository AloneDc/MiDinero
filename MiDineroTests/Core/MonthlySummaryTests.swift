import XCTest
#if SWIFT_PACKAGE
@testable import MiDineroCore
#else
@testable import MiDinero
#endif

final class MonthlySummaryTests: XCTestCase {
    func testTotalsCategoriesAndExpenseDays() throws {
        let records = try [
            Fixtures.record("12.50"), Fixtures.record("7.50"),
            Fixtures.record("10", category: Fixtures.transport, date: "2026-09-16T12:00:00-05:00"),
            Fixtures.record("100", type: .income, date: "2026-09-17T12:00:00-05:00")
        ]
        let summary = MonthlySummary.build(records: records, month: try Fixtures.date("2026-09-01T00:00:00-05:00"), calendar: Fixtures.calendar)
        XCTAssertEqual(summary.expense, 30)
        XCTAssertEqual(summary.income, 100)
        XCTAssertEqual(summary.balance, 70)
        XCTAssertEqual(summary.transactionCount, 4)
        XCTAssertEqual(summary.expenseDayCount, 2)
        XCTAssertEqual(summary.averagePerExpenseDay, 15)
        XCTAssertEqual(summary.leadingCategory?.category.id, "food")
        XCTAssertEqual(summary.leadingCategory?.amount, 20)
        XCTAssertEqual(summary.categories.last?.amount, 10)
        XCTAssertEqual(summary.leadingCategory?.percentage, Decimal(20) * 100 / 30)
    }

    func testMonthBoundariesUseLocalTimezoneAndExcludeEnd() throws {
        let records = try [
            Fixtures.record("1", date: "2026-09-01T04:59:59Z"), // August in Lima
            Fixtures.record("2", date: "2026-09-01T05:00:00Z"),
            Fixtures.record("4", date: "2026-10-01T04:59:59Z"),
            Fixtures.record("8", date: "2026-10-01T05:00:00Z")
        ]
        let summary = MonthlySummary.build(records: records, month: try Fixtures.date("2026-09-15T00:00:00-05:00"), calendar: Fixtures.calendar)
        XCTAssertEqual(summary.expense, 6)
        XCTAssertEqual(summary.transactionCount, 2)
    }

    func testLeapYearAndYearBoundary() throws {
        let leap = try [Fixtures.record("3", date: "2024-02-29T23:59:59-05:00"), Fixtures.record("8", date: "2024-03-01T00:00:00-05:00")]
        XCTAssertEqual(MonthlySummary.build(records: leap, month: try Fixtures.date("2024-02-15T12:00:00-05:00"), calendar: Fixtures.calendar).expense, 3)
        let year = try [Fixtures.record("5", date: "2025-12-31T23:59:59-05:00"), Fixtures.record("9", date: "2026-01-01T00:00:00-05:00")]
        XCTAssertEqual(MonthlySummary.build(records: year, month: try Fixtures.date("2025-12-01T12:00:00-05:00"), calendar: Fixtures.calendar).expense, 5)
    }

    func testEmptyAndIncomeOnlyMonthsDoNotDivideByZero() throws {
        let month = try Fixtures.date("2026-09-01T00:00:00-05:00")
        let empty = MonthlySummary.build(records: [], month: month, calendar: Fixtures.calendar)
        XCTAssertEqual(empty.averagePerExpenseDay, 0)
        XCTAssertNil(empty.leadingCategory)
        let income = MonthlySummary.build(records: [try Fixtures.record("50", type: .income)], month: month, calendar: Fixtures.calendar)
        XCTAssertEqual(income.balance, 50)
        XCTAssertEqual(income.averagePerExpenseDay, 0)
        XCTAssertTrue(income.categories.isEmpty)
    }

    func testCurrenciesAreNeverAddedTogether() throws {
        let records = try [Fixtures.record("10"), Fixtures.record("100", currency: Currency(code: "USD", fractionDigits: 2))]
        let summary = MonthlySummary.build(records: records, month: try Fixtures.date("2026-09-15T12:00:00-05:00"), calendar: Fixtures.calendar)
        XCTAssertEqual(summary.expense, 10)
        XCTAssertEqual(summary.transactionCount, 1)
    }

    func testDSTDoesNotSplitOneLocalExpenseDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let records = try [Fixtures.record("10", date: "2026-11-01T01:30:00-04:00"), Fixtures.record("20", date: "2026-11-01T01:30:00-05:00")]
        let summary = MonthlySummary.build(records: records, month: try Fixtures.date("2026-11-15T00:00:00Z"), calendar: calendar)
        XCTAssertEqual(summary.expenseDayCount, 1)
        XCTAssertEqual(summary.averagePerExpenseDay, 30)
    }

    func testDecimalTotalsAndDeterministicTies() throws {
        let records = try [Fixtures.record("0.10"), Fixtures.record("0.20"), Fixtures.record("0.30", category: Fixtures.transport)]
        let summary = MonthlySummary.build(records: records, month: try Fixtures.date("2026-09-01T00:00:00-05:00"), calendar: Fixtures.calendar)
        XCTAssertEqual(summary.expense, Decimal(string: "0.60"))
        XCTAssertEqual(summary.categories.map(\.category.id), ["food", "transport"])
        XCTAssertEqual(summary.categories.map(\.percentage), [50, 50])
    }
}
