import SwiftUI

struct TransactionRow: View {
    let record: TransactionRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: record.category.symbol)
                .foregroundStyle(.secondary).frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.category.name).font(.body.weight(.medium))
                if let note = record.note {
                    Text(note).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Text(record.date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.type.sign + MoneyFormatter.string(record.money.decimal, currency: record.money.currency))
                    .font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(record.type.title, systemImage: record.type.symbol)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

struct SummaryRows: View {
    let summary: MonthlySummary

    var body: some View {
        LabeledContent("Gastos", value: MoneyFormatter.string(summary.expense, currency: summary.currency))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gastos")
            .accessibilityValue(MoneyFormatter.string(summary.expense, currency: summary.currency))
            .accessibilityIdentifier("summary.expense")
        LabeledContent("Ingresos", value: MoneyFormatter.string(summary.income, currency: summary.currency))
        LabeledContent("Balance", value: MoneyFormatter.string(summary.balance, currency: summary.currency))
            .font(.body.weight(.semibold))
        LabeledContent("Movimientos", value: summary.transactionCount.formatted())
    }
}

struct CategorySpendingRow: View {
    let spending: CategorySpending
    var currency: Currency = .pen

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(spending.category.name, systemImage: spending.category.symbol)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 3) {
                Text(MoneyFormatter.string(spending.amount, currency: currency)).monospacedDigit()
                Text(MoneyFormatter.percentage(spending.percentage))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
