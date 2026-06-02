import SwiftUI

struct GitTab: View {
    let project: Project
    @State private var gitStatus = ""
    @State private var commits: [GitCommit] = []
    @State private var branches: [String] = []
    @State private var currentBranch = ""
    @State private var diff = ""
    @State private var isLoading = false
    @State private var output = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                if !currentBranch.isEmpty {
                    Label(currentBranch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(6)
                }

                Spacer()

                Button("Pull") { runGit { try await GitService.pull(at: project.paths.resolvedSource) } }
                Button("Push") { runGit { try await GitService.push(at: project.paths.resolvedSource) } }
                Button("Fetch") { runGit { try await GitService.fetch(at: project.paths.resolvedSource) } }
                Button("Diff") {
                    Task {
                        isLoading = true
                        diff = (try? await GitService.diff(at: project.paths.resolvedSource)) ?? ""
                        isLoading = false
                    }
                }
            }
            .padding(10)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Output
                    if !output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("输出")
                                .font(.headline)
                            Text(output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }

                    // Status
                    if !gitStatus.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.headline)
                            Text(gitStatus)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }

                    // Diff
                    if !diff.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Diff")
                                .font(.headline)
                            Text(diff)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }

                    // Commits
                    if !commits.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最近提交")
                                .font(.headline)
                            ForEach(commits) { commit in
                                HStack(spacing: 8) {
                                    Text(String(commit.hash.prefix(7)))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.yellow)
                                    Text(commit.date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 80)
                                    Text(commit.message)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            isLoading = true
            async let status = GitService.status(at: project.paths.resolvedSource)
            async let log = GitService.log(at: project.paths.resolvedSource)
            async let branchList = GitService.branches(at: project.paths.resolvedSource)
            async let branch = GitService.currentBranch(at: project.paths.resolvedSource)

            gitStatus = (try? await status) ?? ""
            commits = (try? await log) ?? []
            branches = (try? await branchList) ?? []
            currentBranch = (try? await branch) ?? ""
            isLoading = false
        }
    }

    private func runGit(_ action: @escaping () async throws -> String) {
        Task {
            isLoading = true
            do {
                output = try await action()
            } catch {
                output = "错误: \(error.localizedDescription)"
            }
            gitStatus = (try? await GitService.status(at: project.paths.resolvedSource)) ?? ""
            isLoading = false
        }
    }
}
