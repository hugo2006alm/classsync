import Foundation

@main
struct WidgetChecks {
    static func main() throws {
        let original = "group.app.classsync.classsync"
        let rewritten = original + ".ABCDE12345"
        precondition(TimetableWidgetStorage.candidates(bundleID: "app.classsync.classsync", metadata: []) == [original])
        for suffix in ["", ".widgets"] {
            let candidates = TimetableWidgetStorage.candidates(
                bundleID: "app.classsync.classsync.ABCDE12345" + suffix,
                metadata: [rewritten, rewritten, "group.other.ABCDE12345", original + ".invalid"]
            )
            precondition(candidates == [rewritten, original])
        }
        precondition(TimetableWidgetStorage.candidates(
            bundleID: "app.classsync.classsync.ABCDE12345.widgets", metadata: []
        ) == [rewritten, original])

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("snapshot.json")
        try TimetableWidgetStorage.write(slots: [], demoIfEmpty: true, to: url)
        let data = try TimetableWidgetStorage.read(from: url)
        let schedule = try JSONDecoder().decode(Schedule.self, from: data)
        precondition(schedule.fixture == true && schedule.slots.count == 1)
        let lesson = schedule.slots[0]
        let before = lesson.begins.addingTimeInterval(-60)
        precondition(TimetableEntry(date: before, schedule: schedule).next?.room == "A.101")
        precondition(TimetableEntry(date: lesson.begins, schedule: schedule).current.count == 1)
        precondition(TimetableEntry(date: lesson.ends, schedule: schedule).lessons.isEmpty)
        precondition(TimetableEntry(date: schedule.expires, schedule: schedule).lessons.isEmpty)
        let dates = TimetableEntry.dates(from: before, schedule: schedule)
        precondition(dates.first == before && dates.contains(lesson.begins) && dates.contains(lesson.ends))
        precondition(dates == dates.sorted())

        try TimetableWidgetStorage.write(slots: [], demoIfEmpty: false, to: url)
        let cleared = try JSONDecoder().decode(Schedule.self, from: TimetableWidgetStorage.read(from: url))
        precondition(cleared.slots.isEmpty && cleared.fixture == false)
        try Data(repeating: 0, count: 128_001).write(to: url)
        do {
            _ = try TimetableWidgetStorage.read(from: url)
            preconditionFailure("Oversized snapshot was read")
        } catch TimetableWidgetStorage.Failure.invalidSize {
            print("Widget resolver, snapshot and timeline checks passed")
        }
    }
}
