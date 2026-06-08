import SwiftUI

enum ViewMode: String, CaseIterable {
    case card = "卡片"
    case list = "列表"
}

struct DashboardView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var searchText = ""
    @State private var selectedProject: Project?
    @State private var viewMode: ViewMode = .card

    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return store.projects
        }
        return store.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedProjects: [(String, [Project])] {
        let filtered = filteredProjects
        var groups: [String: [Project]] = [:]
        for p in filtered {
            let key = p.group ?? "未分组"
            groups[key, default: []].append(p)
        }
        return groups.sorted { $0.key < $1.key }
    }

    var filteredTools: [Tool] {
        if searchText.isEmpty {
            return store.tools
        }
        return store.tools.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索项目...", text: $searchText)
                    .textFieldStyle(.plain)

                Spacer()

                // View mode toggle
                Picker("显示模式", selection: $viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ViewMode.card)
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 70)
            }
            .padding(10)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Content
            if filteredProjects.isEmpty && filteredTools.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(store.projects.isEmpty ? "暂无项目，请在 workspace-governance 中注册" : "未找到匹配项目")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Tools section
                        if !filteredTools.isEmpty {
                            toolsSection
                        }

                        // Projects section
                        switch viewMode {
                        case .card:
                            projectsCardView
                        case .list:
                            projectsListView
                        }
                    }
                }
            }
        }
        .navigationTitle("项目列表")
        .sheet(item: $selectedProject) { project in
            ProjectDetailSheet(project: project)
                .environmentObject(store)
        }
        .onAppear {
            store.loadProjects()
            store.loadServers()
        }
    }

    // MARK: - Tools Section

    var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.orange)
                Text("工具")
                    .font(.title3)
                    .bold()
                Text("\(filteredTools.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400))], spacing: 12) {
                ForEach(filteredTools) { tool in
                    ToolCard(tool: tool)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Projects Card View

    var projectsCardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groupedProjects, id: \.0) { groupName, projects in
                    VStack(alignment: .leading, spacing: 10) {
                        // Group header
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(groupName)
                                .font(.title3)
                                .bold()
                            Text("\(projects.count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }

                        // Cards
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400))], spacing: 12) {
                            ForEach(projects) { project in
                                ProjectCard(project: project)
                                    .onTapGesture { selectedProject = project }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Projects List View

    var projectsListView: some View {
        List {
            ForEach(groupedProjects, id: \.0) { groupName, projects in
                Section(header:
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(groupName)
                            .font(.headline)
                        Spacer()
                        Text("\(projects.count)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                ) {
                    ForEach(projects) { project in
                        ProjectListRow(project: project)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedProject = project }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Card View

struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(project.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: project.status)
                    Text(project.projectType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(3)
                }
            }

            // Tech stack
            HStack(spacing: 3) {
                ForEach(allTechs.prefix(5), id: \.self) { tech in
                    Text(tech)
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(3)
                }
                if allTechs.count > 5 {
                    Text("+\(allTechs.count - 5)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(project.paths.source)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let remote = project.git?.remote, !remote.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(remote)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let dep = project.deploymentInfo {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(dep.host):\(dep.port)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                }

                HStack {
                    Text("创建: \(project.created)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("更新: \(project.updated)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    var allTechs: [String] {
        project.tech.values.flatMap { $0 }
    }
}

// MARK: - List Row

struct ProjectListRow: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                    StatusBadge(status: project.status)
                    Text(project.projectType.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(3)
                }
                Text(project.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(allTechs.prefix(3), id: \.self) { tech in
                    Text(tech)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(3)
                }
            }

            if let dep = project.deploymentInfo {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(dep.host)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var allTechs: [String] {
        project.tech.values.flatMap { $0 }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: Tool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: tool.status)
                    Text(tool.type.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(3)
                }
            }

            // Capabilities
            HStack(spacing: 3) {
                ForEach(tool.capabilities.prefix(5), id: \.self) { cap in
                    Text(cap)
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(3)
                }
                if tool.capabilities.count > 5 {
                    Text("+\(tool.capabilities.count - 5)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(tool.location)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("创建: \(tool.created)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("更新: \(tool.updated)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Detail Sheet

struct ProjectDetailSheet: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(project.name)
                    .font(.title2)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()

            ProjectDetailView(project: project)
                .environmentObject(store)
        }
        .frame(width: 850, height: 600)
    }
}


