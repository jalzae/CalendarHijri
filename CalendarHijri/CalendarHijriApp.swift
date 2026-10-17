import SwiftUI

@main
struct CalendarHijriApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarCalendarView()
                .frame(width: 330)
        } label: {
            // Menu bar shows the current Hijri day number, refreshed every minute.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 3) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11))
                    Text("\(HijriDateInfo.make(for: context.date).day)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
