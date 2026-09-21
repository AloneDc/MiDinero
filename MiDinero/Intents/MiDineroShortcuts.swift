import AppIntents

struct MiDineroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegisterExpenseIntent(),
            phrases: ["Registrar gasto en \(.applicationName)", "Anotar un gasto en \(.applicationName)"],
            shortTitle: "Registrar gasto",
            systemImageName: "plus.circle"
        )
    }
}
