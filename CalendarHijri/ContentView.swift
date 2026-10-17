import SwiftUI

struct ContentView: View {
    private let info = HijriDateInfo.make(for: Date())
    private var status: DayStatusText { DayStatusText(info: info) }
    @State private var upcoming: [(event: IslamicEvents.Event, date: Date)] = []

    var body: some View {
        VStack(spacing: 18) {
            Text("Hijri Calendar")
                .font(.title2.bold())

            HStack(alignment: .top, spacing: 16) {
                // Today card
                VStack(spacing: 4) {
                    Text(info.weekdayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(info.day)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("\(info.monthName) \(info.year) AH")
                        .font(.headline)
                    Text(info.monthNameArabic)
                        .font(.title3)
                    Text(info.gregorianText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(status.text)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(status.color.opacity(0.15), in: Capsule())
                }
                .padding(20)
                .frame(width: 210)
                .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Upcoming events")
                        .font(.headline)
                    ForEach(upcoming, id: \.event.id) { item in
                        HStack {
                            Text(item.event.name)
                                .font(.callout)
                            Spacer()
                            Text(dateText(item.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if upcoming.isEmpty {
                        Text("No events in the next months")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Label("Add the widget", systemImage: "square.grid.2x2")
                        .font(.headline)
                    Text("""
                        Open Notification Center (click the clock in the \
                        menu bar) → Edit Widgets → search “Hijri”.
                        """)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
        }
        .padding(24)
        .onAppear {
            upcoming = IslamicEvents.upcoming(from: info, horizonMonths: 3, limit: 6)
        }
    }

    private func dateText(_ date: Date) -> String {
        let hijri = HijriDateInfo.hijriCalendar
        let c = hijri.dateComponents([.day, .month], from: date)
        let month = HijriDateInfo.monthNames[(c.month ?? 1) - 1]
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "\(c.day ?? 0) \(month) · \(fmt.string(from: date))"
    }
}

/// App-side copy of the widget status line (Color macOS-safe).
struct DayStatusText {
    let text: String
    let color: Color

    init(info: HijriDateInfo) {
        if let event = IslamicEvents.event(onDay: info.day, monthIndex: info.monthIndex) {
            text = "★ \(event.name)"
            color = .orange
            return
        }
        switch IslamicEvents.fastRule(day: info.day, monthIndex: info.monthIndex) {
        case .sunnahFasting:
            text = info.monthIndex == 0 ? "Sunnah fast" : "Ayyamul Bidh · Sunnah fast"
            color = .green
        case .obligatory:
            text = "Ramadan · Obligatory fast"
            color = .green
        case .forbidden:
            text = "Day of Tasyrik · No fasting"
            color = .red
        case .none:
            text = info.monthNameArabic
            color = .secondary
        }
    }
}
