import SwiftUI

struct BuildTab: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore
    @State private var output = ""
    @State private var isBuilding = false
    @State private var isDeploying = false
    @State private var customCommand = ""

    var body: some View {
        VStack(spacing: 0) {
            // Quick build buttons
            HStack(spacing: 8) {
                // Auto build button based on project type
                if let buildCmd = project.buildCommand {
                    Button(action: { build(buildCmd) }) {
                        HStack(spacing: 4) {
                            if isBuilding { ProgressView().scaleEffect(0.5) }
                            Text("🔨 一键打包 (\(project.projectType.rawValue))")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBuilding)
                }

                // Deploy button
                if let dep = project.deploymentInfo, !dep.host.isEmpty {
                    Button(action: { deploy(dep) }) {
                        HStack(spacing: 4) {
                            if isDeploying { ProgressView().scaleEffect(0.5) }
                            Text("🚀 一键部署到 \(dep.host)")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeploying)
                }

                // Build + Deploy combo
                if let buildCmd = project.buildCommand, let dep = project.deploymentInfo, !dep.host.isEmpty {
                    Button(action: { buildAndDeploy(buildCmd, dep) }) {
                        HStack(spacing: 4) {
                            Text("⚡ 打包 + 部署")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBuilding || isDeploying)
                }

                Spacer()
            }
            .padding(10)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Custom command
            HStack {
                TextField("自定义命令...", text: $customCommand)
                    .textFieldStyle(.plain)
                Button("运行") {
                    if !customCommand.isEmpty { build(customCommand) }
                }
                .disabled(customCommand.isEmpty || isBuilding)
            }
            .padding(10)

            Divider()

            // Output
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("构建输出")
                        .font(.headline)
                    Spacer()
                    if isBuilding || isDeploying {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Button("清空") { output = "" }
                        .font(.caption)
                }

                ScrollView {
                    Text(output.isEmpty ? "点击上方按钮开始构建" : output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
            }
            .padding()
        }
    }

    private func build(_ command: String) {
        isBuilding = true
        output = "🔨 执行: \(command)\n路径: \(project.paths.resolvedSource)\n\n"

        Task {
            do {
                let result = try await ShellService.runAsync("bash", arguments: ["-c", command], at: project.paths.resolvedSource)
                output += result
                output += "\n\n✅ 构建完成"
            } catch {
                output += "\n\n❌ 构建失败: \(error.localizedDescription)"
            }
            isBuilding = false
        }
    }

    private func deploy(_ dep: DeploymentInfo) {
        isDeploying = true
        output += "\n\n🚀 开始部署到 \(dep.host)...\n"

        Task {
            // Find matching server config from store
            let server = findServer(for: dep)

            do {
                if let server = server {
                    // SCP upload
                    let sourcePath = project.paths.resolvedSource
                    let remotePath = "/opt/\(project.name)/"

                    // Try to upload build artifacts
                    var deployCmd = ""
                    if project.projectType == .java {
                        deployCmd = "scp -i \(server.keyPath) -P \(server.port) \(sourcePath)/target/*.jar \(server.user)@\(server.host):\(remotePath)"
                    } else if project.projectType == .frontend {
                        deployCmd = "scp -i \(server.keyPath) -P \(server.port) -r \(sourcePath)/dist/* \(server.user)@\(server.host):\(remotePath)"
                    } else {
                        deployCmd = "scp -i \(server.keyPath) -P \(server.port) -r \(sourcePath)/* \(server.user)@\(server.host):\(remotePath)"
                    }

                    output += "上传命令: \(deployCmd)\n"
                    let result = try await ShellService.runAsync("bash", arguments: ["-c", deployCmd])
                    output += result

                    // Restart service if available
                    let service = dep.service
                    if !service.isEmpty {
                        let restartCmd = "ssh -i \(server.keyPath) -p \(server.port) \(server.user)@\(server.host) 'sudo systemctl restart \(service)'"
                        output += "\n\n重启服务: \(service)\n"
                        let restartResult = try await ShellService.runAsync("bash", arguments: ["-c", restartCmd])
                        output += restartResult
                    }

                    output += "\n\n✅ 部署完成"
                } else {
                    output += "\n\n⚠️ 未找到匹配的服务器配置，请在服务器管理页面添加"
                }
            } catch {
                output += "\n\n❌ 部署失败: \(error.localizedDescription)"
            }
            isDeploying = false
        }
    }

    private func buildAndDeploy(_ buildCmd: String, _ dep: DeploymentInfo) {
        isBuilding = true
        output = "⚡ 打包 + 部署流程开始\n\n"

        Task {
            // Step 1: Build
            output += "🔨 第一步: 打包\n"
            do {
                let result = try await ShellService.runAsync("bash", arguments: ["-c", buildCmd], at: project.paths.resolvedSource)
                output += result
                output += "\n\n✅ 打包完成\n\n"
            } catch {
                output += "\n\n❌ 打包失败: \(error.localizedDescription)"
                isBuilding = false
                return
            }

            // Step 2: Deploy
            isBuilding = false
            deploy(dep)
        }
    }

    private func findServer(for dep: DeploymentInfo) -> Server? {
        return store.servers.first { $0.host == dep.host }
    }
}
