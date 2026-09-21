import AppIntents

struct ExpenseCategoryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Categoría" }
    static var defaultQuery: ExpenseCategoryQuery { ExpenseCategoryQuery() }

    let id: String
    let name: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }

    init(info: CategoryInfo) {
        id = info.id
        name = info.name
        symbol = info.symbol
    }
}

struct ExpenseCategoryQuery: EntityStringQuery {
    func entities(for identifiers: [ExpenseCategoryEntity.ID]) async throws -> [ExpenseCategoryEntity] {
        let categories = try await allCategories()
        return identifiers.compactMap { id in categories.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [ExpenseCategoryEntity] { try await allCategories() }

    func entities(matching string: String) async throws -> [ExpenseCategoryEntity] {
        try await allCategories().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    private func allCategories() throws -> [ExpenseCategoryEntity] {
        let repository = try TransactionRepository(container: PersistenceController.shared.container())
        return try repository.categories().map(ExpenseCategoryEntity.init)
    }
}
