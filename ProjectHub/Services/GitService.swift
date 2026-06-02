import Foundation

struct GitService {
    static func status(at path: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["status"], at: path)
    }

    static func log(at path: String, count: Int = 20) async throws -> [GitCommit] {
        let output = try await ShellService.runAsync("git", arguments: ["log", "-\(count)", "--pretty=format:%H|%an|%ai|%s"], at: path)
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 3)
            guard parts.count >= 4 else { return nil }
            return GitCommit(
                hash: String(parts[0]),
                author: String(parts[1]),
                date: String(parts[2]),
                message: String(parts[3])
            )
        }
    }

    static func pull(at path: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["pull"], at: path)
    }

    static func push(at path: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["push"], at: path)
    }

    static func fetch(at path: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["fetch"], at: path)
    }

    static func diff(at path: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["diff"], at: path)
    }

    static func checkout(at path: String, branch: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["checkout", branch], at: path)
    }

    static func branches(at path: String) async throws -> [String] {
        let output = try await ShellService.runAsync("git", arguments: ["branch", "-a"], at: path)
        return output.split(separator: "\n").map { line in
            String(line).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "* ", with: "")
        }.filter { !$0.isEmpty }
    }

    static func currentBranch(at path: String) async throws -> String {
        try await ShellService.runAsync("git", arguments: ["branch", "--show-current"], at: path)
    }
}
