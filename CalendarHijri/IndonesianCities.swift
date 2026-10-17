import Foundation

/// Bundled Indonesian cities for the Jadwal Sholat area picker.
/// Coordinates are city centers; precision of ~0.05° shifts times by well under a minute.
struct IndonesianCity: Identifiable, Hashable {
    let id: String
    let name: String
    let province: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
    var menuTitle: String { "\(name) — \(province)" }
}

enum IndonesianCities {
    static let all: [IndonesianCity] = [
        // Sumatra (WIB)
        City("id-bandaaceh", "Banda Aceh", "Aceh", 5.5483, 95.3238, "Asia/Jakarta"),
        City("id-medan", "Medan", "Sumatera Utara", 3.5952, 98.6722, "Asia/Jakarta"),
        City("id-padang", "Padang", "Sumatera Barat", -0.9471, 100.4172, "Asia/Jakarta"),
        City("id-pekanbaru", "Pekanbaru", "Riau", 0.5071, 101.4478, "Asia/Jakarta"),
        City("id-batam", "Batam", "Kepulauan Riau", 1.1300, 104.0533, "Asia/Jakarta"),
        City("id-jambi", "Jambi", "Jambi", -1.6101, 103.6131, "Asia/Jakarta"),
        City("id-palembang", "Palembang", "Sumatera Selatan", -2.9761, 104.7754, "Asia/Jakarta"),
        City("id-bengkulu", "Bengkulu", "Bengkulu", -3.8004, 102.2655, "Asia/Jakarta"),
        City("id-bandarlampung", "Bandar Lampung", "Lampung", -5.4292, 105.2611, "Asia/Jakarta"),
        City("id-pangkalpinang", "Pangkalpinang", "Kep. Bangka Belitung", -2.1291, 106.1062, "Asia/Jakarta"),

        // Java (WIB)
        City("id-jakarta", "Jakarta", "DKI Jakarta", -6.2088, 106.8456, "Asia/Jakarta"),
        City("id-serang", "Serang", "Banten", -6.1203, 106.1504, "Asia/Jakarta"),
        City("id-bekasi", "Bekasi", "Jawa Barat", -6.2383, 106.9756, "Asia/Jakarta"),
        City("id-depok", "Depok", "Jawa Barat", -6.4025, 106.7942, "Asia/Jakarta"),
        City("id-bogor", "Bogor", "Jawa Barat", -6.5950, 106.8166, "Asia/Jakarta"),
        City("id-bandung", "Bandung", "Jawa Barat", -6.9175, 107.6191, "Asia/Jakarta"),
        City("id-cirebon", "Cirebon", "Jawa Barat", -6.7320, 108.5523, "Asia/Jakarta"),
        City("id-semarang", "Semarang", "Jawa Tengah", -6.9932, 110.4203, "Asia/Jakarta"),
        City("id-solo", "Surakarta", "Jawa Tengah", -7.5755, 110.8243, "Asia/Jakarta"),
        City("id-yogyakarta", "Yogyakarta", "DI Yogyakarta", -7.7956, 110.3695, "Asia/Jakarta"),
        City("id-surabaya", "Surabaya", "Jawa Timur", -7.2575, 112.7521, "Asia/Jakarta"),
        City("id-malang", "Malang", "Jawa Timur", -7.9666, 112.6326, "Asia/Jakarta"),

        // Kalimantan (WIB)
        City("id-pontianak", "Pontianak", "Kalimantan Barat", -0.0263, 109.3425, "Asia/Jakarta"),
        City("id-palangkaraya", "Palangkaraya", "Kalimantan Tengah", -2.2088, 113.9213, "Asia/Jakarta"),
        City("id-banjarmasin", "Banjarmasin", "Kalimantan Selatan", -3.3186, 114.5944, "Asia/Jakarta"),
        City("id-balikpapan", "Balikpapan", "Kalimantan Timur", -1.2379, 116.8529, "Asia/Jakarta"),
        City("id-samarinda", "Samarinda", "Kalimantan Timur", -0.5017, 117.1536, "Asia/Jakarta"),

        // Bali & Nusa Tenggara (WITA)
        City("id-denpasar", "Denpasar", "Bali", -8.6705, 115.2126, "Asia/Makassar"),
        City("id-mataram", "Mataram", "Nusa Tenggara Barat", -8.5833, 116.1167, "Asia/Makassar"),
        City("id-kupang", "Kupang", "Nusa Tenggara Timur", -10.1772, 123.6070, "Asia/Makassar"),

        // Sulawesi (WITA)
        City("id-makassar", "Makassar", "Sulawesi Selatan", -5.1477, 119.4327, "Asia/Makassar"),
        City("id-palu", "Palu", "Sulawesi Tengah", -0.9017, 119.8707, "Asia/Makassar"),
        City("id-gorontalo", "Gorontalo", "Gorontalo", 0.5432, 123.0559, "Asia/Makassar"),
        City("id-manado", "Manado", "Sulawesi Utara", 1.4748, 124.8421, "Asia/Makassar"),
        City("id-kendari", "Kendari", "Sulawesi Tenggara", -3.9985, 122.5130, "Asia/Makassar"),

        // Maluku (WITA)
        City("id-ambon", "Ambon", "Maluku", -3.6954, 128.1814, "Asia/Makassar"),
        City("id-ternate", "Ternate", "Maluku Utara", 0.7905, 127.3842, "Asia/Makassar"),

        // Papua (WIT)
        City("id-sorong", "Sorong", "Papua Barat Daya", -0.8796, 131.2492, "Asia/Jayapura"),
        City("id-manokwari", "Manokwari", "Papua Barat", -0.8618, 134.0619, "Asia/Jayapura"),
        City("id-timika", "Timika", "Papua Tengah", -4.5414, 136.8838, "Asia/Jayapura"),
        City("id-jayapura", "Jayapura", "Papua", -2.5916, 140.6690, "Asia/Jayapura"),
        City("id-merauke", "Merauke", "Papua Selatan", -8.4884, 140.3964, "Asia/Jayapura"),
    ]

    static let defaultCity = IndonesianCities.all.first { $0.id == "id-jakarta" } ?? all[0]

    static func city(id: String) -> IndonesianCity? {
        all.first { $0.id == id }
    }
}

private func City(_ id: String, _ name: String, _ province: String,
                  _ latitude: Double, _ longitude: Double, _ tz: String) -> IndonesianCity {
    IndonesianCity(id: id, name: name, province: province,
                   latitude: latitude, longitude: longitude, timeZoneIdentifier: tz)
}
