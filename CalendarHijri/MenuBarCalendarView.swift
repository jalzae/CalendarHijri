import SwiftUI

/// Popup shown from the menu bar icon: navigable Hijri month with optional
/// Gregorian day numbers, per-day memos, event markers, Ayyamul Bidh dots
/// and an upcoming-events list.
struct MenuBarCalendarView: View {
    @EnvironmentObject private var settings: PrayerSettingsStore
    @EnvironmentObject private var memoStore: DayMemoStore
    @State private var monthOffset = 0
    @State private var selectedDay: Int?

    private var todayInfo: HijriDateInfo { HijriDateInfo.make(for: Date()) }

    /// Gregorian date a Hijri grid cell falls on.
    fileprivate func gregorianDate(forDay day: Int, in display: HijriDateInfo) -> Date? {
        HijriDateInfo.hijriCalendar.date(from: DateComponents(
            year: display.year, month: display.monthIndex + 1, day: day))
    }

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
            if let selectedDay, let memoDate = gregorianDate(forDay: selectedDay, in: displayInfo) {
                Divider()
                DayMemoEditor(day: selectedDay, display: displayInfo, date: memoDate) {
                    self.selectedDay = nil
                }
                .id(selectedDay)
            }
            Divider()
            todayLine
            Divider()
            PrayerTimesPanel()
            Divider()
            AmalYaumiPanel()
            Divider()
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
                    let memoDate = gregorianDate(forDay: day, in: displayInfo)
                    PopupDayCell(day: day,
                                 display: displayInfo,
                                 today: todayInfo,
                                 showGregorian: settings.showGregorianDates,
                                 isSelected: selectedDay == day,
                                 hasMemo: memoDate.map { memoStore.hasMemo(day: DayMemoStore.dayKey($0)) } ?? false,
                                 onSelect: {
                                     selectedDay = selectedDay == day ? nil : day
                                 })
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
    let showGregorian: Bool
    let isSelected: Bool
    let hasMemo: Bool
    let onSelect: () -> Void

    private var isToday: Bool {
        display.monthIndex == today.monthIndex
            && display.year == today.year
            && day == today.day
    }

    /// Gregorian day number shown under the Hijri day to learn the mapping.
    private var gregorianDay: Int? {
        guard showGregorian else { return nil }
        let date = HijriDateInfo.hijriCalendar.date(from: DateComponents(
            year: display.year, month: display.monthIndex + 1, day: day))
        return date.map { Calendar.current.component(.day, from: $0) }
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
                    } else if isSelected {
                        Circle().strokeBorder(Color.green, lineWidth: 1.5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if hasMemo {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                            .offset(x: 3, y: -1)
                    }
                }
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(markerColor ?? .clear)
                    .frame(width: 14, height: 3)
                    .opacity(markerColor == nil ? 0 : 1)
                if let gregorianDay {
                    Text("\(gregorianDay)")
                        .font(.system(size: 8, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help(hasMemo ? "Buka memo hari ini" : "Klik untuk tulis memo")
    }
}

// MARK: - Day memo editor

/// Inline memo editor for the clicked date: typing saves automatically,
/// clearing the text deletes the memo.
private struct DayMemoEditor: View {
    @EnvironmentObject private var memoStore: DayMemoStore
    let day: Int
    let display: HijriDateInfo
    let date: Date
    let onClose: () -> Void

    @State private var text = ""

    private var title: String {
        let gregorian = DateFormatter()
        gregorian.dateFormat = "d MMM yyyy"
        return "\(day) \(display.monthName) · \(gregorian.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("Memo · \(title)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    memoStore.setMemo("", for: date)
                    text = ""
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hapus memo")
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Tutup")
            }
            TextEditor(text: $text)
                .font(.system(size: 11))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.3))
                )
                .onChange(of: text) { _, newValue in
                    memoStore.setMemo(newValue, for: date)
                }
        }
        .onAppear {
            text = memoStore.memo(for: date) ?? ""
        }
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
