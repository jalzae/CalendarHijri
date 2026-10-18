import SwiftUI

/// "Amal Yaumi" block in the popup: today's daily deeds with check-offs,
/// streaks and a button that opens the management window (CRUD + statistics).
struct AmalYaumiPanel: View {
    @EnvironmentObject private var amal: AmalYaumiStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Amal Yaumi")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(amal.todaySummaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(amal.todaySummaryText.hasPrefix("0/")
                                     ? Color.orange : Color.green)
                Spacer()
                Button {
                    openWindow(id: "amal-yaumi")
                } label: {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 10))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Kelola amal yaumi & statistik")
            }

            ForEach(amal.items) { item in
                row(item)
            }

            if amal.items.isEmpty {
                Text("Belum ada amal. Tambahkan lewat ikon di atas.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ item: AmalItem) -> some View {
        let stats = amal.stats(for: item)

        HStack(spacing: 6) {
            Button {
                if item.targetPerDay == 1 {
                    amal.toggle(item)
                } else {
                    amal.increment(item)
                }
            } label: {
                Image(systemName: stats.isDoneToday
                      ? "checkmark.circle.fill"
                      : (item.targetPerDay == 1 ? "circle" : "plus.circle"))
                    .font(.system(size: 13))
                    .foregroundStyle(stats.isDoneToday ? Color.green : Color.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(item.targetPerDay == 1
                  ? "Tandai selesai hari ini"
                  : "Tambah hitungan (\(stats.doneToday)/\(item.targetPerDay))")

            Image(systemName: item.symbol)
                .font(.system(size: 10))
                .foregroundStyle(stats.isDoneToday ? Color.green : Color.orange)
                .frame(width: 13)

            Text(item.name)
                .font(.system(size: 11, weight: stats.isDoneToday ? .regular : .medium))
                .lineLimit(1)

            if stats.needsAttention && !stats.isDoneToday {
                Circle().fill(Color.orange).frame(width: 4, height: 4)
                    .help("Perlu perhatian hari ini")
            }

            Spacer()

            if stats.currentStreak > 1 {
                Label("\(stats.currentStreak)", systemImage: "flame.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .help("Streak \(stats.currentStreak) hari")
            }

            if item.targetPerDay > 1 {
                Text("\(stats.doneToday)/\(item.targetPerDay)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(stats.isDoneToday ? Color.green : Color.secondary)
                Button {
                    amal.decrement(item)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(stats.doneToday == 0)
                .help("Kurangi hitungan")
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Tandai selesai") { amal.complete(item) }
            Button("Reset hari ini") { amal.reset(item) }
        }
    }
}
