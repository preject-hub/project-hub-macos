import SwiftUI

struct ServersView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var showAddSheet = false
    @State private var editingServer: Server?
    @State private var serverStatuses: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("服务器管理")
                    .font(.title2)
                    .bold()
                Spacer()
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
            } else {
                List {
                    ForEach(store.servers) { server in
                        ServerRow(
                            server: server,
                            isOnline: serverStatuses[server.host],
                            onSSH: { ShellService.openTerminal(at: server.host) },
                            onEdit: { editingServer = server },
                            onDelete: { deleteServer(server) }
                        )
                    }
                }
                .listStyle(.inset)
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

struct ServerRow: View {
    let server: Server
    let isOnline: Bool?
    let onSSH: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(isOnline == true ? Color.green : (isOnline == false ? Color.red : Color.gray))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.headline)
                Text("\(server.user)@\(server.host):\(server.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("SSH") { onSSH() }
                .font(.caption)
            Button("编辑") { onEdit() }
                .font(.caption)
            Button("删除") { onDelete() }
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct ServerEditSheet: View {
    let server: Server?
    let onSave: (Server) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var user = "root"
    @State private var keyPath = "~/.ssh/id_rsa"
    @State private var port = "22"

    var body: some View some View {
        VStack(spacing: 16) {
            Text(server == nil ? "添加服务器" : "编辑服务器")
                .font(.title2)
                .bold()

            Form {
                TextField("名称", text: $name)
                TextField("主机", text: $host)
                TextField("用户", text: $user)
                TextField("SSH 密钥", text: $keyPath)
                TextField("端口", text: $port)
            }
            .formStyle(.grouped)

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") {
                    let s = Server(
                        name: name,
                        host: host,
                        user: user,
                        keyPath: keyPath,
                        port: Int(port) ?? 22
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
                port = String(s.port)
            }
        }
    }
}
