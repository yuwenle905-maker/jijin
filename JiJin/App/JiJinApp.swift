import SwiftUI

@main
struct JiJinApp: App {
    @StateObject private var store        = DataStore()
    @StateObject private var priceService = PriceService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(priceService)
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
                .tabItem { Label("首页", systemImage: "house.fill") }

            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet.clipboard") }

            RebalanceView()
                .tabItem { Label("再平衡", systemImage: "scale.3d") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
