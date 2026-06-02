import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var selectedTab = "overview"

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "概览", icon: "info.circle", tag: "overview", selection: $selectedTab)
                TabButton(title: "Git", icon: "arrow.triangle.branch", tag: "git", selection: $selectedTab)
                TabButton(title: "构建 & 部署", icon: "hammer", tag: "build", selection: $selectedTab)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case "overview":
                    OverviewTab(project: project)
                case "git":
                    GitTab(project: project)
                case "build":
                    BuildTab(project: project)
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
                    StatusBadge(status: project.status)
                        .font(.body)
                }

                Divider()

                // Quick actions
                HStack(spacing: 12) {
                    ActionButton(title: "编辑器", icon: "pencil") {
                        ShellService.openApp("Visual Studio Code", arguments: [project.paths.resolvedSource])
                    }
                    ActionButton(title: "终端", icon: "terminal") {
                        ShellService.openTerminal(at: project.paths.resolvedSource)
                    }
                    if let remote = project.git?.remote {
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
                    InfoCard(title: "角色", value: project.role, icon: "person")
                    if let group = project.group {
                        InfoCard(title: "分组", value: group, icon: "square.grid.2x2")
                    }
                    InfoCard(title: "创建时间", value: project.created, icon: "calendar")
                    InfoCard(title: "更新时间", value: project.updated, icon: "clock")
                    if let remote = project.git?.remote {
                        InfoCard(title: "Git 仓库", value: remote, icon: "arrow.triangle.branch")
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
                            FlowLayout(spacing: 4) {
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

// Simple flow layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (offsets, CGSize(width: maxX, height: y + rowHeight))
    }
}
