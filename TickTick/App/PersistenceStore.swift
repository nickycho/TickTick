import Foundation

enum PersistenceStore {
    static let directoryName = "com.nickycho.TickTick"
    static let storeFileName = "TickTick.store"
    static let legacyStoreFileName = "default.store"

    static func storeURL(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = applicationSupportDirectory.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(storeFileName)
    }

    static func legacyStoreURL(applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory.appendingPathComponent(legacyStoreFileName)
    }

    static func migrateLegacyStoreIfNeeded(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws {
        let destination = try storeURL(
            applicationSupportDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        guard !fileManager.fileExists(atPath: destination.path) else { return }

        let legacy = legacyStoreURL(applicationSupportDirectory: applicationSupportDirectory)
        guard fileManager.fileExists(atPath: legacy.path) else { return }

        let sidecars: [(suffix: String, source: URL)] = [
            ("", legacy),
            ("-wal", URL(fileURLWithPath: legacy.path + "-wal")),
            ("-shm", URL(fileURLWithPath: legacy.path + "-shm")),
        ]

        for (suffix, source) in sidecars where fileManager.fileExists(atPath: source.path) {
            let target = URL(fileURLWithPath: destination.path + suffix)
            try fileManager.copyItem(at: source, to: target)
        }
    }
}
