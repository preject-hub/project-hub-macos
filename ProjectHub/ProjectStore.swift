import Foundation
import Yams

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tools: [Tool] = []
    @Published var servers: [Server] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var registryPath: String {
        UserDefaults.standard.string(forKey: "registryPath") ??
            "~/.openclaw/skills/workspace-governance/registry"
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
            guard let yaml = try Yams.load(yaml: content) as? [String: Any],
                  let projectsDict = yaml["projects"] as? [String: Any] else {
                errorMessage = "YAML 格式错误"
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
