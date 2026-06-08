import SwiftUI

struct TerminalView: View {
    let title: String
    let server: Server?
    let workingDirectory: String?

    @State private var output: String = ""
    @State private var input: String = ""
    @State private var isRunning = false
    @State private var history: [String] = []
    @State private var historyIndex: Int = -1
    @State private var process: Process?
    @State private var outputPipe: Pipe?

    init(title: String, workingDirectory: String) {
        self.title = title
        self.workingDirectory = workingDirectory
        self.server = nil
    }

    init(title: String, server: Server) {
        self.title = title
        self.server = server
        self.workingDirectory = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: server != nil ? "server.rack" : "terminal")
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
                Spacer()
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("运行中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button("清空") { output = "" }
                    .font(.caption)
            }
            .padding(10)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? "终端就绪，输入命令开始...\n" : output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("output-bottom")
                }
                .onChange(of: output) {
                    withAnimation {
                        proxy.scrollTo("output-bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(.textBackgroundColor))

            Divider()

            // Input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.accentColor)

                TextField("输入命令...", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        executeCommand()
                    }

                Button("执行") {
                    executeCommand()
                }
                .disabled(input.isEmpty || isRunning)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(10)
            .background(Color(.controlBackgroundColor))
        }
        .onAppear {
            if let s = server {
                output += "📍 SSH 连接: \(s.user)@\(s.host):\(s.port)\n"
                output += "   认证方式: \(s.authMethod == .password ? "密码" : "SSH 密钥")\n\n"
            } else {
                output += "📍 本地目录: \(workingDirectory ?? "~")\n\n"
            }
        }
        .onDisappear {
            killProcess()
        }
    }

    private func executeCommand() {
        let cmd = input.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        history.append(cmd)
        historyIndex = history.count
        input = ""

        if cmd == "clear" {
            output = ""
            return
        }

        if cmd == "exit" {
            killProcess()
            output += "\n已断开连接\n"
            return
        }

        output += "$ \(cmd)\n"

        if let server = server {
            executeSSH(command: cmd, server: server)
        } else {
            executeLocal(command: cmd)
        }
    }

    private func executeLocal(command: String) {
        isRunning = true
        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", command]
        proc.standardOutput = pipe
        proc.standardError = pipe

        if let dir = workingDirectory {
            proc.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let data = fh.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async {
                    self.output += str
                }
            }
        }

        proc.terminationHandler = { _ in
            DispatchQueue.main.async {
                handle.readabilityHandler = nil
                self.isRunning = false
            }
        }

        do {
            try proc.run()
            process = proc
        } catch {
            output += "❌ 执行失败: \(error.localizedDescription)\n"
            isRunning = false
        }
    }

    private func executeSSH(command: String, server: Server) {
        isRunning = true
        let proc = Process()
        let pipe = Pipe()

        let expandedKey = server.keyPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

        if server.hasPassword {
            // Use sshpass for password auth
            proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sshpass")
            proc.arguments = [
                "-p", server.password,
                "/usr/bin/ssh",
                "-o", "StrictHostKeyChecking=no",
                "-o", "ConnectTimeout=10",
                "-o", "NumberOfPasswordPrompts=1",
                "-p", "\(server.port)",
                "\(server.user)@\(server.host)",
                command
            ]
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            proc.arguments = [
                "-i", expandedKey,
                "-o", "StrictHostKeyChecking=no",
                "-o", "ConnectTimeout=10",
                "-p", "\(server.port)",
                "\(server.user)@\(server.host)",
                command
            ]
        }

        proc.standardOutput = pipe
        proc.standardError = pipe

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let data = fh.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async {
                    self.output += str
                }
            }
        }

        proc.terminationHandler = { _ in
            DispatchQueue.main.async {
                handle.readabilityHandler = nil
                self.isRunning = false
            }
        }

        do {
            try proc.run()
            process = proc
        } catch {
            output += "❌ SSH 连接失败: \(error.localizedDescription)\n"
            output += "提示: 密码认证需要安装 sshpass (brew install hudochenkov/sshpass/sshpass)\n"
            isRunning = false
        }
    }

    private func killProcess() {
        process?.terminate()
        process = nil
    }
}
