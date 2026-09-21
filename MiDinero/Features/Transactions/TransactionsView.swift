import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

@MainActor
struct TransactionsView: View {
    @Environment(LedgerStore.self) private var store
    @State private var newestFirst = true
    @State private var pendingDeletion: TransactionRecord?
    @State private var error: String?
    @State private var exportDocument = CSVDocument()
    @State private var isExporting = false
    let onAdd: () -> Void
    let onEdit: (TransactionRecord) -> Void

    private var ordered: [TransactionRecord] { newestFirst ? store.records : Array(store.records.reversed()) }

    var body: some View {
        NavigationStack {
            List {
                if store.records.isEmpty {
                    ContentUnavailableView {
                        Label("Tu historial empieza aquí", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Los gastos e ingresos que registres aparecerán en esta lista.")
                    } actions: {
                        Button("Registrar gasto", action: onAdd).buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(ordered) { record in
                            Button { onEdit(record) } label: { TransactionRow(record: record) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Editar movimiento")
                                .accessibilityIdentifier("transaction.\(record.id.uuidString)")
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Deliberately no destructive role until confirmation: no premature row removal.
                                    Button { pendingDeletion = record } label: { Label("Eliminar", systemImage: "trash") }
                                        .tint(.red)
                                }
                                .contextMenu {
                                    Button { onEdit(record) } label: { Label("Editar", systemImage: "pencil") }
                                    Button(role: .destructive) { pendingDeletion = record } label: { Label("Eliminar", systemImage: "trash") }
                                }
                                .accessibilityAction(named: Text("Eliminar movimiento")) { pendingDeletion = record }
                        }
                    } header: {
                        Text(newestFirst ? "Más recientes primero" : "Más antiguos primero")
                    } footer: {
                        Text("\(store.records.count) movimientos · Toca uno para editarlo.")
                    }
                }
            }
            .navigationTitle("Movimientos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Orden", selection: $newestFirst) {
                            Text("Más recientes primero").tag(true)
                            Text("Más antiguos primero").tag(false)
                        }
                        Button { export() } label: { Label("Exportar CSV", systemImage: "square.and.arrow.up") }
                            .disabled(store.records.isEmpty)
                    } label: { Label("Opciones", systemImage: "ellipsis.circle") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onAdd) { Label("Registrar gasto", systemImage: "plus") }
                }
            }
            .refreshable { store.reload() }
            .confirmationDialog("¿Eliminar este movimiento?", isPresented: Binding(
                get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible, presenting: pendingDeletion) { record in
                Button("Eliminar movimiento", role: .destructive) {
                    do { try store.delete(id: record.id) } catch { self.error = error.localizedDescription }
                    pendingDeletion = nil
                }
                Button("Cancelar", role: .cancel) { pendingDeletion = nil }
            } message: { record in
                Text("\(record.category.name) · \(MoneyFormatter.string(record.money.decimal, currency: record.money.currency)). Esta acción no se puede deshacer.")
            }
            .alert("No se pudo completar", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("Aceptar", role: .cancel) { error = nil } } message: { Text(error ?? "") }
            .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .commaSeparatedText,
                          defaultFilename: "MiDinero-movimientos") { result in
                if case .failure(let failure) = result { error = failure.localizedDescription }
            }
        }
    }

    private func export() {
        do {
            exportDocument = CSVDocument(data: try CSVExporter().export(store.records))
            isExporting = true
        } catch { self.error = error.localizedDescription }
    }
}
