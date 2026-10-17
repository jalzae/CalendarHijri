import SwiftUI

/// "Jadwal Sholat" block in the popup: today's times with the next prayer
/// highlighted and its countdown, plus a gear button for the settings window.
struct PrayerTimesPanel: View {
    @EnvironmentObject private var prayer: PrayerModel
    @EnvironmentObject private var settings: PrayerSettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Jadwal Sholat")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(settings.city.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Pengaturan jadwal sholat")
            }

            ForEach(prayer.todaysTimes) { time in
                row(time)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ time: PrayerTime) -> some View {
        let isNext = prayer.next?.kind == time.kind
        return HStack(spacing: 6) {
            Circle()
                .fill(isNext ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 5, height: 5)
            Text(time.kind.displayName)
                .font(.system(size: 11, weight: isNext ? .semibold : .regular))
            Spacer()
            if isNext, let next = prayer.next {
                Text(PrayerTimeCalculator.countdown(until: next.date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.green)
            }
            Text(PrayerTimeCalculator.clockText(time.date, timeZone: settings.city.timeZone))
                .font(.system(size: 11, weight: isNext ? .semibold : .regular))
                .monospacedDigit()
        }
        .foregroundStyle(isNext ? Color.green : Color.primary)
    }
}
