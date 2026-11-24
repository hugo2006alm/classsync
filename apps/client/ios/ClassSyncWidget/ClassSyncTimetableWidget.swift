import OSLog
import SwiftUI
import WidgetKit

extension TimetableEntry: TimelineEntry {}

private struct TimetableProvider: TimelineProvider {
    private let log = Logger(subsystem: "app.classsync.classsync", category: "WidgetTimeline")

    private func load(at now: Date) -> (Schedule?, String?) {
        #if CLASSSYNC_WIDGET_DEMO
        let seconds = Int64(now.timeIntervalSince1970)
        let first = (seconds - seconds % 120) * 1000
        let slots = (0..<12).map { index in
            let start = first + Int64(index) * 120_000
            return Lesson(
                start: start, end: start + 90_000, subject: "Demo class \((start / 120_000) % 100)",
                type: "Lab", room: "A.101", teacher: "Demo teacher", group: "T1"
            )
        }
        return (Schedule(savedAt: seconds * 1000, fixture: true, slots: slots), nil)
        #else
        do {
            let schedule = try JSONDecoder().decode(Schedule.self, from: TimetableWidgetStorage.read())
            guard schedule.slots.count <= 120 else { return (nil, "Invalid timetable") }
            return (schedule, nil)
        } catch TimetableWidgetStorage.Failure.containerUnavailable {
            return (nil, "Widget container unavailable")
        } catch {
            log.notice("Timetable snapshot unavailable or invalid")
            return (nil, "Open ClassSync to sync timetable")
        }
        #endif
    }

    func placeholder(in context: Context) -> TimetableEntry {
        TimetableEntry(date: .now, schedule: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        let now = Date.now
        let (schedule, status) = load(at: now)
        completion(TimetableEntry(date: now, schedule: schedule, status: status))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let now = Date.now
        let (schedule, status) = load(at: now)
        let entries = TimetableEntry.dates(from: now, schedule: schedule).map {
            TimetableEntry(date: $0, schedule: schedule, status: status)
        }
        #if CLASSSYNC_WIDGET_DEMO
        let refresh = now.addingTimeInterval(20 * 60)
        #else
        let refresh = now.addingTimeInterval(24 * 3600)
        #endif
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

private struct TimetableView: View {
    let entry: TimetableEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var primary: Lesson? { entry.current.first ?? entry.next }
    private var title: String { entry.current.isEmpty ? "Next class" : "Current class" }
    private var emptyLabel: String {
        if let status = entry.status { return status }
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
                Label([lesson.subject, lesson.room].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "calendar")
                    .privacySensitive()
            } else {
                Text(emptyLabel)
            }
        case .accessoryRectangular:
            if let lesson = primary {
                VStack(alignment: .leading, spacing: 1) {
                    Text(lesson.subject).font(.headline).lineLimit(1)
                    (Text(lesson.begins, style: .time) + Text(lesson.room.isEmpty ? "" : " · " + lesson.room))
                        .font(.caption).lineLimit(1)
                    Text(lesson.teacher).font(.caption2).lineLimit(1)
                }
                .privacySensitive()
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
            (Text(lesson.begins, style: .time) + Text("â€“") + Text(lesson.ends, style: .time))
                .font(.caption)
                .lineLimit(1)
            if !lesson.room.isEmpty {
                Text(lesson.room).font(.caption.weight(.semibold)).lineLimit(1)
            }
            if detailed {
                Text([lesson.group, lesson.type, lesson.teacher].filter { !$0.isEmpty }.joined(separator: " Â· "))
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
        .privacySensitive()
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
