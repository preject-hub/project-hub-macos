import Foundation
import AppKit

enum ShellError: LocalizedError {
    case executionFailed(String)
    case processError(Int32, String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "执行失败: \(msg)"
        case .processError(let code, let msg): return "进程退出 (\(code)): \(msg)"
        }
    }
}

struct ShellService {
    @discardableResult
    static func run(_ command: String, arguments: [String] = [], at directory: String? = nil) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "\(command) \(arguments.joined(separator: " "))"]
        process.standardOutput = pipe
        process.standardError = pipe

        if let dir = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw ShellError.processError(process.terminationStatus, output)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func runAsync(_ command: String, arguments: [String] = [], at directory: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try run(command, arguments: arguments, at: directory)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func openApp(_ app: String, arguments: [String] = []) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app] + arguments
        try? process.run()
    }

    static func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    static func openTerminal(at path: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd \(path)"
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
}
