import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case servers = "servers"
    case settings = "settings"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "项目"
        case .servers: return "服务器"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .servers: return "server.rack"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.label, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle("Project Hub")
        } detail: {
            switch selectedItem {
            case .dashboard:
                DashboardView()
            case .servers:
                ServersView()
            case .settings:
                SettingsView()
            case .none:
                Text("选择一个项目")
                    .foregroundColor(.secondary)
            }
        }
    }
}
