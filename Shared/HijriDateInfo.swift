import Foundation

/// All data the widget (and the app preview) needs for one moment in time,
/// computed from the Umm al-Qura Hijri calendar built into macOS.
struct HijriDateInfo {
    let day: Int
    let monthIndex: Int          // 0...11
    let year: Int
    let monthName: String        // transliterated
    let monthNameArabic: String
    let weekdayName: String
    let gregorianText: String
    let daysInMonth: Int
    let firstWeekdayIndex: Int   // 0 = Sunday
    let isToday: Bool

    static let monthNames = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
    ]

    static let monthNamesIndonesian = [
        "Muharam", "Safar", "Rabiul Awal", "Rabiul Akhir",
        "Jumadil Awal", "Jumadil Akhir", "Rajab", "Sya'ban",
        "Ramadhan", "Syawal", "Dzulqa'dah", "Dzulhijjah"
    ]

    static let monthNamesArabic = [
        "محرم", "صفر", "ربيع الأول", "ربيع الثاني",
        "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
        "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
    ]

    static let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)

    static func make(for date: Date) -> HijriDateInfo {
        let hijri = hijriCalendar
        let gregorian = Calendar(identifier: .gregorian)

        let comps = hijri.dateComponents([.day, .month, .year], from: date)
        let day = comps.day ?? 1
        let monthIndex = (comps.month ?? 1) - 1
        let year = comps.year ?? 1

        let monthStart = hijri.date(from: DateComponents(
            year: comps.year, month: comps.month, day: 1)) ?? date
        let daysInMonth = hijri.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = gregorian.component(.weekday, from: monthStart) - 1 // 0 = Sunday

        let weekdayName = gregorian.weekdaySymbols[gregorian.component(.weekday, from: date) - 1]

        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateStyle = .full
        let gregorianText = fmt.string(from: date)

        let startOfToday = gregorian.startOfDay(for: Date())
        let isToday = gregorian.isDate(date, inSameDayAs: startOfToday)

        return HijriDateInfo(
            day: day,
            monthIndex: monthIndex,
            year: year,
            monthName: monthNames[monthIndex],
            monthNameArabic: monthNamesArabic[monthIndex],
            weekdayName: weekdayName,
            gregorianText: gregorianText,
            daysInMonth: daysInMonth,
            firstWeekdayIndex: firstWeekday,
            isToday: isToday
        )
    }

    var yearText: String { "\(year) AH" }

    /// Day numbers laid out in a 7-column grid; nil = empty leading cell.
    var gridCells: [Int?] {
        Array(repeating: nil, count: firstWeekdayIndex)
            + Array(1...daysInMonth)
    }
}
