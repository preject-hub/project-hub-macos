import Foundation
import Yams

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
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

            let data = try JSONSerialization.data(withJSONObject: ["projects": projectsDict])
            let file = try JSONDecoder().decode(ProjectsFile.self, from: data)
            projects = file.projects.values.sorted { $0.name < $1.name }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
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
            let data = try JSONSerialization.data(withJSONObject: yamlArray)
            servers = try JSONDecoder().decode([Server].self, from: data)
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

        do {
            var yamlString = ""
            for server in servers {
                yamlString += "- name: \"\(server.name)\"\n"
                yamlString += "  host: \"\(server.host)\"\n"
                yamlString += "  user: \"\(server.user)\"\n"
                yamlString += "  keyPath: \"\(server.keyPath)\"\n"
                yamlString += "  port: \(server.port)\n"
            }
            try yamlString.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("保存服务器失败: \(error)")
        }
    }
}
