import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("项目", systemImage: "square.grid.2x2")
                }
                .tag(0)

            ServersView()
                .tabItem {
                    Label("服务器", systemImage: "server.rack")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
    }
}
