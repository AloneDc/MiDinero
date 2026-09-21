import Foundation

struct Currency: Hashable, Codable, Sendable {
    let code: String
    let fractionDigits: Int

    static let pen = Currency(code: "PEN", fractionDigits: 2)

    var scale: Decimal {
        (0..<fractionDigits).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}

struct Money: Equatable, Sendable {
    // A per-entry bound leaves ample headroom; aggregates use Decimal, not Int64.
    static let maximumMinorUnits: Int64 = 99_999_999_999
    let minorUnits: Int64
    let currency: Currency

    var decimal: Decimal { Decimal(minorUnits) / currency.scale }

    static func parse(_ input: String, currency: Currency = .pen) throws -> Money {
        guard (0...6).contains(currency.fractionDigits) else { throw MoneyError.invalidCurrency }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw MoneyError.empty }
        // Accept the two decimal keyboards without guessing grouping separators.
        // Reject exponents, grouping, signs, partial parses and excess precision.
        guard text.utf8.allSatisfy({ (48...57).contains($0) || $0 == 44 || $0 == 46 }) else {
            throw MoneyError.invalidFormat
        }
        let pieces = text.replacingOccurrences(of: ",", with: ".").split(
            separator: ".", omittingEmptySubsequences: false
        )
        guard pieces.count <= 2, let whole = pieces.first, !whole.isEmpty else {
            throw MoneyError.invalidFormat
        }
        let fraction = pieces.count == 2 ? String(pieces[1]) : ""
        guard pieces.count == 1 || !fraction.isEmpty else { throw MoneyError.invalidFormat }
        guard fraction.count <= currency.fractionDigits else { throw MoneyError.excessPrecision }
        let padded = fraction + String(repeating: "0", count: currency.fractionDigits - fraction.count)
        guard let units = Int64(String(whole) + padded), units <= maximumMinorUnits else {
            throw MoneyError.tooLarge
        }
        guard units > 0 else { throw MoneyError.notPositive }
        return Money(minorUnits: units, currency: currency)
    }

    var editableText: String {
        NSDecimalNumber(decimal: decimal).stringValue
    }
}

enum MoneyError: LocalizedError, Equatable {
    case empty, invalidFormat, excessPrecision, notPositive, tooLarge, invalidCurrency

    var errorDescription: String? {
        switch self {
        case .empty: "Escribe un monto."
        case .invalidFormat: "Usa un monto como 12.50 o 12,50, sin separadores de miles."
        case .excessPrecision: "El monto tiene demasiados decimales. En soles usa como máximo dos."
        case .notPositive: "El monto debe ser mayor que cero."
        case .tooLarge: "El monto supera el límite de 999 999 999,99 por movimiento."
        case .invalidCurrency: "La moneda no tiene una precisión válida."
        }
    }
}

enum MoneyFormatter {
    static func string(_ amount: Decimal, currency: Currency = .pen, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        if currency.code == "PEN" { formatter.currencySymbol = "S/" }
        formatter.minimumFractionDigits = currency.fractionDigits
        formatter.maximumFractionDigits = currency.fractionDigits
        formatter.roundingMode = .halfEven
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency.code) \(amount)"
    }

    static func percentage(_ value: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSDecimalNumber(decimal: value / 100)) ?? "0 %"
    }
}
