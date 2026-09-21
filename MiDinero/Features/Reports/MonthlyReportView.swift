import Charts
import SwiftUI

@MainActor
struct MonthlyReportView: View {
    @Environment(LedgerStore.self) private var store
    @State private var month = Date.now

    var body: some View {
        let summary = MonthlySummary.build(records: store.records, month: month)
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("Mes anterior")
                        Spacer(minLength: 4)
                        Text(month, format: .dateTime.month(.wide).year())
                            .font(.headline).multilineTextAlignment(.center)
                        Spacer(minLength: 4)
                        Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("Mes siguiente")
                    }
                    if !FinanceCalendar.current.isDate(month, equalTo: store.referenceDate, toGranularity: .month) {
                        Button("Ir al mes actual") { month = store.referenceDate }
                    }
                }
                Section("Resumen · PEN") { SummaryRows(summary: summary) }
                if summary.transactionCount == 0 {
                    ContentUnavailableView("Un mes por descubrir", systemImage: "calendar", description: Text("No hay movimientos registrados en este mes."))
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        LabeledContent("Promedio por día con gasto", value: MoneyFormatter.string(summary.averagePerExpenseDay))
                        LabeledContent("Días con gasto", value: summary.expenseDayCount.formatted())
                    } footer: {
                        Text("Gasto total dividido entre los días de este mes con al menos un gasto. Los días con solo ingresos no cuentan.")
                    }
                    if let leading = summary.leadingCategory {
                        Section("Mayor gasto") { CategorySpendingRow(spending: leading) }
                    }
                    if !summary.categories.isEmpty {
                        Section("Gasto por categoría") {
                            Chart(summary.categories) { spending in
                                BarMark(
                                    x: .value("Gasto en soles", NSDecimalNumber(decimal: spending.amount).doubleValue),
                                    y: .value("Categoría", spending.category.name)
                                )
                                .foregroundStyle(Color.indigo)
                                .cornerRadius(3)
                            }
                            // Double is confined to the chart rendering; all calculations use Decimal.
                            .chartXAxisLabel("S/")
                            .frame(height: CGFloat(summary.categories.count) * 36 + 44)
                            .accessibilityHidden(true)
                            ForEach(summary.categories) { CategorySpendingRow(spending: $0) }
                        }
                    } else {
                        Section { Text("Este mes registraste ingresos, pero todavía ningún gasto.").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Reporte mensual")
            .refreshable { store.reload() }
        }
    }

    private func moveMonth(_ offset: Int) {
        let calendar = FinanceCalendar.current
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let next = calendar.date(byAdding: .month, value: offset, to: start) else { return }
        month = next
    }
}
