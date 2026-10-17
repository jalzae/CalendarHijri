import SwiftUI
import Combine

/// Keeps the menu bar label ("8 Jumadil Awwal 1448") fresh across midnight.
@MainActor
final class MenuBarModel: ObservableObject {
    @Published var menuText = ""

    private var cancellable: AnyCancellable?

    init() {
        refresh()
        cancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        let info = HijriDateInfo.make(for: Date())
        menuText = "\(info.day) \(HijriDateInfo.monthNamesIndonesian[info.monthIndex]) \(info.year)"
    }
}

@main
struct CalendarHijriApp: App {
    @StateObject private var model = MenuBarModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarCalendarView()
                .frame(width: 330)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 11))
                Text(model.menuText)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
