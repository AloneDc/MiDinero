import Foundation
import Observation

@MainActor
@Observable
final class LedgerStore {
    private(set) var records: [TransactionRecord] = []
    private(set) var categories: [CategoryInfo] = []
    private(set) var hasLoaded = false
    private(set) var loadError: String?
    private(set) var referenceDate = Date.now
    private var repository: TransactionRepository?

    func reload() {
        do {
            let activeRepository = try repository ?? TransactionRepository(container: PersistenceController.shared.container())
            let categories = try activeRepository.categories()
            let records = try activeRepository.records()
            self.repository = activeRepository
            self.categories = categories
            self.records = records
            referenceDate = .now
            hasLoaded = true
            loadError = nil
        } catch {
            loadError = "No se pudieron cargar los movimientos. Reintenta con el iPhone desbloqueado. \(error.localizedDescription)"
        }
    }

    func save(_ draft: TransactionDraft, editing id: UUID?) throws {
        guard let repository else { throw LedgerError.invalidStoredData }
        try repository.save(draft, editing: id)
        reload()
    }

    func delete(id: UUID) throws {
        guard let repository else { throw LedgerError.invalidStoredData }
        try repository.delete(id: id)
        reload()
    }
}
