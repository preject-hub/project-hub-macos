import Foundation
import Yams

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tools: [Tool] = []
    @Published var servers: [Server] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// workspace 根目录，默认 ~/workspace
    var workspacePath: String {
        UserDefaults.standard.string(forKey: "workspacePath") ?? "~/workspace"
    }

    /// 注册表目录，默认 WORKSPACE_ROOT/registry
    var registryPath: String {
        let custom = UserDefaults.standard.string(forKey: "registryPath") ?? ""
        if !custom.isEmpty {
            return custom
        }
        return workspacePath + "/registry"
    }

    var projectsFilePath: String {
        (registryPath as NSString).expandingTildeInPath + "/projects.yaml"
    }

    var serversFilePath: String {
        (registryPath as NSString).expandingTildeInPath + "/servers.yaml"
    }

    func loadProjects() {
        isLoading = true
        errorMessage = nil

        let path = projectsFilePath

        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "未找到注册表: \(path)"

            isLoading = false
            return
        }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            guard let yaml = try Yams.load(yaml: content) as? [String: Any] else {
                errorMessage = "YAML 顶层解析失败"
                isLoading = false
                return
            }

            guard let projectsDict = yaml["projects"] as? [String: Any] else {
                errorMessage = "YAML 格式错误: 找不到 projects 键"

                isLoading = false
                return
            }

            var result: [Project] = []
            for (name, value) in projectsDict {
                guard let dict = value as? [String: Any] else { continue }
                let project = parseProject(name: name, dict: dict)
                result.append(project)
            }
            projects = result.sorted { $0.name < $1.name }

            // Load tools
            var toolsResult: [Tool] = []
            if let toolsDict = yaml["tools"] as? [String: Any] {
                for (name, value) in toolsDict {
                    guard let dict = value as? [String: Any] else { continue }
                    let tool = parseTool(name: name, dict: dict)
                    toolsResult.append(tool)
                }
            }
            tools = toolsResult.sorted { $0.name < $1.name }

        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func formatDate(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let d = value as? Date {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: d)
        }
        return ""
    }

    private func parseProject(name: String, dict: [String: Any]) -> Project {
        let description = dict["description"] as? String ?? ""
        // Handle both String and Date types from YAML
        let created = formatDate(dict["created"])
        let updated = formatDate(dict["updated"])
        let status = dict["status"] as? String ?? ""
        let group = dict["group"] as? String
        let role = dict["role"] as? String ?? ""

        let pathsDict = dict["paths"] as? [String: Any] ?? [:]
        let source = pathsDict["source"] as? String ?? ""
        let paths = ProjectPaths(source: source)

        var git: GitInfo? = nil
        if let gitDict = dict["git"] as? [String: Any],
           let remote = gitDict["remote"] as? String {
            git = GitInfo(remote: remote)
        }

        var tech: [String: [String]] = [:]
        if let techDict = dict["tech"] as? [String: Any] {
            for (key, value) in techDict {
                if let arr = value as? [String] {
                    tech[key] = arr
                }
            }
        }

        // Parse deployment info
        var deploymentInfo: DeploymentInfo? = nil
        if let dep = dict["deployment"] as? [String: Any] {
            var info = DeploymentInfo()
            if let v = dep["host"] { info.host = "\(v)" }
            if let v = dep["port"] { info.port = "\(v)" }
            if let v = dep["service"] { info.service = "\(v)" }
            if let v = dep["server"] { info.server = "\(v)" }
            if let backend = dep["backend"] as? [String: Any] {
                if let v = backend["host"] { info.host = "\(v)" }
                if let v = backend["port"] { info.port = "\(v)" }
                if let v = backend["service"] { info.service = "\(v)" }
            }
            if info.isValid { deploymentInfo = info }
        }

        return Project(
            name: name,
            description: description,
            created: created,
            updated: updated,
            status: status,
            group: group,
            role: role,
            paths: paths,
            git: git,
            deploymentInfo: deploymentInfo,
            tech: tech
        )
    }

    private func parseTool(name: String, dict: [String: Any]) -> Tool {
        let description = dict["description"] as? String ?? ""
        let created = formatDate(dict["created"])
        let updated = formatDate(dict["updated"])
        let status = dict["status"] as? String ?? ""
        let location = dict["location"] as? String ?? ""
        let type = dict["type"] as? String ?? ""
        let capabilities = dict["capabilities"] as? [String] ?? []
        let notes = dict["notes"] as? String ?? ""

        return Tool(
            name: name,
            description: description,
            created: created,
            updated: updated,
            status: status,
            location: location,
            type: type,
            capabilities: capabilities,
            notes: notes
        )
    }

    func loadServers() {
        let path = serversFilePath
        guard FileManager.default.fileExists(atPath: path) else {
            servers = []
            return
        }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            guard let yamlArray = try Yams.load(yaml: content) as? [[String: Any]] else {
                return
            }
            var result: [Server] = []
            for dict in yamlArray {
                let authStr = dict["authMethod"] as? String ?? "key"
                let auth: AuthMethod = authStr == "password" ? .password : .key
                let server = Server(
                    name: dict["name"] as? String ?? "",
                    host: dict["host"] as? String ?? "",
                    user: dict["user"] as? String ?? "root",
                    keyPath: dict["keyPath"] as? String ?? "~/.ssh/id_rsa",
                    password: dict["password"] as? String ?? "",
                    port: dict["port"] as? Int ?? 22,
                    authMethod: auth
                )
                result.append(server)
            }
            servers = result
        } catch {
            print("加载服务器失败: \(error)")
        }
    }

    /// Move a project folder to a new location and update the registry YAML
    func moveProject(_ project: Project, to destinationDir: URL) async -> String? {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: project.paths.resolvedSource)
        let destinationURL = destinationDir.appendingPathComponent(sourceURL.lastPathComponent)

        // Pre-checks
        guard fm.fileExists(atPath: sourceURL.path) else {
            return "源目录不存在: \(sourceURL.path)"
        }
        if fm.fileExists(atPath: destinationURL.path) {
            return "目标位置已存在同名文件夹: \(destinationURL.lastPathComponent)"
        }

        // Update YAML FIRST (before moving files)
        let newSource: String
        let home = fm.homeDirectoryForCurrentUser.path
        if destinationURL.path.hasPrefix(home) {
            newSource = "~" + destinationURL.path.dropFirst(home.count)
        } else {
            newSource = destinationURL.path
        }

        let updateResult = updateProjectSourceInYAML(projectName: project.name, newSource: newSource)
        if let err = updateResult { return "更新注册表失败，未移动文件: \(err)" }

        // Then move the actual files
        do {
            try fm.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            // Rollback YAML change
            let oldSource: String
            if sourceURL.path.hasPrefix(home) {
                oldSource = "~" + sourceURL.path.dropFirst(home.count)
            } else {
                oldSource = sourceURL.path
            }
            _ = updateProjectSourceInYAML(projectName: project.name, newSource: oldSource)
            return "移动文件失败，已回滚注册表: \(error.localizedDescription)"
        }

        // Reload
        await MainActor.run { loadProjects() }
        return nil
    }

    /// Update paths.source in projects.yaml for a given project name
    private func updateProjectSourceInYAML(projectName: String, newSource: String) -> String? {
        let path = projectsFilePath
        guard FileManager.default.fileExists(atPath: path) else {
            return "注册表文件不存在: \(path)"
        }

        do {
            var lines = try String(contentsOfFile: path, encoding: .utf8)
                .components(separatedBy: .newlines)

            // Find the project block by matching "  projectName:" at 2-space indent
            var inProject = false
            var inPaths = false
            var found = false

            for i in 0..<lines.count {
                let line = lines[i]
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Detect project block start (2-space indent, ends with colon)
                if line.hasPrefix("  ") && !line.hasPrefix("    ") && trimmed.hasSuffix(":") {
                    let name = String(trimmed.dropLast())
                    inProject = (name == projectName)
                    inPaths = false
                    continue
                }

                // Detect paths block within the project (4-space indent)
                if inProject && trimmed == "paths:" && line.hasPrefix("    ") {
                    inPaths = true
                    continue
                }

                // Find source line within paths block (6-space indent)
                if inPaths && line.hasPrefix("      ") && trimmed.hasPrefix("source:") {
                    lines[i] = "      source: \(newSource)"
                    found = true
                    break
                }

                // If we hit another 4-space key, we left paths block
                if inPaths && line.hasPrefix("    ") && !line.hasPrefix("      ") && trimmed.contains(":") {
                    inPaths = false
                }
            }

            if !found {
                return "未能在注册表中找到项目 \"\(projectName)\" 的 paths.source 字段"
            }

            try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return "更新注册表失败: \(error.localizedDescription)"
        }
    }

    func saveServers() {
        let path = serversFilePath
        let dir = (path as NSString).deletingLastPathComponent

        if !FileManager.default.fileExists(atPath: dir) {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        var yamlString = ""
        for server in servers {
            yamlString += "- name: \"\(server.name)\"\n"
            yamlString += "  host: \"\(server.host)\"\n"
            yamlString += "  user: \"\(server.user)\"\n"
            yamlString += "  keyPath: \"\(server.keyPath)\"\n"
            yamlString += "  password: \"\(server.password)\"\n"
            yamlString += "  port: \(server.port)\n"
            yamlString += "  authMethod: \"\(server.authMethod.rawValue)\"\n"
        }
        try? yamlString.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
