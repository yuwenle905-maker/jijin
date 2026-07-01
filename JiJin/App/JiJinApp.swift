import SwiftUI

@main
struct JiJinApp: App {
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    NotificationManager.requestAuthorization()
                    NotificationManager.scheduleAll(funds: store.funds)
                }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "calendar.day.timeline.left") }

            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet.clipboard") }

            RebalanceView()
                .tabItem { Label("再平衡", systemImage: "scale.3d") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
