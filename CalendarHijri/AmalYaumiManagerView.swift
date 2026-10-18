import SwiftUI

/// Management window for amal yaumi: add / edit / delete deeds and review
/// statistics (streaks, 14-day trend, 30-day completion) to spot the amal
/// that needs attention.
struct AmalYaumiManagerView: View {
    @EnvironmentObject private var amal: AmalYaumiStore
    @State private var editing: AmalItem?
    @State private var adding = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if amal.items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(amal.items) { item in
                        AmalStatRow(item: item)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    amal.delete(item)
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                }
                                Button {
                                    editing = item
                                } label: {
                                    Label("Ubah", systemImage: "pencil")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 560, height: 520)
        .sheet(item: $editing) { item in
            AmalEditSheet(item: item)
        }
        .sheet(isPresented: $adding) {
            AmalEditSheet(item: nil)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Amal Yaumi")
                    .font(.system(size: 15, weight: .bold))
                Text("Hari ini \(amal.todaySummaryText) amal selesai")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                adding = true
            } label: {
                Label("Tambah Amal", systemImage: "plus")
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Belum ada amal yaumi")
                .font(.system(size: 13, weight: .semibold))
            Text("Tambahkan amal harian seperti sholawat, istighfar, atau tilawah.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Tambah Amal") { adding = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat row

private struct AmalStatRow: View {
    @EnvironmentObject private var amal: AmalYaumiStore
    let item: AmalItem
    @State private var editing = false

    private var stats: AmalYaumiStats { amal.stats(for: item) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 15))
                .foregroundStyle(stats.isDoneToday ? Color.green : Color.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                    if stats.needsAttention {
                        Text("Perlu perhatian")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .foregroundStyle(Color.orange)
                    }
                }
                HStack(spacing: 10) {
                    if stats.currentStreak > 0 {
                        Label("\(stats.currentStreak) hari", systemImage: "flame.fill")
                            .foregroundStyle(Color.orange)
                    }
                    Text("\(stats.doneDays30)/30 hari bulan ini")
                        .foregroundStyle(.secondary)
                    if item.targetPerDay > 1 {
                        Text("\(stats.doneToday)/\(item.targetPerDay) hari ini")
                            .foregroundStyle(stats.isDoneToday ? Color.green : .secondary)
                    }
                }
                .font(.system(size: 10))
            }

            Spacer()

            TrendBars(values: amal.completionTrend(item: item))
                .frame(width: 110, height: 22)

            Button("Hari ini ✓") {
                amal.complete(item)
            }
            .buttonStyle(.bordered)
            .tint(stats.isDoneToday ? .green : .orange)
            .disabled(stats.isDoneToday)

            Menu {
                Button("Ubah…") { editing = true }
                Button("Tandai selesai hari ini") { amal.complete(item) }
                Button("Reset hari ini") { amal.reset(item) }
                Divider()
                Button("Hapus", role: .destructive) { amal.delete(item) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $editing) {
            AmalEditSheet(item: item)
        }
    }
}

/// One small bar per day for the last 14 days — filled when the amal was done.
private struct TrendBars: View {
    let values: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(value > 0 ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 5, height: 6 + 12 * value)
            }
        }
    }
}

// MARK: - Edit / add sheet

private struct AmalEditSheet: View {
    @EnvironmentObject private var amal: AmalYaumiStore
    @Environment(\.dismiss) private var dismiss

    let original: AmalItem?

    @State private var name = ""
    @State private var symbol = AmalYaumiStore.symbolChoices[0]
    @State private var target = 1

    init(item: AmalItem?) {
        original = item
        _name = State(initialValue: item?.name ?? "")
        _symbol = State(initialValue: item?.symbol ?? AmalYaumiStore.symbolChoices[0])
        _target = State(initialValue: item?.targetPerDay ?? 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(original == nil ? "Tambah Amal Yaumi" : "Ubah Amal")
                .font(.system(size: 14, weight: .bold))

            Form {
                TextField("Nama amal (mis. Sholawat)", text: $name)

                Picker("Ikon", selection: $symbol) {
                    ForEach(AmalYaumiStore.symbolChoices, id: \.self) { choice in
                        Image(systemName: choice).tag(choice)
                    }
                }

                Stepper(value: $target, in: 1...1000) {
                    HStack {
                        Text("Target per hari")
                        Spacer()
                        Text(target == 1 ? "1× (sekali selesai)" : "\(target)×")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Target > 1 dipakai untuk amal berhitungan seperti istighfar 100×. Ada tombol +/− di popup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            HStack {
                if let original {
                    Button("Hapus", role: .destructive) {
                        amal.delete(original)
                        dismiss()
                    }
                }
                Spacer()
                Button("Batal") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(original == nil ? "Tambah" : "Simpan") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(.top, 16)
        .frame(width: 380, height: 340)
    }

    private func save() {
        if var item = original {
            item.name = name.trimmingCharacters(in: .whitespaces)
            item.symbol = symbol
            item.targetPerDay = target
            amal.update(item)
        } else {
            amal.add(name: name, symbol: symbol, targetPerDay: target)
        }
        dismiss()
    }
}
