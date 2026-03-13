import Foundation

struct StatePersistence {
    private let directoryName = "FloatNote"
    private let fileName = "state.json"

    func load() -> PersistedSnapshot? {
        guard let url = stateURL() else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ snapshot: PersistedSnapshot) {
        guard let url = stateURL() else {
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Failed to save FloatNote state: \(error.localizedDescription)")
        }
    }

    private func stateURL() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        return appSupport
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
