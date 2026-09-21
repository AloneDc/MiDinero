import AppIntents

struct RegisterExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Registrar gasto" }
    static var description: IntentDescription {
        IntentDescription("Guarda un gasto en soles en este iPhone, sin abrir MiDinero. Usa un monto como 12.50, sin separadores de miles.")
    }
    // The default background mode remains compatible with iOS 17. No foreground request.
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }

    @Parameter(title: "Monto", description: "Monto en soles, por ejemplo 12.50 o 12,50. Sin separadores de miles.",
               requestValueDialog: "¿Cuánto gastaste, en soles?")
    var amount: String

    @Parameter(title: "Categoría", requestValueDialog: "¿En qué categoría?")
    var category: ExpenseCategoryEntity

    @Parameter(title: "Descripción", description: "Opcional. Puedes dejarla vacía.")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar \(\.$amount) en \(\.$category)") { \.$note }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            _ = try Money.parse(amount)
        } catch {
            throw $amount.needsValueError(IntentDialog("Usa un monto mayor que cero, como 12.50, con hasta dos decimales y sin separadores de miles."))
        }
        let repository = try TransactionRepository(container: PersistenceController.shared.container())
        let saved = try ExpenseIntentWriter.save(amount: amount, categoryID: category.id, note: note, repository: repository)
        return .result(dialog: "Guardé \(MoneyFormatter.string(saved.decimal)) en \(category.name).")
    }
}

// Shared testable write path. App Intent and UI use exactly the same repository.
enum ExpenseIntentWriter {
    @MainActor
    static func save(amount: String, categoryID: String, note: String?, repository: TransactionRepository) throws -> Money {
        let money = try Money.parse(amount)
        try repository.save(TransactionDraft(amountText: amount, categoryID: categoryID, note: note ?? ""))
        return money
    }
}
