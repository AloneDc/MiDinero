import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(LedgerStore.self) private var store
    let onAdd: () -> Void
    let onEdit: (TransactionRecord) -> Void

    var body: some View {
        let summary = MonthlySummary.build(records: store.records, month: store.referenceDate)
        NavigationStack {
            List {
                Section {
                    Button(action: onAdd) {
                        Label("Registrar gasto", systemImage: "plus.circle.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("addExpense")
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                if store.records.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Empieza con un gasto", systemImage: "text.badge.plus")
                        } description: {
                            Text("Un café, un pasaje o el almuerzo. Regístralo y empieza a descubrir en qué se va tu dinero.")
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section {
                    SummaryRows(summary: summary)
                } header: {
                    Text(store.referenceDate, format: .dateTime.month(.wide).year())
                } footer: {
                    Text("Balance = ingresos menos gastos registrados. No representa el saldo de tus cuentas.")
                }
                if !summary.categories.isEmpty {
                    Section("En qué gastaste este mes") {
                        ForEach(Array(summary.categories.prefix(3))) { CategorySpendingRow(spending: $0) }
                    }
                } else if !store.records.isEmpty {
                    Section {
                        Text("Todavía no registraste gastos este mes.").foregroundStyle(.secondary)
                    }
                }
                if !store.records.isEmpty {
                    Section("Últimos movimientos") {
                        ForEach(Array(store.records.prefix(5))) { record in
                            Button { onEdit(record) } label: { TransactionRow(record: record) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Editar movimiento")
                                .accessibilityIdentifier("transaction.\(record.id.uuidString)")
                        }
                    }
                }
                Section {
                    NavigationLink { ShortcutHelpView() } label: {
                        Label("Registra con Atajos o Siri", systemImage: "square.stack.3d.up")
                    }
                }
            }
            .navigationTitle("MiDinero")
            .refreshable { store.reload() }
        }
    }
}
