import Foundation

struct SSHService {
    /// Execute SSH command on a server
    static func exec(_ server: Server, command: String) async throws -> String {
        let expandedKey = server.keyPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

        if server.hasPassword {
            return try await execWithPassword(server: server, command: command)
        } else {
            let args = [
                "-o", "StrictHostKeyChecking=no",
                "-o", "ConnectTimeout=10",
                "-o", "BatchMode=yes",
                "-i", expandedKey,
                "-p", "\(server.port)",
                "\(server.user)@\(server.host)",
                command
            ]
            return try await ShellService.runAsync("/usr/bin/ssh", arguments: args)
        }
    }

    /// Test SSH connection
    static func testConnection(_ server: Server) async -> (Bool, String) {
        do {
            let result = try await exec(server, command: "echo 'connected' && hostname && uptime")
            return (true, "✅ 连接成功\n\(result)")
        } catch {
            return (false, "❌ 连接失败: \(error.localizedDescription)")
        }
    }

    /// Build SCP arguments
    static func scpArgs(for server: Server, source: String, destination: String) -> [String] {
        let expandedKey = server.keyPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

        if server.hasPassword {
            return [
                "/opt/homebrew/bin/sshpass", "-p", server.password,
                "/usr/bin/scp",
                "-o", "StrictHostKeyChecking=no",
                "-P", "\(server.port)",
                source, destination
            ]
        } else {
            return [
                "/usr/bin/scp",
                "-i", expandedKey,
                "-o", "StrictHostKeyChecking=no",
                "-P", "\(server.port)",
                source, destination
            ]
        }
    }

    /// Create Process for interactive terminal
    static func createProcess(for server: Server, command: String? = nil) -> Process {
        let proc = Process()
        let expandedKey = server.keyPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

        if server.hasPassword {
            proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sshpass")
            var args = ["-p", server.password, "/usr/bin/ssh",
                        "-o", "StrictHostKeyChecking=no",
                        "-o", "ConnectTimeout=10",
                        "-p", "\(server.port)",
                        "\(server.user)@\(server.host)"]
            if let cmd = command { args.append(cmd) }
            proc.arguments = args
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            var args = ["-i", expandedKey,
                        "-o", "StrictHostKeyChecking=no",
                        "-o", "ConnectTimeout=10",
                        "-p", "\(server.port)",
                        "\(server.user)@\(server.host)"]
            if let cmd = command { args.append(cmd) }
            proc.arguments = args
        }

        return proc
    }

    // MARK: - Private

    private static func execWithPassword(server: Server, command: String) async throws -> String {
        let args = [
            "/opt/homebrew/bin/sshpass", "-p", server.password,
            "/usr/bin/ssh",
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=10",
            "-o", "NumberOfPasswordPrompts=1",
            "-p", "\(server.port)",
            "\(server.user)@\(server.host)",
            command
        ]

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: args[0])
        proc.arguments = Array(args.dropFirst())

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        proc.standardInput = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            proc.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ShellError.processError(proc.terminationStatus, output))
                }
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
