import XCTest
#if SWIFT_PACKAGE
@testable import MiDineroCore
#else
@testable import MiDinero
#endif

final class MoneyTests: XCTestCase {
    func testDecimalInputIsExactForBothKeyboards() throws {
        XCTAssertEqual(try Money.parse("12.50").minorUnits, 1250)
        XCTAssertEqual(try Money.parse(" 12,50 \n").minorUnits, 1250)
        XCTAssertEqual(try Money.parse("0.01").minorUnits, 1)
        XCTAssertEqual(try Money.parse("10").minorUnits, 1000)
        XCTAssertEqual(try Money.parse("0.10").decimal + Money.parse("0.20").decimal, Decimal(string: "0.30"))
    }

    func testRejectsAmbiguousPartialAndNonPositiveInput() {
        for input in ["", " ", "0", "0,00", "-2", "+2", "1e3", "NaN", "∞", "12 soles",
                      "1,000", "1.000", "1,234.56", "1 234,56", ".5", "1.", "1..2", "١٢", "2\n3"] {
            XCTAssertThrowsError(try Money.parse(input), "Unexpectedly accepted: \(input)")
        }
    }

    func testOverflowAndMaximum() throws {
        XCTAssertEqual(try Money.parse("999999999.99").minorUnits, Money.maximumMinorUnits)
        XCTAssertThrowsError(try Money.parse("1000000000"))
        XCTAssertThrowsError(try Money.parse(String(repeating: "9", count: 200)))
    }

    func testCurrencyScaleCanEvolve() throws {
        let yen = Currency(code: "JPY", fractionDigits: 0)
        XCTAssertEqual(try Money.parse("250", currency: yen).minorUnits, 250)
        XCTAssertThrowsError(try Money.parse("250.1", currency: yen))
        let dinar = Currency(code: "KWD", fractionDigits: 3)
        XCTAssertEqual(try Money.parse("1.234", currency: dinar).minorUnits, 1234)
        XCTAssertThrowsError(try Money.parse("1", currency: Currency(code: "BAD", fractionDigits: -1)))
    }

    func testEditingRoundTripPreservesCents() throws {
        for amount in ["0.01", "0.10", "12.50", "999999999.99"] {
            let original = try Money.parse(amount)
            XCTAssertEqual(try Money.parse(original.editableText), original)
        }
    }

    func testFormattingHonorsLocaleAndCurrency() throws {
        let amount = try Money.parse("1234.50").decimal
        XCTAssertTrue(MoneyFormatter.string(amount, locale: Locale(identifier: "es_PE")).contains("S/"))
        XCTAssertTrue(MoneyFormatter.string(amount, locale: Locale(identifier: "de_DE")).contains("1.234,50"))
    }

    func testNoteNormalizationAndLimit() throws {
        var draft = TransactionDraft(amountText: "2", categoryID: "food", note: " \n ")
        XCTAssertNil(draft.normalizedNote)
        draft.note = " Almuerzo \n"
        XCTAssertEqual(draft.normalizedNote, "Almuerzo")
        draft.note = String(repeating: "a", count: 501)
        XCTAssertThrowsError(try draft.validatedMoney())
    }
}
