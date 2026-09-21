import Foundation

// The seam for future file formats. Network integrations will need a separate async
// delivery service; there is no stub that pretends to send data to Notion.
protocol TransactionExporter {
    func export(_ records: [TransactionRecord]) throws -> Data
}

struct CSVExporter: TransactionExporter {
    func export(_ records: [TransactionRecord]) throws -> Data {
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dates.timeZone = TimeZone(secondsFromGMT: 0)
        let header = "id,type,amount,currency,category_id,category,note,date,created_at"
        let rows = records.map { record in
            [record.id.uuidString, record.type.rawValue, record.money.editableText,
             record.money.currency.code, record.category.id, record.category.name,
             record.note ?? "", dates.string(from: record.date), dates.string(from: record.createdAt)]
                .map(Self.cell).joined(separator: ",")
        }
        // UTF-8 BOM helps spreadsheet apps recognize Spanish accents; RFC 4180 line endings.
        return Data(("\u{FEFF}" + ([header] + rows).joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func cell(_ text: String) -> String {
        // Quoting alone doesn't stop Excel/Sheets interpreting user text as a formula.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let unsafe = trimmed.first.map { "=+-@".contains($0) } ?? false
        let safe = unsafe || text.hasPrefix("\t") || text.hasPrefix("\r") || text.hasPrefix("\n")
            ? "'" + text : text
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
