import SwiftUI

/// Settings window: area picker, calculation method and adhan notification toggles.
/// Opened via the gear button in the Jadwal Sholat panel (Settings scene + openSettings).
struct SettingsView: View {
    @EnvironmentObject private var settings: PrayerSettingsStore
    @State private var cityFilter = ""

    private var filteredCities: [IndonesianCity] {
        let query = cityFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return IndonesianCities.all }
        return IndonesianCities.all.filter {
            $0.name.lowercased().contains(query) || $0.province.lowercased().contains(query)
        }
    }

    var body: some View {
        Form {
            Section("Lokasi") {
                Picker("Kota / Area", selection: $settings.city) {
                    ForEach(filteredCities) { city in
                        Text(city.menuTitle).tag(city)
                    }
                }
                TextField("Cari kota atau provinsi…", text: $cityFilter)
                LabeledContent("Zona Waktu") {
                    Text(settings.city.timeZoneIdentifier)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Perhitungan") {
                Picker("Metode", selection: $settings.method) {
                    ForEach(CalculationMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                Picker("Mazhab Ashar", selection: $settings.hanafiAsr) {
                    Text("Syafi'i (bayangan 1)").tag(false)
                    Text("Hanafi (bayangan 2)").tag(true)
                }
            }

            Section("Pengingat Adzan") {
                Toggle("Aktifkan notifikasi adzan", isOn: $settings.notificationsEnabled)
                if settings.notificationsEnabled {
                    ForEach(PrayerKind.adhan) { kind in
                        Toggle(kind.displayName, isOn: kindBinding(kind))
                    }
                    Text("Notifikasi muncul tiap waktu sholat selama 7 hari ke depan, lalu dijadwalkan ulang otomatis. Izinkan notifikasi untuk aplikasi ini di System Settings bila diminta.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Menu Bar") {
                Toggle("Tampilkan sholat berikutnya di menu bar",
                       isOn: $settings.showInMenuBar)
            }
        }
        .formStyle(.grouped)
        .frame(width: 430, height: 420)
    }

    private func kindBinding(_ kind: PrayerKind) -> Binding<Bool> {
        Binding(
            get: { settings.adhanKinds.contains(kind) },
            set: { newValue in
                if newValue {
                    settings.adhanKinds.insert(kind)
                } else {
                    settings.adhanKinds.remove(kind)
                }
            }
        )
    }
}
