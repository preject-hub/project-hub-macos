import Foundation

// MARK: - Project

struct Project: Identifiable, Codable, Hashable {
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
    var deployment: [String: AnyCodable]?
    var tech: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case name, description, created, updated, status, group, role, paths, git, deployment, tech
    }
}

struct ProjectPaths: Codable, Hashable {
    var source: String

    var resolvedSource: String {
        source.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    }
}

struct GitInfo: Codable, Hashable {
    var remote: String
}

// MARK: - Server

struct Server: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var host: String
    var user: String
    var keyPath: String
    var port: Int

    enum CodingKeys: String, CodingKey {
        case name, host, user, port
        case keyPath = "keyPath"
    }
}

// MARK: - Git Commit

struct GitCommit: Identifiable {
    var id: String { hash }
    var hash: String
    var author: String
    var date: String
    var message: String
}

// MARK: - AnyCodable (for deployment dict)

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map { $0.value }
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine("\(value)")
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        "\(lhs.value)" == "\(rhs.value)"
    }
}

// MARK: - Projects YAML File

struct ProjectsFile: Codable {
    var projects: [String: Project]
}
