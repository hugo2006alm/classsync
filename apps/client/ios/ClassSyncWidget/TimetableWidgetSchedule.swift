import Foundation

struct Lesson: Decodable, Identifiable {
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

struct Schedule: Decodable {
    let savedAt: Int64
    let fixture: Bool?
    let slots: [Lesson]
    var expires: Date { Date(timeIntervalSince1970: Double(savedAt) / 1000 + 7 * 86400) }
}

struct TimetableEntry {
    let date: Date
    let schedule: Schedule?
    var status: String? = nil

    var lessons: [Lesson] {
        guard let schedule, date < schedule.expires else { return [] }
        return schedule.slots.filter {
            $0.ends > date && $0.ends > $0.begins && $0.begins < date.addingTimeInterval(4 * 86400)
        }.sorted { $0.start < $1.start }
    }

    var current: [Lesson] { lessons.filter { $0.begins <= date } }
    var next: Lesson? { lessons.first { $0.begins > date } }
    var today: [Lesson] {
        lessons.filter { Calendar.current.isDate($0.begins, inSameDayAs: date) }
    }
}

extension TimetableEntry {
    static func dates(from now: Date, schedule: Schedule?) -> [Date] {
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        let extraDates = [nextDay, schedule?.expires].compactMap { $0 }
        let boundaries = (schedule?.slots ?? []).flatMap { [$0.begins, $0.ends] }
        let dates = Set(boundaries + extraDates)
            .filter { $0 > now && $0 <= now.addingTimeInterval(24 * 3600) }
            .sorted()
        return [now] + dates
    }
}
