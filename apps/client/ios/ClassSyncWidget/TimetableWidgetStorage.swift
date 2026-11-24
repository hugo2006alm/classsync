import Foundation
import OSLog

enum TimetableWidgetStorage {
    enum Failure: Error {
        case containerUnavailable, invalidSize
    }

    private static let group = "group.app.classsync.classsync"
    private static let maximumBytes = 128_000
    private static let log = Logger(subsystem: "app.classsync.classsync", category: "WidgetStorage")

    static func candidates(bundleID: String?, metadata: [String]) -> [String] {
        let prefix = "app.classsync.classsync."
        let team = bundleID.flatMap { identifier -> String? in
            guard identifier.hasPrefix(prefix) else { return nil }
            return identifier.dropFirst(prefix.count).split(separator: ".").first.map(String.init)
        }
        let validTeam: (String) -> Bool = {
            $0.utf8.count == 10 && $0.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) }
        }
        let declared = metadata.filter {
            $0 == group || ($0.hasPrefix(group + ".") && validTeam(String($0.suffix(10)))
                && $0.count == group.count + 11)
        }
        var seen = Set<String>()
        let inferred = team.flatMap { validTeam($0) ? [group + "." + $0] : nil } ?? []
        return (declared + inferred + [group]).filter { seen.insert($0).inserted }
    }

    private static func snapshotURL() throws -> URL {
        let bundle = Bundle.main
        let metadata = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        for id in candidates(bundleID: bundle.bundleIdentifier, metadata: metadata) {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return container.appendingPathComponent("timetable.json")
            }
        }
        log.error("No entitled timetable App Group container")
        throw Failure.containerUnavailable
    }

    static func read() throws -> Data {
        try read(from: snapshotURL())
    }

    static func read(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw Failure.invalidSize }
        return data
    }

    static func write(slots: [[String: Any]], demoIfEmpty: Bool = false) throws {
        try write(slots: slots, demoIfEmpty: demoIfEmpty, to: snapshotURL())
    }

    static func write(slots: [[String: Any]], demoIfEmpty: Bool, to url: URL) throws {
        let fixture = demoIfEmpty && slots.isEmpty
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let fixtureSlots: [[String: Any]] = [[
            "start": now + 300_000, "end": now + 3_600_000,
            "subject": "Snapshot test", "room": "A.101",
            "teacher": "Demo teacher", "class": "T1", "type": "Lab",
        ]]
        let cache: [String: Any] = ["savedAt": now, "slots": fixture ? fixtureSlots : slots, "fixture": fixture]
        let data = try JSONSerialization.data(withJSONObject: cache)
        guard slots.count <= 120, data.count <= maximumBytes else { throw Failure.invalidSize }
        do {
            #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: url, options: .atomic)
            #endif
        } catch {
            log.error("Could not write timetable snapshot")
            throw error
        }
    }
}
