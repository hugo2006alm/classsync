import SwiftUI
import WidgetKit

private struct Lesson: Decodable, Identifiable {
    let start: Int64
    let end: Int64
    let subject: String
    let type: String
    let room: String
    let teacher: String
    let group: String

    enum CodingKeys: String, CodingKey {
        case start, end, subject, type, room, teacher
        case group = "class"
    }

    var id: String { "\(start)-\(subject)-\(room)-\(group)" }
    var begins: Date { Date(timeIntervalSince1970: Double(start) / 1000) }
    var ends: Date { Date(timeIntervalSince1970: Double(end) / 1000) }
}

private struct Schedule: Decodable {
    let savedAt: Int64
    let slots: [Lesson]
    var expires: Date { Date(timeIntervalSince1970: Double(savedAt) / 1000 + 7 * 86400) }
}

private struct TimetableEntry: TimelineEntry {
    let date: Date
    let schedule: Schedule?

    var lessons: [Lesson] {
        guard let schedule, date < schedule.expires else { return [] }
        return schedule.slots.filter {
            $0.ends > date && $0.ends > $0.begins && $0.begins < date.addingTimeInterval(4 * 86400)
        }
    }

    var current: [Lesson] { lessons.filter { $0.begins <= date } }
    var next: Lesson? { lessons.first { $0.begins > date } }
    var today: [Lesson] {
        lessons.filter { Calendar.current.isDate($0.begins, inSameDayAs: date) }
    }
}

private struct TimetableProvider: TimelineProvider {
    private func readSchedule() -> Schedule? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.classsync.classsync"
        ), let data = try? Data(contentsOf: container.appendingPathComponent("timetable.json")),
        data.count <= 128_000 else { return nil }
        return try? JSONDecoder().decode(Schedule.self, from: data)
    }

    func placeholder(in context: Context) -> TimetableEntry {
        TimetableEntry(date: .now, schedule: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        completion(TimetableEntry(date: .now, schedule: readSchedule()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let now = Date.now
        let schedule = readSchedule()
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        let extraDates = [nextDay, schedule?.expires].compactMap { $0 }
        let boundaries = (schedule?.slots ?? []).flatMap { [$0.begins, $0.ends] }
        let dates = Set(boundaries + extraDates)
            .filter { $0 > now && $0 <= now.addingTimeInterval(24 * 3600) }
            .sorted()
        let entries = ([now] + dates).map { TimetableEntry(date: $0, schedule: schedule) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(24 * 3600))))
    }
}

private struct TimetableView: View {
    let entry: TimetableEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var primary: Lesson? { entry.current.first ?? entry.next }
    private var title: String { entry.current.isEmpty ? "Next class" : "Current class" }
    private var emptyLabel: String {
        guard let schedule = entry.schedule, entry.date < schedule.expires else {
            return "Open ClassSync to refresh"
        }
        return "No upcoming class"
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) {
                if renderingMode == .fullColor {
                    Color(uiColor: .secondarySystemBackground)
                }
            }
            .widgetURL(URL(string: "classsync://timetable/academic?section=0"))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            if let lesson = primary {
                Label(lesson.room.isEmpty ? lesson.subject : lesson.room, systemImage: "calendar")
            } else {
                Text(emptyLabel)
            }
        case .accessoryRectangular:
            if let lesson = primary {
                lessonRow(lesson, title: title, detailed: false)
            } else {
                Text(emptyLabel)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 8) {
                Text("Today").font(.headline).widgetAccentable()
                if entry.today.isEmpty {
                    if let lesson = primary {
                        lessonRow(lesson, title: title, detailed: true)
                    } else {
                        Text(emptyLabel)
                    }
                } else {
                    ForEach(Array(entry.today.prefix(4))) { lesson in
                        lessonRow(lesson, title: lesson.begins <= entry.date ? "Current class" : nil, detailed: true)
                    }
                }
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 12) {
                if let lesson = primary {
                    lessonRow(lesson, title: title, detailed: true)
                    if !entry.current.isEmpty, let next = entry.next {
                        Divider()
                        lessonRow(next, title: "Next class", detailed: true)
                    }
                } else {
                    Text(emptyLabel)
                }
            }
        default:
            if let lesson = primary {
                lessonRow(lesson, title: title, detailed: false)
            } else {
                Text(emptyLabel)
            }
        }
    }

    private func lessonRow(_ lesson: Lesson, title: String?, detailed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title { Text(title).font(.caption.weight(.semibold)).widgetAccentable() }
            Text(lesson.subject).font(.subheadline.weight(.semibold)).lineLimit(2)
            (Text(lesson.begins, style: .time) + Text("–") + Text(lesson.ends, style: .time))
                .font(.caption)
                .lineLimit(1)
            if !lesson.room.isEmpty {
                Text(lesson.room).font(.caption.weight(.semibold)).lineLimit(1)
            }
            if detailed {
                Text([lesson.group, lesson.type, lesson.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2)
                    .lineLimit(2)
                if family == .systemMedium {
                    let deadline = lesson.begins > entry.date ? lesson.begins : lesson.ends
                    Text(timerInterval: entry.date...deadline, countsDown: true)
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct ClassSyncTimetableWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClassSyncTimetable", provider: TimetableProvider()) {
            TimetableView(entry: $0)
        }
        .configurationDisplayName("ClassSync Timetable")
        .description("See your current and upcoming classes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}
