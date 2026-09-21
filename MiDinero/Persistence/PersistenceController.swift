import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    private var cachedContainer: ModelContainer?

    func container() throws -> ModelContainer {
        if let cachedContainer { return cachedContainer }
        let container = try Self.makeContainer(url: Self.storeURL())
        cachedContainer = container
        return container
    }

    static func storeURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        var directory = support.appendingPathComponent("MiDinero", isDirectory: true)
        #if DEBUG
        // Hosted unit/UI tests never use the personal store; the UUID survives relaunch.
        if let testID = ProcessInfo.processInfo.environment["MIDINERO_UI_TEST_STORE"],
           let uuid = UUID(uuidString: testID) {
            directory = support.appendingPathComponent("UITests-\(uuid.uuidString)", isDirectory: true)
        }
        #endif
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The MVP is deliberately local, including exclusion from automatic device backups.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory.appendingPathComponent("MiDinero.store")
    }

    static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([FinancialTransaction.self, Category.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "MiDinero", schema: schema, isStoredInMemoryOnly: true,
                groupContainer: .none, cloudKitDatabase: .none
            )
        } else {
            let location = try url ?? storeURL()
            configuration = ModelConfiguration("MiDinero", schema: schema, url: location, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
