import AppIntents
import Combine
import SwiftUI

private struct EditorRequest: Identifiable {
    let id = UUID()
    let record: TransactionRecord?
}

@MainActor
struct RootView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: EditorRequest?
    @State private var confirmation: String?
    @State private var successCount = 0

    var body: some View {
        Group {
            if store.hasLoaded {
                TabView {
                    HomeView(onAdd: add, onEdit: edit)
                        .tabItem { Label("Inicio", systemImage: "house") }
                    TransactionsView(onAdd: add, onEdit: edit)
                        .tabItem { Label("Movimientos", systemImage: "list.bullet") }
                    MonthlyReportView()
                        .tabItem { Label("Reporte", systemImage: "chart.bar.xaxis") }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let error = store.loadError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Los datos podrían estar desactualizados.").font(.headline)
                            Text(error).font(.footnote)
                            Button("Reintentar", action: store.reload)
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                    }
                }
            } else if let error = store.loadError {
                ContentUnavailableView {
                    Label("No pudimos abrir tus datos", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar", action: store.reload).buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Abriendo MiDinero…")
            }
        }
        .sheet(item: $editor) { request in
            TransactionEditorView(record: request.record) { message in
                confirmation = message
                successCount += 1
            }
        }
        .overlay(alignment: .top) {
            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding().background(.regularMaterial, in: Capsule())
                    .padding(.horizontal).allowsHitTesting(false)
                    .accessibilityLabel(confirmation)
            }
        }
        .sensoryFeedback(.success, trigger: successCount)
        .task(id: successCount) {
            guard confirmation != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            confirmation = nil
        }
        .task {
            store.reload()
            MiDineroShortcuts.updateAppShortcutParameters()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ledgerDidChange)) { _ in store.reload() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.reload()
        }
    }

    private func add() { editor = EditorRequest(record: nil) }
    private func edit(_ record: TransactionRecord) { editor = EditorRequest(record: record) }
}
