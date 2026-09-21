import SwiftUI

@MainActor
struct TransactionEditorView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var amountFocused: Bool
    @State private var amount: String
    @State private var type: TransactionType
    @State private var categoryID: String
    @State private var note: String
    @State private var date: Date
    @State private var showDetails: Bool
    @State private var error: String?
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false

    let record: TransactionRecord?
    let onSaved: (String) -> Void
    private let initialDate: Date

    init(record: TransactionRecord?, onSaved: @escaping (String) -> Void) {
        self.record = record
        self.onSaved = onSaved
        let initialDate = record?.date ?? .now
        self.initialDate = initialDate
        _amount = State(initialValue: record?.money.editableText ?? "")
        _type = State(initialValue: record?.type ?? .expense)
        _categoryID = State(initialValue: record?.category.id ?? "")
        _note = State(initialValue: record?.note ?? "")
        _date = State(initialValue: initialDate)
        _showDetails = State(initialValue: record != nil)
    }

    private var currency: Currency { record?.money.currency ?? .pen }
    private var parsedMoney: Money? { try? Money.parse(amount, currency: currency) }
    private var isDirty: Bool {
        amount != (record?.money.editableText ?? "") || type != (record?.type ?? .expense)
            || categoryID != (record?.category.id ?? "") || note != (record?.note ?? "") || date != initialDate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    amountSection
                    if showDetails {
                        categorySection
                        noteSection
                        typeAndDateSection
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.red)
                            .accessibilityIdentifier("editorError")
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(record == nil ? "Registrar gasto" : "Editar movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if isDirty { showDiscardConfirmation = true } else { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(showDetails ? "Listo" : "Continuar") { advance() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if showDetails { save() } else { advance() }
                } label: {
                    Text(showDetails ? (record == nil ? "Guardar \(type.title.lowercased())" : "Guardar cambios") : "Continuar")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || (showDetails && (parsedMoney == nil || categoryID.isEmpty || note.count > 500)))
                .accessibilityIdentifier(showDetails ? "saveTransaction" : "continueAmount")
                .padding().background(.regularMaterial)
            }
            .confirmationDialog("¿Descartar los cambios?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Descartar cambios", role: .destructive) { dismiss() }
                Button("Seguir editando", role: .cancel) { }
            }
            .interactiveDismissDisabled(isDirty)
            .onChange(of: amount) { _, _ in
                guard showDetails else { return }
                do {
                    _ = try Money.parse(amount, currency: currency)
                    error = nil
                } catch { self.error = error.localizedDescription }
            }
            .task { amountFocused = record == nil }
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("¿Cuánto?").font(.title2.weight(.semibold))
            HStack(alignment: .firstTextBaseline) {
                Text(currency.code == "PEN" ? "S/" : currency.code).foregroundStyle(.secondary)
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .accessibilityLabel("Monto en \(currency.code)")
                    .accessibilityIdentifier("amountField")
            }
            .font(.largeTitle.weight(.semibold)).monospacedDigit()
            Text("\(currency.code) · hasta \(currency.fractionDigits) decimales")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿En qué categoría?").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 240 : 140), spacing: 10)], spacing: 10) {
                ForEach(store.categories) { category in categoryButton(category) }
            }
        }
    }

    private func categoryButton(_ category: CategoryInfo) -> some View {
        let selected = categoryID == category.id
        return Button {
            categoryID = category.id
            amountFocused = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.symbol).frame(width: 22)
                Text(category.name).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark") }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected ? Color.indigo.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.indigo : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("category.\(category.id)")
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descripción (opcional)").font(.headline)
            TextField("Por ejemplo, almuerzo con amigos", text: $note, axis: .vertical)
                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("noteField")
            if note.count > 500 {
                Text("Usa hasta 500 caracteres.").font(.footnote).foregroundStyle(.red)
            }
        }
    }

    private var typeAndDateSection: some View {
        DisclosureGroup("Tipo y fecha") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Tipo de movimiento", selection: $type) {
                    ForEach(TransactionType.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Fecha", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            .padding(.top, 12)
        }
        .font(.subheadline)
    }

    private func advance() {
        do {
            _ = try Money.parse(amount, currency: currency)
            error = nil
            showDetails = true
            amountFocused = false
        } catch { self.error = error.localizedDescription }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        do {
            try store.save(TransactionDraft(amountText: amount, type: type, categoryID: categoryID,
                                             note: note, date: date, currency: currency), editing: record?.id)
            onSaved(record == nil ? "\(type.title) guardado" : "Cambios guardados")
            UIAccessibility.post(notification: .announcement, argument: "Movimiento guardado")
            dismiss()
        } catch {
            self.error = "No se pudo guardar. \(error.localizedDescription)"
            isSaving = false
        }
    }
}
