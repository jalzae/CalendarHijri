import SwiftUI

/// Popup shown from the menu bar icon: navigable Hijri month,
/// event markers, Ayyamul Bidh dots and an upcoming-events list.
struct MenuBarCalendarView: View {
    @State private var monthOffset = 0

    private var todayInfo: HijriDateInfo { HijriDateInfo.make(for: Date()) }

    /// First day of the displayed Hijri month.
    private var displayInfo: HijriDateInfo {
        let hijri = HijriDateInfo.hijriCalendar
        let anchor = hijri.date(from: DateComponents(
            year: todayInfo.year, month: todayInfo.monthIndex + 1, day: 1)) ?? Date()
        let shifted = hijri.date(byAdding: .month, value: monthOffset, to: anchor) ?? anchor
        return HijriDateInfo.make(for: shifted)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayRow
            monthGrid
            legend
            Divider()
            todayLine
            UpcomingList(offset: monthOffset)
        }
        .padding(14)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Previous month")

            VStack(spacing: 1) {
                Text("\(displayInfo.monthName) \(displayInfo.year) AH")
                    .font(.system(size: 14, weight: .bold))
                Text("\(displayInfo.monthNameArabic) · \(displayInfo.daysInMonth) days")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Next month")
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.prefix(1))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Grid

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(displayInfo.gridCells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    PopupDayCell(day: day, display: displayInfo, today: todayInfo)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: .orange, text: "Event")
            legendItem(color: .green, text: "Sunnah fast")
            legendItem(color: .red, text: "No fast")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    // MARK: Today line

    private var todayLine: some View {
        let status = DayStatusText(info: todayInfo)
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(todayInfo.weekdayName), \(todayInfo.gregorianText)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(todayInfo.day) \(todayInfo.monthName) \(todayInfo.year) AH")
                    .font(.system(size: 12, weight: .semibold))
            }
            Spacer()
            Text(status.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(status.color)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
    }
}

// MARK: - Day cell

private struct PopupDayCell: View {
    let day: Int
    let display: HijriDateInfo
    let today: HijriDateInfo

    private var isToday: Bool {
        display.monthIndex == today.monthIndex
            && display.year == today.year
            && day == today.day
    }

    private var markerColor: Color? {
        switch IslamicEvents.marker(forDay: day, monthIndex: display.monthIndex) {
        case .event:         return .orange
        case .sunnahFast:    return .green
        case .forbiddenFast: return .red
        case nil:            return nil
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 13, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: 26, height: 26)
                .background {
                    if isToday {
                        Circle().fill(Color.green)
                    }
                }
            RoundedRectangle(cornerRadius: 1.5)
                .fill(markerColor ?? .clear)
                .frame(width: 14, height: 3)
                .opacity(markerColor == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Upcoming events

private struct UpcomingList: View {
    let offset: Int
    @State private var items: [(event: IslamicEvents.Event, date: Date)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Upcoming")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(items, id: \.event.id) { item in
                HStack {
                    Circle().fill(Color.orange).frame(width: 5, height: 5)
                    Text(item.event.name)
                        .font(.system(size: 11))
                    Spacer()
                    Text(label(for: item))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if items.isEmpty {
                Text("No events in the next few months")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: reload)
        .onChange(of: offset) { _, _ in reload() }
    }

    private func reload() {
        items = IslamicEvents.upcoming(from: HijriDateInfo.make(for: Date()),
                                       horizonMonths: 4, limit: 4)
    }

    private func label(for item: (event: IslamicEvents.Event, date: Date)) -> String {
        let comps = HijriDateInfo.hijriCalendar.dateComponents([.day, .month], from: item.date)
        let month = HijriDateInfo.monthNames[(comps.month ?? 1) - 1]
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "\(comps.day ?? 0) \(month) · \(fmt.string(from: item.date))"
    }
}
