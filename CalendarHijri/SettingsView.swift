import SwiftUI

/// Settings window: area picker, calculation method and adhan notification toggles.
/// Opened via the gear button in the Jadwal Sholat panel (Settings scene + openSettings).
struct SettingsView: View {
    @EnvironmentObject private var settings: PrayerSettingsStore
    @ObservedObject private var adhanPlayer = AdhanPlayer.shared
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

            Section("Suara Adzan") {
                Toggle("Putar audio adzan saat masuk waktu",
                       isOn: $settings.adhanAudioEnabled)
                if settings.adhanAudioEnabled {
                    Picker("Murottal adzan", selection: $settings.adhanReciterID) {
                        ForEach(AdhanCatalog.reciters) { reciter in
                            Text(reciterStateTitle(reciter)).tag(reciter.id)
                        }
                    }
                    Text("Audio (~0,7 MB) diunduh sekali lalu diputar langsung saat masuk waktu sholat. Butuh koneksi internet untuk unduhan pertama.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            if adhanPlayer.playingReciterID == settings.adhanReciterID {
                                adhanPlayer.stop()
                            } else {
                                adhanPlayer.play(reciterID: settings.adhanReciterID)
                            }
                        } label: {
                            Label(adhanPlayer.playingReciterID == settings.adhanReciterID
                                  ? "Stop" : "Uji Coba",
                                  systemImage: adhanPlayer.playingReciterID == settings.adhanReciterID
                                  ? "stop.fill" : "play.fill")
                        }
                        .disabled(downloadInProgress)

                        if case let .downloading(progress) = adhanPlayer.state(for: settings.adhanReciterID) {
                            ProgressView(value: progress)
                                .frame(maxWidth: 120)
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Kalender") {
                Toggle("Tampilkan tanggal Masehi", isOn: $settings.showGregorianDates)
                Text("Menampilkan angka tanggal Masehi di bawah tanggal Hijriah pada kalender popup, supaya makin hafal padanannya.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar") {
                Toggle("Tampilkan sholat berikutnya di menu bar",
                       isOn: $settings.showInMenuBar)
            }
        }
        .formStyle(.grouped)
        .frame(width: 430, height: 560)
        .onChange(of: settings.adhanReciterID) { _, newID in
            // Kick off the download right away so the adhan is ready in time.
            if let reciter = AdhanCatalog.reciter(id: newID) {
                Task { await adhanPlayer.ensureDownloaded(reciter) }
            }
        }
    }

    private var downloadInProgress: Bool {
        if case .downloading = adhanPlayer.state(for: settings.adhanReciterID) { return true }
        return false
    }

    /// Picker title with the download state, e.g. "Adzan 9 — tersimpan".
    private func reciterStateTitle(_ reciter: AdhanReciter) -> String {
        switch adhanPlayer.state(for: reciter.id) {
        case .ready:            return "\(reciter.name) · tersimpan"
        case .downloading:      return "\(reciter.name) · mengunduh…"
        case .failed:           return "\(reciter.name) · gagal, coba lagi"
        case .notDownloaded:    return reciter.name
        }
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
