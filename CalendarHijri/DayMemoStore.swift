import Foundation
import Combine

/// Per-day memos shown when clicking a date in the popup calendar.
/// Keyed by Gregorian "yyyy-MM-dd" (each Hijri cell in the grid maps to one
/// Gregorian day), persisted as JSON in standard UserDefaults.
@MainActor
final class DayMemoStore: ObservableObject {
    static let shared = DayMemoStore()

    private enum Key {
        static let memos = "calendar.dayMemos"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    @Published private(set) var memos: [String: String]

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Key.memos),
           let stored = try? JSONDecoder().decode([String: String].self, from: data) {
            memos = stored
        } else {
            memos = [:]
        }
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(memos), forKey: Key.memos)
    }

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    func memo(for date: Date) -> String? {
        memos[Self.dayKey(date)]
    }

    func hasMemo(day dayKey: String) -> Bool {
        !(memos[dayKey] ?? "").isEmpty
    }

    /// Empty text deletes the memo.
    func setMemo(_ text: String, for date: Date) {
        let key = Self.dayKey(date)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            memos[key] = nil
        } else {
            memos[key] = text
        }
        persist()
    }
}
