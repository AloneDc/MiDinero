import Foundation

struct CategoryInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let sortOrder: Int

    // Stable IDs are shared by persisted records and AppEntity identifiers.
    // Custom categories can use UUID strings without changing the transaction schema.
    static let defaults: [CategoryInfo] = [
        .init(id: "food", name: "Comida", symbol: "fork.knife", sortOrder: 0),
        .init(id: "transport", name: "Transporte", symbol: "bus", sortOrder: 1),
        .init(id: "shopping", name: "Compras", symbol: "bag", sortOrder: 2),
        .init(id: "entertainment", name: "Entretenimiento", symbol: "popcorn", sortOrder: 3),
        .init(id: "home", name: "Hogar", symbol: "house", sortOrder: 4),
        .init(id: "utilities", name: "Servicios", symbol: "bolt", sortOrder: 5),
        .init(id: "education", name: "Educación", symbol: "book", sortOrder: 6),
        .init(id: "health", name: "Salud", symbol: "cross.case", sortOrder: 7),
        .init(id: "technology", name: "Tecnología", symbol: "laptopcomputer", sortOrder: 8),
        .init(id: "other", name: "Otros", symbol: "ellipsis.circle", sortOrder: 9)
    ]
}
