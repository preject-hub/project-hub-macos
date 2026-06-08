import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore
    @State private var selectedTab = "overview"
    @State private var showTerminal = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "概览", icon: "info.circle", tag: "overview", selection: $selectedTab)
                TabButton(title: "Git", icon: "arrow.triangle.branch", tag: "git", selection: $selectedTab)
                TabButton(title: "构建 & 部署", icon: "hammer", tag: "build", selection: $selectedTab)
                TabButton(title: "终端", icon: "terminal", tag: "terminal", selection: $selectedTab)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(Color(.windowBackgroundColor))

            Divider()

            Group {
                switch selectedTab {
                case "overview":
                    OverviewTab(project: project, selectedTab: $selectedTab)
                case "git":
                    GitTab(project: project)
                case "build":
                    BuildTab(project: project)
                        .environmentObject(store)
                case "terminal":
                    TerminalView(title: project.name, workingDirectory: project.paths.resolvedSource)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let tag: String
    @Binding var selection: String

    var body: some View {
        Button(action: { selection = tag }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(selection == tag ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(selection == tag ? .accentColor : .secondary)
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let project: Project
    @Binding var selectedTab: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.largeTitle)
                            .bold()
                        Text(project.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(status: project.status)
                        Text(project.projectType.rawValue.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Divider()

                // Quick actions
                HStack(spacing: 12) {
                    ActionButton(title: "编辑器", icon: "pencil") {
                        if let appPath = project.editorAppPath {
                            ShellService.openApp(appPath, arguments: [project.paths.resolvedSource])
                        } else {
                            ShellService.openApp("Visual Studio Code", arguments: [project.paths.resolvedSource])
                        }
                    }
                    ActionButton(title: "终端", icon: "terminal") {
                        selectedTab = "terminal"
                    }
                    if let remote = project.git?.remote, !remote.isEmpty {
                        ActionButton(title: "GitHub", icon: "link") {
                            ShellService.openURL(remote)
                        }
                    }
                    ActionButton(title: "Finder", icon: "folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: project.paths.resolvedSource))
                    }
                }

                Divider()

                // Info cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InfoCard(title: "路径", value: project.paths.source, icon: "folder")
                    InfoCard(title: "类型", value: project.projectType.rawValue, icon: "tag")
                    InfoCard(title: "推荐编辑器", value: project.recommendedEditor, icon: "pencil.circle")
                    if let group = project.group {
                        InfoCard(title: "分组", value: group, icon: "square.grid.2x2")
                    }
                    InfoCard(title: "创建时间", value: project.created, icon: "calendar")
                    InfoCard(title: "更新时间", value: project.updated, icon: "clock")
                    if let remote = project.git?.remote, !remote.isEmpty {
                        InfoCard(title: "Git 仓库", value: remote, icon: "arrow.triangle.branch")
                    }
                }

                // Deployment info
                if let dep = project.deploymentInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("部署信息")
                            .font(.headline)
                        HStack(spacing: 12) {
                            if !dep.host.isEmpty {
                                InfoCard(title: "服务器", value: dep.host, icon: "server.rack")
                            }
                            if !dep.port.isEmpty {
                                InfoCard(title: "端口", value: dep.port, icon: "number")
                            }
                            if !dep.service.isEmpty {
                                InfoCard(title: "服务", value: dep.service, icon: "gearshape")
                            }
                        }
                    }
                }

                // Tech stack
                VStack(alignment: .leading, spacing: 8) {
                    Text("技术栈")
                        .font(.headline)
                    ForEach(Array(project.tech.keys.sorted()), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                ForEach(project.tech[category] ?? [], id: \.self) { tech in
                                    Text(tech)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption)
            }
            .frame(width: 70, height: 56)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status == "active" ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
            .cornerRadius(4)
    }
}
