import Foundation
import Combine

/// User preferences for Jadwal Sholat, persisted in standard UserDefaults
/// (only the menu bar app reads them — the widget keeps using Shared/ only).
@MainActor
final class PrayerSettingsStore: ObservableObject {
    static let shared = PrayerSettingsStore()

    private enum Key {
        static let cityID = "prayer.cityID"
        static let method = "prayer.method"
        static let hanafiAsr = "prayer.hanafiAsr"
        static let notificationsEnabled = "prayer.notificationsEnabled"
        static let adhanKinds = "prayer.adhanKinds"
        static let adhanAudioEnabled = "prayer.adhanAudioEnabled"
        static let adhanReciterID = "prayer.adhanReciterID"
        static let showInMenuBar = "prayer.showInMenuBar"
        static let showGregorianDates = "calendar.showGregorianDates"
    }

    @Published var city: IndonesianCity {
        didSet { UserDefaults.standard.set(city.id, forKey: Key.cityID) }
    }
    @Published var method: CalculationMethod {
        didSet { UserDefaults.standard.set(method.rawValue, forKey: Key.method) }
    }
    @Published var hanafiAsr: Bool {
        didSet { UserDefaults.standard.set(hanafiAsr, forKey: Key.hanafiAsr) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }
    @Published var adhanKinds: Set<PrayerKind> {
        didSet {
            UserDefaults.standard.set(adhanKinds.map(\.rawValue).sorted(), forKey: Key.adhanKinds)
        }
    }
    @Published var adhanAudioEnabled: Bool {
        didSet { UserDefaults.standard.set(adhanAudioEnabled, forKey: Key.adhanAudioEnabled) }
    }
    @Published var adhanReciterID: String {
        didSet { UserDefaults.standard.set(adhanReciterID, forKey: Key.adhanReciterID) }
    }
    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: Key.showInMenuBar) }
    }
    @Published var showGregorianDates: Bool {
        didSet { UserDefaults.standard.set(showGregorianDates, forKey: Key.showGregorianDates) }
    }

    var location: PrayerLocation {
        PrayerLocation(latitude: city.latitude,
                       longitude: city.longitude,
                       timeZone: city.timeZone)
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedCityID = defaults.string(forKey: Key.cityID) ?? IndonesianCities.defaultCity.id
        city = IndonesianCities.city(id: storedCityID) ?? IndonesianCities.defaultCity
        method = defaults.string(forKey: Key.method)
            .flatMap(CalculationMethod.init(rawValue:)) ?? .kemenag
        hanafiAsr = defaults.object(forKey: Key.hanafiAsr) as? Bool ?? false
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? false
        let storedKinds = defaults.stringArray(forKey: Key.adhanKinds)
            ?? PrayerKind.adhan.map(\.rawValue)
        adhanKinds = Set(storedKinds.compactMap(PrayerKind.init(rawValue:)))
        adhanAudioEnabled = defaults.object(forKey: Key.adhanAudioEnabled) as? Bool ?? true
        adhanReciterID = defaults.string(forKey: Key.adhanReciterID) ?? AdhanCatalog.defaultReciterID
        showInMenuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? true
        showGregorianDates = defaults.object(forKey: Key.showGregorianDates) as? Bool ?? true
    }
}
