import WidgetKit
import SwiftUI

// MARK: - Timeline

struct HijriEntry: TimelineEntry {
    let date: Date
}

struct HijriProvider: TimelineProvider {
    func placeholder(in context: Context) -> HijriEntry {
        HijriEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HijriEntry) -> Void) {
        completion(HijriEntry(date: Date()))
    }

    /// One entry per day for the next 7 days; refresh the day after.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HijriEntry>) -> Void) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var entries = (0..<7).compactMap { offset -> HijriEntry? in
            cal.date(byAdding: .day, value: offset, to: today).map(HijriEntry.init)
        }
        if entries.isEmpty { entries = [HijriEntry(date: Date())] }

        let refresh = cal.date(byAdding: .day, value: 7, to: today) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - Widget

struct HijriWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HijriWidget", provider: HijriProvider()) { entry in
            HijriWidgetView(entry: entry)
        }
        .configurationDisplayName("Hijri Calendar")
        .description("Today's Hijri date with Islamic events and Ayyamul Bidh fasting days.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Root view

struct HijriWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HijriEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [Color.green.opacity(0.18), Color.teal.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:  SmallView(info: HijriDateInfo.make(for: entry.date))
        case .systemMedium: MediumView(info: HijriDateInfo.make(for: entry.date))
        default:            LargeView(info: HijriDateInfo.make(for: entry.date))
        }
    }
}

// MARK: - Day status (today line)

private struct DayStatus {
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
            text = info.monthIndex == 0
                ? "Sunnah fast" : "Ayyamul Bidh · Sunnah fast"
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

// MARK: - Small: date + status

private struct SmallView: View {
    let info: HijriDateInfo
    private var status: DayStatus { DayStatus(info: info) }

    var body: some View {
        VStack(spacing: 2) {
            Text(info.weekdayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("\(info.day)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .minimumScaleFactor(0.6)

            Text("\(info.monthName) \(info.year)")
                .font(.system(size: 12, weight: .semibold))

            Text(status.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(status.color)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Medium: date + mini month grid

private struct MediumView: View {
    let info: HijriDateInfo
    private var status: DayStatus { DayStatus(info: info) }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.weekdayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("\(info.day)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text("\(info.monthName) \(info.year)")
                    .font(.system(size: 13, weight: .semibold))
                Text(status.text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(status.color)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            MiniMonthGrid(info: info)
                .frame(maxWidth: 175)
        }
        .padding(2)
    }
}

// MARK: - Large: full month grid + upcoming events

private struct LargeView: View {
    let info: HijriDateInfo

    var body: some View {
        VStack(spacing: 5) {
            VStack(spacing: 0) {
                Text("\(info.monthName) \(info.yearText)")
                    .font(.system(size: 16, weight: .bold))
                Text("\(info.monthNameArabic) — \(info.gregorianText)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            MonthGrid(info: info)

            UpcomingEvents(info: info)
        }
    }
}

// MARK: - Upcoming events footer

private struct UpcomingEvents: View {
    let info: HijriDateInfo

    var body: some View {
        let items = IslamicEvents.upcoming(from: info, limit: 3)

        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.event.id) { item in
                HStack(spacing: 5) {
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange)
                    Text(item.event.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.event.day) \(HijriDateInfo.monthNames[item.event.monthIndex])")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .opacity(items.isEmpty ? 0 : 1)
    }
}

// MARK: - Grids

/// One day cell: number + colored dot marker underneath.
private struct DayCell: View {
    let day: Int
    let info: HijriDateInfo
    var numberFont: Font
    var cellHeight: CGFloat
    var dotHeight: CGFloat = 3

    var body: some View {
        VStack(spacing: 1) {
            Text("\(day)")
                .font(numberFont)
                .foregroundStyle(day == info.day ? Color.white : .primary)
            RoundedRectangle(cornerRadius: dotHeight / 2)
                .fill(markerColor ?? .clear)
                .frame(height: dotHeight)
                .opacity(markerColor == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight)
        .background {
            if day == info.day {
                RoundedRectangle(cornerRadius: 6).fill(Color.green)
            }
        }
    }

    private var markerColor: Color? {
        switch IslamicEvents.marker(forDay: day, monthIndex: info.monthIndex) {
        case .event:         return .orange
        case .sunnahFast:    return .green
        case .forbiddenFast: return .red
        case nil:            return nil
        }
    }
}

private struct MiniMonthGrid: View {
    let info: HijriDateInfo

    var body: some View {
        VStack(spacing: 2) {
            weekdayRow
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(info.gridCells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        DayCell(day: day, info: info,
                                numberFont: .system(size: 8),
                                cellHeight: 13, dotHeight: 2)
                    } else {
                        Color.clear.frame(minHeight: 13)
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Calendar.current.veryShortWeekdaySymbols.indices, id: \.self) { i in
                Text(Calendar.current.veryShortWeekdaySymbols[i].prefix(1))
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct MonthGrid: View {
    let info: HijriDateInfo

    var body: some View {
        VStack(spacing: 3) {
            weekdayRow
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(info.gridCells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        DayCell(day: day, info: info,
                                numberFont: .system(size: 13, weight: day == info.day ? .bold : .regular, design: .rounded),
                                cellHeight: 26, dotHeight: 3)
                    } else {
                        Color.clear.frame(minHeight: 26)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Calendar.current.veryShortWeekdaySymbols.indices, id: \.self) { i in
                Text(Calendar.current.veryShortWeekdaySymbols[i].prefix(1))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
