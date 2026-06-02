import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var searchText = ""
    @State private var selectedProject: Project?

    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return store.projects
        }
        return store.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索项目...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding()

                // Project list
                List(filteredProjects, selection: $selectedProject) { project in
                    ProjectRow(project: project)
                        .tag(project)
                }
                .listStyle(.sidebar)
            }
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择一个项目")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Project Hub")
        .onAppear {
            store.loadProjects()
            store.loadServers()
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(project.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: project.status)
            }
            Text(project.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            HStack(spacing: 4) {
                ForEach(allTechs.prefix(4), id: \.self) { tech in
                    Text(tech)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                if allTechs.count > 4 {
                    Text("+\(allTechs.count - 4)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var allTechs: [String] {
        project.tech.values.flatMap { $0 }
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
