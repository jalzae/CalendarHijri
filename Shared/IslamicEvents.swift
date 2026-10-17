import Foundation

/// Fast-status for a single Hijri day.
enum FastRule {
    case sunnahFasting   // Ayyamul Bidh, Ashura, Arafah, ...
    case obligatory      // Ramadan
    case forbidden       // Day of Tasyrik (13 Dhu al-Hijjah)
    case none
}

/// Major Islamic events per Hijri month + Ayyamul Bidh (white days) rules.
enum IslamicEvents {
    struct Event: Identifiable, Equatable {
        let monthIndex: Int   // 0 = Muharram
        let day: Int
        let name: String
        var id: String { "\(monthIndex)-\(day)-\(name)" }
    }

    static let all: [Event] = [
        Event(monthIndex: 0, day: 1,  name: "Islamic New Year"),
        Event(monthIndex: 0, day: 10, name: "Day of Ashura"),
        Event(monthIndex: 2, day: 12, name: "Mawlid al-Nabi"),
        Event(monthIndex: 6, day: 27, name: "Al Isra' wal Mi'raj"),
        Event(monthIndex: 7, day: 15, name: "Nisfu Sha'ban (Night of Bara'at)"),
        Event(monthIndex: 9, day: 1,  name: "Eid al-Fitr"),
        Event(monthIndex: 11, day: 9,  name: "Day of Arafah"),
        Event(monthIndex: 11, day: 10, name: "Eid al-Adha"),
    ]

    static func events(inMonth monthIndex: Int) -> [Event] {
        all.filter { $0.monthIndex == monthIndex }.sorted { $0.day < $1.day }
    }

    static func event(onDay day: Int, monthIndex: Int) -> Event? {
        all.first { $0.monthIndex == monthIndex && $0.day == day }
    }

    /// Ayyamul Bidh — the 13th, 14th, 15th of each lunar month, with exceptions:
    /// - Ramadan: absorbed by the obligatory fast, no separate days.
    /// - Dhu al-Hijjah: the 13th is a Day of Tasyrik (fasting prohibited);
    ///   only the 14th and 15th are kept.
    static func ayyamulBidh(monthIndex: Int) -> [Int] {
        switch monthIndex {
        case 8:  return []        // Ramadan
        case 11: return [14, 15]  // Dhu al-Hijjah (13th forbidden)
        default: return [13, 14, 15]
        }
    }

    static func fastRule(day: Int, monthIndex: Int) -> FastRule {
        if monthIndex == 11 && day == 13 { return .forbidden }
        if monthIndex == 8 { return .obligatory }
        if ayyamulBidh(monthIndex: monthIndex).contains(day) { return .sunnahFasting }
        switch (monthIndex, day) {
        case (0, 10), (11, 9): return .sunnahFasting  // Ashura, Arafah
        default: return .none
        }
    }

    /// Dot color marker for a grid cell. nil = no marker.
    static func marker(forDay day: Int, monthIndex: Int) -> Marker? {
        if event(onDay: day, monthIndex: monthIndex) != nil { return .event }
        switch fastRule(day: day, monthIndex: monthIndex) {
        case .sunnahFasting: return .sunnahFast
        case .forbidden:     return .forbiddenFast
        default:             return nil
        }
    }

    enum Marker {
        case event          // orange
        case sunnahFast     // green
        case forbiddenFast  // red
    }

    /// Next events from a given moment, up to `horizonMonths` Hijri months ahead.
    static func upcoming(from info: HijriDateInfo, horizonMonths: Int = 3, limit: Int = 4) -> [(event: Event, date: Date)] {
        let hijri = HijriDateInfo.hijriCalendar
        var result: [(Event, Date)] = []

        for monthOffset in 0...horizonMonths {
            guard
                let monthDate = hijri.date(from: DateComponents(
                    year: info.year,
                    month: info.monthIndex + 1 + monthOffset,
                    day: 1))
            else { continue }
            let comps = hijri.dateComponents([.year, .month], from: monthDate)
            guard let y = comps.year, let m = comps.month else { continue }

            for event in events(inMonth: m - 1) {
                guard
                    let date = hijri.date(from: DateComponents(year: y, month: m, day: event.day))
                else { continue }
                // Skip events earlier than "now" only in the current month.
                if monthOffset == 0 && event.day < info.day { continue }
                result.append((event, date))
            }
        }
        return Array(result.sorted { $0.1 < $1.1 }.prefix(limit))
    }
}
