import SwiftUI
import AppKit

struct ServersView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var showAddSheet = false
    @State private var editingServer: Server?
    @State private var serverStatuses: [String: Bool] = [:]
    @State private var terminalServer: Server?
    @State private var monitorServer: Server?
    @State private var filesServer: Server?
    @AppStorage("serverViewMode") private var viewMode: ViewMode = .list

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("服务器管理")
                    .font(.title2)
                    .bold()
                Spacer()
                // View mode toggle
                Picker("显示模式", selection: $viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ViewMode.card)
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 70)

                Button("刷新状态") { checkAllStatuses() }
                Button("+ 添加服务器") { showAddSheet = true }
            }
            .padding()

            Divider()

            // Server list
            if store.servers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无服务器")
                        .foregroundColor(.secondary)
                    Button("+ 添加服务器") { showAddSheet = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewMode == .list {
                // List mode
                List {
                    ForEach(store.servers) { server in
                        ServerRow(
                            server: server,
                            isOnline: serverStatuses[server.host],
                            onTerminal: { terminalServer = server },
                            onMonitor: { monitorServer = server },
                            onFiles: { filesServer = server },
                            onEdit: { editingServer = server },
                            onDelete: { deleteServer(server) }
                        )
                    }
                }
                .listStyle(.inset)
            } else {
                // Card mode
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 300, maximum: 400))],
                        spacing: 12
                    ) {
                        ForEach(store.servers) { server in
                            ServerCardView(
                                server: server,
                                isOnline: serverStatuses[server.host],
                                onTerminal: { terminalServer = server },
                                onMonitor: { monitorServer = server },
                                onFiles: { filesServer = server },
                                onEdit: { editingServer = server },
                                onDelete: { deleteServer(server) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ServerEditSheet(server: nil) { newServer in
                store.servers.append(newServer)
                store.saveServers()
            }
        }
        .sheet(item: $editingServer) { server in
            ServerEditSheet(server: server) { updated in
                if let idx = store.servers.firstIndex(where: { $0.id == server.id }) {
                    store.servers[idx] = updated
                    store.saveServers()
                }
            }
        }
        .sheet(item: $terminalServer) { server in
            TerminalSheet(server: server)
        }
        .sheet(item: $monitorServer) { server in
            MonitorSheet(server: server)
        }
        .sheet(item: $filesServer) { server in
            FilesSheet(server: server)
        }
        .onAppear { checkAllStatuses() }
    }

    private func deleteServer(_ server: Server) {
        store.servers.removeAll { $0.id == server.id }
        store.saveServers()
    }

    private func checkAllStatuses() {
        for server in store.servers {
            Task {
                let online = await checkServer(host: server.host)
                serverStatuses[server.host] = online
            }
        }
    }

    private func checkServer(host: String) async -> Bool {
        do {
            _ = try await ShellService.runAsync("ping", arguments: ["-c", "1", "-W", "2", host])
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Sheets

struct TerminalSheet: View {
    let server: Server
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SSH 终端 - \(server.name)")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()

            TerminalView(title: "\(server.user)@\(server.host)", server: server)
        }
        .frame(width: 800, height: 500)
    }
}

struct MonitorSheet: View {
    let server: Server
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("服务器监控 - \(server.name)")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()

            ServerMonitorView(server: server)
        }
        .frame(width: 800, height: 600)
    }
}

struct FilesSheet: View {
    let server: Server
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("文件管理 - \(server.name)")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()

            ServerFilesView(server: server)
        }
        .frame(width: 900, height: 600)
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: Server
    let isOnline: Bool?
    let onTerminal: () -> Void
    let onMonitor: () -> Void
    let onFiles: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var statusColor: Color {
        if isOnline == true { return .green }
        if isOnline == false { return .red }
        return .gray
    }

    private var statusText: String {
        if isOnline == true { return "在线" }
        if isOnline == false { return "离线" }
        return "检测中"
    }

    var body: some View {
        HStack {
            // Left: name + status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(server.name)
                    .font(.headline)
                Text(statusText)
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(3)
            }

            Spacer()

            // Middle: connection info + auth
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(server.user)@\(server.host):\(server.port)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: server.authMethod == .key ? "key.fill" : "lock.fill")
                        .font(.caption2)
                        .foregroundColor(server.authMethod == .key ? .orange : .purple)
                    Text(server.authMethod == .key ? "密钥" : "密码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Right: action buttons
            HStack(spacing: 4) {
                Button(action: onTerminal) {
                    Image(systemName: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("终端")

                Button(action: onMonitor) {
                    Image(systemName: "chart.bar")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("监控")

                Button(action: onFiles) {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("文件")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("编辑")

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("删除")
            }
        }
        .padding(.vertical, 4)
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive, action: onDelete)
        } message: {
            Text("确定要删除服务器「\(server.name)」吗？此操作不可撤销。")
        }
    }
}

// MARK: - Server Card View

struct ServerCardView: View {
    let server: Server
    let isOnline: Bool?
    let onTerminal: () -> Void
    let onMonitor: () -> Void
    let onFiles: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var statusColor: Color {
        if isOnline == true { return .green }
        if isOnline == false { return .red }
        return .gray
    }

    private var statusText: String {
        if isOnline == true { return "在线" }
        if isOnline == false { return "离线" }
        return "检测中"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: name + description + status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(server.name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text("\(server.user)@\(server.host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(statusText)
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(3)

                    // Auth type tag
                    HStack(spacing: 3) {
                        Image(systemName: server.authMethod == .key ? "key.fill" : "lock.fill")
                            .font(.system(size: 8))
                        Text(server.authMethod == .key ? "密钥" : "密码")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((server.authMethod == .key ? Color.orange : Color.purple).opacity(0.2))
                    .foregroundColor(server.authMethod == .key ? .orange : .purple)
                    .cornerRadius(3)
                }
            }

            // Connection info (monospaced)
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(server.user)@\(server.host):\(server.port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Auth method
            HStack(spacing: 4) {
                Image(systemName: server.authMethod == .key ? "key.fill" : "lock.fill")
                    .font(.caption2)
                    .foregroundColor(server.authMethod == .key ? .orange : .purple)
                if server.authMethod == .key {
                    Text("密钥认证")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if !server.keyPath.isEmpty {
                        Text(server.keyPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text("密码认证")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Port info (only show if non-standard)
            if server.port != 22 {
                HStack(spacing: 4) {
                    Image(systemName: "cable.connector")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("端口 \(server.port)")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            Divider()

            // Bottom: quick actions
            HStack(spacing: 8) {
                Button(action: onTerminal) {
                    Label("终端", systemImage: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.blue)

                Button(action: onMonitor) {
                    Label("监控", systemImage: "chart.bar")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.green)

                Button(action: onFiles) {
                    Label("文件", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)

                Spacer()

                Menu {
                    Button("编辑", action: onEdit)
                    Divider()
                    Button("删除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .fixedSize()
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive, action: onDelete)
        } message: {
            Text("确定要删除服务器「\(server.name)」吗？此操作不可撤销。")
        }
    }
}

// MARK: - Server Edit Sheet

struct ServerEditSheet: View {
    let server: Server?
    let onSave: (Server) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var user = "root"
    @State private var keyPath = "~/.ssh/id_rsa"
    @State private var password = ""
    @State private var port = "22"
    @State private var authMethod: AuthMethod = .key
    @State private var testResult: String = ""
    @State private var isTesting = false

    var body: some View {
        VStack(spacing: 16) {
            Text(server == nil ? "添加服务器" : "编辑服务器")
                .font(.title2)
                .bold()

            Form {
                TextField("名称", text: $name)
                TextField("主机", text: $host)
                TextField("用户", text: $user)
                Picker("认证方式", selection: $authMethod) {
                    Text("SSH 密钥").tag(AuthMethod.key)
                    Text("密码").tag(AuthMethod.password)
                }
                if authMethod == .key {
                    HStack {
                        TextField("SSH 密钥", text: $keyPath)
                        Button("选择文件") {
                            let panel = NSOpenPanel()
                            panel.title = "选择 SSH 密钥文件"
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/.ssh")
                            if panel.runModal() == .OK, let url = panel.url {
                                keyPath = url.path
                            }
                        }
                    }
                } else {
                    SecureField("密码", text: $password)
                }
                TextField("端口", text: $port)
            }
            .formStyle(.grouped)

            // Test connection
            if !host.isEmpty {
                HStack {
                    Button(action: testConnection) {
                        HStack(spacing: 4) {
                            if isTesting { ProgressView().scaleEffect(0.5) }
                            Text("🔗 连接测试")
                        }
                    }
                    .disabled(isTesting || host.isEmpty)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                    }
                }
            }

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") {
                    let s = Server(
                        name: name,
                        host: host,
                        user: user,
                        keyPath: keyPath,
                        password: password,
                        port: Int(port) ?? 22,
                        authMethod: authMethod
                    )
                    onSave(s)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || host.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            if let s = server {
                name = s.name
                host = s.host
                user = s.user
                keyPath = s.keyPath
                password = s.password
                port = String(s.port)
                authMethod = s.authMethod
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = "测试中..."

        let s = Server(
            name: name,
            host: host,
            user: user,
            keyPath: keyPath,
            password: password,
            port: Int(port) ?? 22,
            authMethod: authMethod
        )

        Task {
            let (success, msg) = await SSHService.testConnection(s)
            testResult = success ? "✅ 连接成功" : "❌ 连接失败"
            isTesting = false
        }
    }
}
