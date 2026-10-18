import Foundation
import Combine

/// One amal yaumi (daily deed) the user wants to keep up every day.
struct AmalItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// How many repetitions make the amal "done" for the day (e.g. 100× istighfar).
    var targetPerDay: Int = 1
    /// SF Symbol name shown next to the amal.
    var symbol: String = "checkmark.circle.fill"
    var createdAt: Date = Date()
}

/// A single day's progress for one amal. Keyed by "yyyy-MM-dd".
struct AmalEntry: Codable, Hashable {
    var itemID: UUID
    var day: String
    var count: Int
}

/// Daily completion snapshot per amal, kept so streaks survive item renames
/// even after days without opening the popup.
struct AmalYaumiStats: Hashable {
    var doneToday: Int
    var targetPerDay: Int
    /// Days completed within the last 30 days (today included).
    var doneDays30: Int
    /// Consecutive completed days ending today or yesterday.
    var currentStreak: Int
    /// Share of the last 7 days completed, 0...1.
    var weekRate: Double
    var isDoneToday: Bool { doneToday >= targetPerDay }
    /// Not done today, or less than half of the last week completed.
    var needsAttention: Bool { !isDoneToday || weekRate < 0.5 }
}

/// CRUD + daily log for amal yaumi, persisted as JSON in standard UserDefaults
/// (same idiom as PrayerSettingsStore — only the menu bar app reads them).
@MainActor
final class AmalYaumiStore: ObservableObject {
    static let shared = AmalYaumiStore()

    private enum Key {
        static let items = "amal.items"
        static let entries = "amal.entries"
    }

    static let symbolChoices = [
        "checkmark.circle.fill", "book.fill", "heart.fill", "hands.and.sparkles.fill" ,
        "drop.fill", "moon.stars.fill", "sun.max.fill", "sparkles", "leaf.fill", "building.columns.fill",
    ]

    @Published var items: [AmalItem] {
        didSet { persist(items, forKey: Key.items) }
    }
    @Published var entries: [AmalEntry] {
        didSet { persist(entries, forKey: Key.entries) }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Key.items),
           let stored = try? JSONDecoder().decode([AmalItem].self, from: data) {
            items = stored
        } else {
            items = AmalYaumiStore.defaultItems
        }
        if let data = defaults.data(forKey: Key.entries),
           let stored = try? JSONDecoder().decode([AmalEntry].self, from: data) {
            entries = stored
        } else {
            entries = []
        }
        pruneOldEntries(keepingDays: 180)
    }

    /// Keeps the UserDefaults payload small — streaks/trends only look back ~30 days.
    private func pruneOldEntries(keepingDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -keepingDays, to: Date()) ?? Date()
        let cutoffKey = Self.dayKey(cutoff)
        let filtered = entries.filter { $0.day >= cutoffKey }
        if filtered.count != entries.count {
            entries = filtered
        }
    }

    private static let defaultItems: [AmalItem] = [
        AmalItem(name: "Sholawat", targetPerDay: 33, symbol: "heart.fill"),
        AmalItem(name: "Istighfar", targetPerDay: 100, symbol: "sparkles"),
        AmalItem(name: "Tilawah Al-Qur'an", targetPerDay: 1, symbol: "book.fill"),
        AmalItem(name: "Dzikir Pagi", targetPerDay: 1, symbol: "sun.max.fill"),
        AmalItem(name: "Dzikir Petang", targetPerDay: 1, symbol: "moon.stars.fill"),
        AmalItem(name: "Sedekah", targetPerDay: 1, symbol: "drop.fill"),
    ]

    private func persist(_ value: some Encodable, forKey key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    // MARK: - Day helpers

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    // MARK: - Daily progress

    func count(for itemID: UUID, on date: Date = Date()) -> Int {
        let day = Self.dayKey(date)
        return entries.first { $0.itemID == itemID && $0.day == day }?.count ?? 0
    }

    private func setCount(_ count: Int, for itemID: UUID, on date: Date) {
        let day = Self.dayKey(date)
        entries.removeAll { $0.itemID == itemID && $0.day == day }
        if count > 0 {
            entries.append(AmalEntry(itemID: itemID, day: day, count: count))
        }
    }

    func increment(_ item: AmalItem, on date: Date = Date()) {
        setCount(count(for: item.id, on: date) + 1, for: item.id, on: date)
    }

    func decrement(_ item: AmalItem, on date: Date = Date()) {
        setCount(max(0, count(for: item.id, on: date) - 1), for: item.id, on: date)
    }

    /// Toggle for target-1 amal (checkbox behaviour).
    func toggle(_ item: AmalItem, on date: Date = Date()) {
        let done = count(for: item.id, on: date) >= item.targetPerDay
        setCount(done ? 0 : item.targetPerDay, for: item.id, on: date)
    }

    /// Marks the whole day as done — used by "tandai selesai" in the manager.
    func complete(_ item: AmalItem, on date: Date = Date()) {
        setCount(item.targetPerDay, for: item.id, on: date)
    }

    func reset(_ item: AmalItem, on date: Date = Date()) {
        setCount(0, for: item.id, on: date)
    }

    // MARK: - CRUD

    func add(name: String, symbol: String, targetPerDay: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(AmalItem(name: trimmed,
                              targetPerDay: max(1, targetPerDay),
                              symbol: symbol))
    }

    func update(_ item: AmalItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    func delete(_ item: AmalItem) {
        items.removeAll { $0.id == item.id }
        entries.removeAll { $0.itemID == item.id }
    }

    // MARK: - Statistics

    func stats(for item: AmalItem, on date: Date = Date()) -> AmalYaumiStats {
        let calendar = Calendar.current
        let today = count(for: item.id, on: date)

        var doneDays30 = 0
        for offset in 0..<30 {
            let day = calendar.date(byAdding: .day, value: -offset, to: date) ?? date
            if count(for: item.id, on: day) >= item.targetPerDay { doneDays30 += 1 }
        }

        var streak = 0
        var streakOffset = count(for: item.id, on: date) >= item.targetPerDay ? 0 : 1
        while streakOffset < 365 {
            let day = calendar.date(byAdding: .day, value: -streakOffset, to: date) ?? date
            guard count(for: item.id, on: day) >= item.targetPerDay else { break }
            streak += 1
            streakOffset += 1
        }

        var weekDone = 0
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -offset, to: date) ?? date
            if count(for: item.id, on: day) >= item.targetPerDay { weekDone += 1 }
        }

        return AmalYaumiStats(doneToday: today,
                              targetPerDay: item.targetPerDay,
                              doneDays30: doneDays30,
                              currentStreak: streak,
                              weekRate: Double(weekDone) / 7.0)
    }

    /// Amal that still need attention today: unfinished, weakest streak first.
    func needingAttention(on date: Date = Date()) -> [AmalItem] {
        items
            .filter { !stats(for: $0, on: date).isDoneToday }
            .sorted { stats(for: $0, on: date).currentStreak < stats(for: $1, on: date).currentStreak }
    }

    /// Completion for each of the last `days` days (oldest first) — the mini bars.
    func completionTrend(item: AmalItem, days: Int = 14, on date: Date = Date()) -> [Double] {
        let calendar = Calendar.current
        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: offset - days + 1, to: date) ?? date
            return count(for: item.id, on: day) >= item.targetPerDay ? 1.0 : 0.0
        }
    }

    var todaySummaryText: String {
        let done = items.filter { stats(for: $0).isDoneToday }.count
        return "\(done)/\(items.count)"
    }
}
