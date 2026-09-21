import AppIntents
import SwiftData
import XCTest
@testable import MiDinero

final class AppIntentTests: XCTestCase {
    @MainActor
    func testPerformWritesToTheContainerAndStoreReadByTheApp() async throws {
        // Fail before touching the singleton if invoked outside the isolated test scheme.
        let testID = try XCTUnwrap(ProcessInfo.processInfo.environment["MIDINERO_UI_TEST_STORE"])
        let uuid = try XCTUnwrap(UUID(uuidString: testID))
        let url = try PersistenceController.storeURL()
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "UITests-\(uuid.uuidString)")
        let container = try PersistenceController.shared.container()
        XCTAssertTrue(container === (try PersistenceController.shared.container()))
        let repository = TransactionRepository(container: container)
        let info = try XCTUnwrap(repository.categories().first { $0.id == "food" })
        let marker = "Intent test \(UUID().uuidString)"
        defer {
            // Only remove this test's transaction; never clear a store wholesale.
            if let own = try? repository.records().first(where: { $0.note == marker }) {
                try? repository.delete(id: own.id)
            }
        }

        var intent = RegisterExpenseIntent()
        intent.amount = "12,50"
        intent.category = ExpenseCategoryEntity(info: info)
        intent.note = marker
        _ = try await intent.perform()

        let app = LedgerStore()
        app.reload()
        XCTAssertNil(app.loadError)
        let saved = try XCTUnwrap(app.records.first { $0.note == marker })
        XCTAssertEqual(saved.money.minorUnits, 1250)
        XCTAssertEqual(saved.type, .expense)
        let withIntent = MonthlySummary.build(records: app.records, month: saved.date)
        let withoutIntent = MonthlySummary.build(records: app.records.filter { $0.id != saved.id }, month: saved.date)
        XCTAssertEqual(withIntent.expense - withoutIntent.expense, Decimal(string: "12.50"))
        XCTAssertEqual(withIntent.transactionCount - withoutIntent.transactionCount, 1)

        let reopened = try PersistenceController.makeContainer(url: url)
        let persisted = try TransactionRepository(container: reopened).records()
        XCTAssertEqual(persisted.filter { $0.id == saved.id }.count, 1)
    }
}
