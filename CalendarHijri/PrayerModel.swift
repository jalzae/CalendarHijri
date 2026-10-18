import Foundation
import Combine
import UserNotifications

/// Drives the "next prayer" countdown: today's times, the upcoming prayer and
/// the compact menu bar text. Reschedules adhan notifications when settings
/// change, at day rollover and on launch.
@MainActor
final class PrayerModel: ObservableObject {
    @Published private(set) var todaysTimes: [PrayerTime] = []
    @Published private(set) var next: PrayerTime?
    @Published private(set) var countdownText = ""
    @Published private(set) var menuBarText = ""

    private let settings: PrayerSettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var lastDay: Int = 0
    private var firedAdhanKeys: Set<String> = []

    init(settings: PrayerSettingsStore) {
        self.settings = settings

        recompute()
        PrayerScheduler.reschedule(settings: settings)

        // Warm the audio cache at launch so the adhan plays instantly at prayer
        // time instead of waiting on a download.
        if settings.adhanAudioEnabled, let reciter = AdhanCatalog.reciter(id: settings.adhanReciterID) {
            Task { await AdhanPlayer.shared.ensureDownloaded(reciter) }
        }

        // objectWillChange fires before the new value lands — the RunLoop hop
        // makes sure recompute() sees the updated settings.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                recompute()
                PrayerScheduler.reschedule(settings: self.settings)
            }
            .store(in: &cancellables)

        Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
    }

    private func tick() {
        refreshNext()
        playAdhanIfDue()
        let day = Calendar.current.component(.day, from: Date())
        if day != lastDay {
            recompute()
            PrayerScheduler.reschedule(settings: settings)
        }
    }

    /// Plays the downloaded adhan audio in-app when a prayer time is reached.
    /// The 2-minute grace window covers tick gaps without replaying stale
    /// adhan after the app sat closed through the prayer time.
    private func playAdhanIfDue() {
        guard settings.adhanAudioEnabled else { return }
        let now = Date()
        for time in todaysTimes where settings.adhanKinds.contains(time.kind) {
            let key = "\(time.kind.rawValue).\(Int(time.date.timeIntervalSince1970))"
            guard now >= time.date, now.timeIntervalSince(time.date) < 120 else { continue }
            guard firedAdhanKeys.insert(key).inserted else { continue }
            AdhanPlayer.shared.play(reciterID: settings.adhanReciterID)
        }
    }

    private func recompute() {
        let now = Date()
        todaysTimes = PrayerTimeCalculator.times(for: now,
                                                 location: settings.location,
                                                 method: settings.method,
                                                 hanafiAsr: settings.hanafiAsr)
        lastDay = Calendar.current.component(.day, from: now)
        refreshNext()
        playAdhanIfDue()
    }

    private func refreshNext() {
        let now = Date()
        let adhanTimes = todaysTimes.filter { $0.kind != .terbit }
        if let upcoming = adhanTimes.first(where: { $0.date > now }) {
            next = upcoming
        } else {
            // All of today's prayers are past — count down to tomorrow's Subuh.
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrowTimes = PrayerTimeCalculator.times(for: tomorrow,
                                                           location: settings.location,
                                                           method: settings.method,
                                                           hanafiAsr: settings.hanafiAsr)
            next = tomorrowTimes.first { $0.kind == .subuh }
        }
        updateTexts()
    }

    private func updateTexts() {
        guard let next else {
            countdownText = ""
            menuBarText = ""
            return
        }
        let remaining = PrayerTimeCalculator.countdown(until: next.date)
        countdownText = "dalam \(remaining)"
        menuBarText = settings.showInMenuBar
            ? "\(next.kind.displayName) \(remaining)"
            : ""
    }
}

// MARK: - Adhan notifications

/// Schedules one adhan notification per enabled prayer for the next 7 days,
/// then refreshes on day rollover / settings change so the drift stays ~zero.
enum PrayerScheduler {
    private static let idPrefix = "prayer.adhan."
    private static let horizonDays = 7

    @MainActor
    static func reschedule(settings: PrayerSettingsStore) {
        let center = UNUserNotificationCenter.current()
        Task {
            // Drop everything pending, then re-add for the current settings.
            let pending = await center.pendingNotificationRequests()
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            guard settings.notificationsEnabled, !settings.adhanKinds.isEmpty else { return }
            guard await authorized(center) else { return }

            let calendar = Calendar.current
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyyMMdd"

            for offset in 0...horizonDays {
                let day = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                let times = PrayerTimeCalculator.times(for: day,
                                                       location: settings.location,
                                                       method: settings.method,
                                                       hanafiAsr: settings.hanafiAsr)
                for time in times where settings.adhanKinds.contains(time.kind) {
                    guard time.date > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "Waktu \(time.kind.displayName)"
                    content.body = "Telah masuk waktu sholat \(time.kind.displayName) — \(settings.city.name)."
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(
                        dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                              from: time.date),
                        repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "\(idPrefix)\(time.kind.rawValue).\(dayFormatter.string(from: day))",
                        content: content,
                        trigger: trigger)
                    try? await center.add(request)
                }
            }
        }
    }

    private static func authorized(_ center: UNUserNotificationCenter) async -> Bool {
        let status = await center.notificationSettings()
        switch status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }
}

/// Shows adhan banners even while the app's popup is frontmost.
final class PrayerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PrayerNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
