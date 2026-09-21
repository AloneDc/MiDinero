import XCTest

final class MiDineroUITests: XCTestCase {
    @MainActor
    func testRegisterReopenEditReportAndDelete() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["MIDINERO_UI_TEST_STORE"] = UUID().uuidString
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_PE"]
        app.launch()

        XCTAssertTrue(app.buttons["addExpense"].waitForExistence(timeout: 10))
        app.buttons["addExpense"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("12.50")
        app.buttons["continueAmount"].tap()
        app.buttons["category.food"].tap()
        app.buttons["saveTransaction"].tap()
        let initialExpense = app.descendants(matching: .any)["summary.expense"]
        XCTAssertTrue(initialExpense.waitForExistence(timeout: 5))
        XCTAssertTrue(((initialExpense.value as? String) ?? "").contains("12.50"))
        attachScreenshot(app, named: "Inicio después de guardar")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Movimientos"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let editAmount = app.textFields["amountField"]
        XCTAssertTrue(editAmount.waitForExistence(timeout: 5))
        editAmount.tap()
        let currentText = (editAmount.value as? String) ?? ""
        editAmount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentText.count) + "20")
        app.buttons["saveTransaction"].tap()

        app.tabBars.buttons["Reporte"].tap()
        let reportExpense = app.descendants(matching: .any)["summary.expense"]
        XCTAssertTrue(reportExpense.waitForExistence(timeout: 5))
        XCTAssertTrue(((reportExpense.value as? String) ?? "").contains("20.00"))
        attachScreenshot(app, named: "Reporte después de editar")

        app.tabBars.buttons["Movimientos"].tap()
        let updatedRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction.")).firstMatch
        updatedRow.swipeLeft()
        app.buttons["Eliminar"].tap()
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(updatedRow.exists)
        updatedRow.swipeLeft()
        app.buttons["Eliminar"].tap()
        app.buttons["Eliminar movimiento"].tap()
        XCTAssertTrue(app.staticTexts["Tu historial empieza aquí"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Empieza con un gasto"].waitForExistence(timeout: 5))
        attachScreenshot(app, named: "Estado vacío después de eliminar y reabrir")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
