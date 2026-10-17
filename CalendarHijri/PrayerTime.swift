import Foundation

// MARK: - Prayer kinds

/// Rows shown in the jadwal panel. `.terbit` is sunrise — display only, never alarmed.
enum PrayerKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case subuh, terbit, dzuhur, ashar, maghrib, isya

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subuh: "Subuh"
        case .terbit: "Terbit"
        case .dzuhur: "Dzuhur"
        case .ashar: "Ashar"
        case .maghrib: "Maghrib"
        case .isya: "Isya"
        }
    }

    /// The five adhan prayers, in day order.
    static let adhan: [PrayerKind] = [.subuh, .dzuhur, .ashar, .maghrib, .isya]
}

// MARK: - Calculation methods

/// Standard prayer-time conventions. `kemenag` is the Indonesian default (Fajr 20°, Isha 18°).
enum CalculationMethod: String, CaseIterable, Identifiable {
    case kemenag, mwl, egypt, isna, ummAlQura, karachi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kemenag: "Kemenag RI (Indonesia)"
        case .mwl: "Muslim World League"
        case .egypt: "Otoritas Mesir"
        case .isna: "ISNA (Amerika Utara)"
        case .ummAlQura: "Umm al-Qura (Makkah)"
        case .karachi: "Karachi"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .kemenag: 20
        case .mwl, .karachi: 18
        case .egypt: 19.5
        case .isna: 15
        case .ummAlQura: 18.5
        }
    }

    /// `nil` means Isha is Maghrib plus `ishaIntervalMinutes`.
    var ishaAngle: Double? {
        switch self {
        case .kemenag: 18
        case .mwl, .karachi: 18
        case .egypt: 17.5
        case .isna: 15
        case .ummAlQura: nil
        }
    }

    var ishaIntervalMinutes: Int? { self == .ummAlQura ? 90 : nil }

    /// Kemenag schedules Dhuhr a couple of minutes after true meridian transit.
    var dhuhrOffsetMinutes: Double { self == .kemenag ? 2 : 0 }
}

// MARK: - Location

struct PrayerLocation {
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
}

// MARK: - Result

struct PrayerTime: Identifiable, Hashable {
    let kind: PrayerKind
    let date: Date

    var id: String { kind.rawValue }
}

// MARK: - Calculator

/// Solar-position prayer times (PrayTimes.org algorithm, one refinement pass).
/// All intermediate math is in wall-clock hours of the location's time zone.
enum PrayerTimeCalculator {

    static func times(for date: Date,
                      location: PrayerLocation,
                      method: CalculationMethod,
                      hanafiAsr: Bool) -> [PrayerTime] {
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents(in: location.timeZone, from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return [] }
        let tzHours = Double(location.timeZone.secondsFromGMT(for: date)) / 3600
        let baseJD = julianDay(year: year, month: month, day: day)

        func sunValues(_ jd: Double) -> (declination: Double, equationOfTime: Double) {
            let d = jd - 2451545.0
            let g = fixDegrees(357.529 + 0.98560028 * d)
            let q = fixDegrees(280.459 + 0.98564736 * d)
            let l = fixDegrees(q + 1.915 * sin(g.radians) + 0.020 * sin((2 * g).radians))
            let e = 23.439 - 0.00000036 * d
            let ra = atan2(cos(e.radians) * sin(l.radians), cos(l.radians)).degrees / 15
            let eqt = q / 15 - fixHours(ra)
            let decl = asin(sin(e.radians) * sin(l.radians)).degrees
            return (decl, eqt)
        }

        /// Local noon (sun transit) in wall-clock hours.
        func midDay(_ jd: Double) -> Double {
            12 + tzHours - location.longitude / 15 - sunValues(jd).equationOfTime
        }

        /// Hours from local noon until the sun sits at `angle` degrees below the horizon.
        func hourAngle(_ angle: Double, jd: Double) -> Double? {
            let decl = sunValues(jd).declination
            let numerator = -sin(angle.radians) - sin(decl.radians) * sin(location.latitude.radians)
            let denominator = cos(decl.radians) * cos(location.latitude.radians)
            let value = numerator / denominator
            guard value > -1, value < 1 else { return nil }
            return acos(value).degrees / 15
        }

        /// `fractions` seeds each prayer with its own hour-of-day for the solar-position
        /// refinement pass; `nil` gives the coarse first pass.
        func computeAll(fractions: [PrayerKind: Double]?) -> [PrayerKind: Double] {
            func jd(for kind: PrayerKind, fallback: Double) -> Double {
                baseJD + (fractions?[kind] ?? fallback) / 24
            }
            let fajrJD = jd(for: .subuh, fallback: 4)
            let riseJD = jd(for: .terbit, fallback: 6)
            let noonJD = jd(for: .dzuhur, fallback: 12)
            let asrJD = jd(for: .ashar, fallback: 15)
            let ishaJD = jd(for: .isya, fallback: 19.5)

            var result: [PrayerKind: Double] = [:]
            let noon = midDay(noonJD)

            if let t = hourAngle(method.fajrAngle, jd: fajrJD) {
                result[.subuh] = noon - t
            }
            if let t = hourAngle(0.833, jd: riseJD) { // refraction + solar radius
                result[.terbit] = noon - t
                result[.maghrib] = noon + t
            }
            result[.dzuhur] = noon + method.dhuhrOffsetMinutes / 60

            // Asr: shadow length t of an object (1 = Syafi'i, 2 = Hanafi).
            let factor: Double = hanafiAsr ? 2 : 1
            let asrDecl = sunValues(asrJD).declination
            let asrAngle = -degrees(atan(1 / (factor + tan(radians(abs(location.latitude - asrDecl))))))
            if let t = hourAngle(asrAngle, jd: asrJD) {
                result[.ashar] = noon + t
            }

            if let interval = method.ishaIntervalMinutes {
                result[.isya] = (result[.maghrib] ?? noon) + Double(interval) / 60
            } else if let angle = method.ishaAngle, let t = hourAngle(angle, jd: ishaJD) {
                result[.isya] = noon + t
            }
            return result
        }

        let values = computeAll(fractions: computeAll(fractions: nil))

        return PrayerKind.allCases.compactMap { kind in
            guard var t = values[kind] else { return nil }
            t = fixHours(t)
            var hour = Int(t)
            var minute = Int(((t - Double(hour)) * 60).rounded())
            if minute >= 60 { hour += 1; minute -= 60 }
            hour %= 24
            var local = DateComponents()
            local.year = year
            local.month = month
            local.day = day
            local.hour = hour
            local.minute = minute
            local.timeZone = location.timeZone
            guard let date = calendar.date(from: local) else { return nil }
            return PrayerTime(kind: kind, date: date)
        }
    }

    /// "1j 23m" style countdown between now and `date`.
    static func countdown(until date: Date, from now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now).rounded()))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)j \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    /// Cached formatter for jadwal rows ("04.31"), rendered in the city's zone.
    static func clockText(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = cachingFormatter(timeZone: timeZone)
        return formatter.string(from: date)
    }

    private static var formatterCache: [String: DateFormatter] = [:]
    private static func cachingFormatter(timeZone: TimeZone) -> DateFormatter {
        if let cached = formatterCache[timeZone.identifier] { return cached }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm"
        formatter.timeZone = timeZone
        formatterCache[timeZone.identifier] = formatter
        return formatter
    }

    // MARK: Solar math

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year)
        var m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    private static func fixDegrees(_ value: Double) -> Double {
        let fixed = value.truncatingRemainder(dividingBy: 360)
        return fixed < 0 ? fixed + 360 : fixed
    }

    private static func fixHours(_ value: Double) -> Double {
        let fixed = value.truncatingRemainder(dividingBy: 24)
        return fixed < 0 ? fixed + 24 : fixed
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
