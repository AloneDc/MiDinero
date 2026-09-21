import XCTest
#if SWIFT_PACKAGE
@testable import MiDineroCore
#else
@testable import MiDinero
#endif

final class CSVExporterTests: XCTestCase {
    func testUTF8EscapingExactAmountsAndUTC() throws {
        let record = try Fixtures.record("12.50", note: "Café, \"con leche\"\nmañana")
        let data = try CSVExporter().export([record])
        let csv = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertTrue(csv.contains("\"12.5\",\"PEN\""))
        XCTAssertTrue(csv.contains("\"Café, \"\"con leche\"\"\nmañana\""))
        XCTAssertTrue(csv.contains("2026-09-15T17:00:00.000Z"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
    }

    func testSpreadsheetFormulaInjectionIsNeutralized() throws {
        for note in ["=1+1", "+SUM(A1)", "-1+2", "@SUM(A1)", "  =1", "\t=1", "\r=1", "\n=1"] {
            let csv = try XCTUnwrap(String(data: CSVExporter().export([Fixtures.record("1", note: note)]), encoding: .utf8))
            XCTAssertTrue(csv.contains("\"'\(note)\""), note)
        }
    }

    func testEmptyExportStillHasHeader() throws {
        // Foundation's UTF-8 decoder consumes the BOM on Apple platforms.
        // Verify the actual exported bytes, including BOM and CRLF.
        let data = try CSVExporter().export([])
        XCTAssertEqual(data, Data("\u{FEFF}id,type,amount,currency,category_id,category,note,date,created_at\r\n".utf8))
    }
}
