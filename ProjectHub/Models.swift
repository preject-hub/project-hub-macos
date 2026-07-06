import Foundation

// MARK: - Project Type

enum ProjectType: String {
    case harmony, android, apple, java, frontend, node, generic
}

// MARK: - Deployment Info

struct DeploymentInfo: Hashable {
    var host: String = ""
    var port: String = ""
    var service: String = ""
    var server: String = ""

    var isValid: Bool { !host.isEmpty }

    var displayString: String {
        var parts: [String] = []
        if !host.isEmpty { parts.append("主机: \(host)") }
        if !port.isEmpty { parts.append("端口: \(port)") }
        if !service.isEmpty { parts.append("服务: \(service)") }
        if !server.isEmpty { parts.append("服务器: \(server)") }
        return parts.joined(separator: " | ")
    }
}

// MARK: - Project

// MARK: - Tool

struct Tool: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var description: String
    var created: String
    var updated: String
    var status: String
    var location: String
    var type: String
    var capabilities: [String]
    var notes: String

    var resolvedLocation: String {
        location.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    }
}

struct Project: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var description: String
    var created: String
    var updated: String
    var status: String
    var group: String?
    var role: String
    var paths: ProjectPaths
    var git: GitInfo?
    var deploymentInfo: DeploymentInfo?
    var tech: [String: [String]]

    // MARK: - 智能判断

    var projectType: ProjectType {
        let allTechs = tech.values.flatMap { $0 }.map { $0.lowercased() }
        let roleLower = role.lowercased()

        if roleLower.contains("harmony") || allTechs.contains(where: { $0.contains("arkts") || $0.contains("harmonyos") || $0.contains("arkui") }) {
            return .harmony
        }
        if roleLower.contains("android") || allTechs.contains(where: { $0.contains("kotlin") || $0.contains("jetpack-compose") || $0.contains("android") }) {
            return .android
        }
        if allTechs.contains(where: { $0.contains("swift") || $0.contains("swiftui") || $0.contains("macos-native") }) {
            return .apple
        }
        if allTechs.contains(where: { $0.contains("java") || $0.contains("spring-boot") }) {
            return .java
        }
        if allTechs.contains(where: { $0.contains("react") || $0.contains("vue") || $0.contains("vite") || $0.contains("typescript") }) {
            return .frontend
        }
        if allTechs.contains(where: { $0.contains("node") || $0.contains("express") }) {
            return .node
        }
        return .generic
    }

    var recommendedEditor: String {
        switch projectType {
        case .harmony: return "DevEco-Studio"
        case .android: return "Android Studio"
        case .apple: return "Xcode"
        case .java: return "IntelliJ IDEA"
        case .frontend, .node: return "Visual Studio Code"
        case .generic: return "Visual Studio Code"
        }
    }

    var editorAppPath: String? {
        switch projectType {
        case .harmony: return "/Applications/IDE/DevEco-Studio.app"
        case .android: return "/Applications/Android Studio.app"
        case .apple: return "/Applications/Xcode.app"
        case .java: return "/Applications/IntelliJ IDEA.app"
        case .frontend, .node, .generic: return nil
        }
    }

    var buildCommand: String? {
        switch projectType {
        case .harmony:
            return "/Applications/IDE/DevEco-Studio.app/Contents/tools/node/bin/node /Applications/IDE/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js --mode module -p product=default assembleHap --analyze=normal --parallel --incremental"
        case .android:
            return "./gradlew assembleDebug"
        case .java:
            return "mvn clean package -DskipTests"
        case .frontend, .node:
            let src = paths.resolvedSource
            if FileManager.default.fileExists(atPath: src + "/pnpm-lock.yaml") {
                return "pnpm build"
            } else if FileManager.default.fileExists(atPath: src + "/yarn.lock") {
                return "yarn build"
            }
            return "npm run build"
        case .apple:
            return nil
        case .generic:
            return nil
        }
    }

}

// MARK: - Supporting Types

struct ProjectPaths: Hashable {
    var source: String

    var resolvedSource: String {
        if source.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser.path + String(source.dropFirst(1))
        }
        return source
    }
}

struct GitInfo: Hashable {
    var remote: String
}

enum AuthMethod: String, Hashable, CaseIterable {
    case key = "key"
    case password = "password"
}

struct Server: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var host: String
    var user: String
    var keyPath: String
    var password: String
    var port: Int
    var authMethod: AuthMethod

    var hasPassword: Bool { !password.isEmpty && authMethod == .password }
}

struct GitCommit: Identifiable {
    var id: String { hash }
    var hash: String
    var author: String
    var date: String
    var message: String
}
