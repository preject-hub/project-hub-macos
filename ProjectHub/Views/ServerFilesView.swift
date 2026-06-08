import SwiftUI
import AppKit

struct FileItem: Identifiable {
    var id: String { path }
    var name: String
    var path: String
    var isDirectory: Bool
    var size: String
    var permissions: String
    var modified: String
    var owner: String

    var icon: String {
        if isDirectory { return "folder.fill" }
        if name.hasSuffix(".py") { return "text.badge.checkmark" }
        if name.hasSuffix(".sh") { return "terminal" }
        if name.hasSuffix(".conf") || name.hasSuffix(".yml") || name.hasSuffix(".yaml") { return "gear" }
        if name.hasSuffix(".log") { return "doc.plaintext" }
        if name.hasSuffix(".tar") || name.hasSuffix(".gz") || name.hasSuffix(".zip") { return "archivebox" }
        if name.hasSuffix(".jpg") || name.hasSuffix(".png") || name.hasSuffix(".gif") { return "photo" }
        if name.hasSuffix(".mp4") || name.hasSuffix(".mov") { return "film" }
        return "doc"
    }
}

struct ServerFilesView: View {
    let server: Server
    @State private var currentPath: String = "/"
    @State private var files: [FileItem] = []
    @State private var isLoading = false
    @State private var pathHistory: [String] = ["/"]
    @State private var pathInput: String = "/"
    @State private var errorMessage: String?
    @State private var selectedFile: FileItem?
    @State private var fileContent: String?
    @State private var showFileContent = false
    @State private var showUploadPanel = false
    @State private var uploadStatus: String?
    @State private var downloadStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.accentColor)
                Text("文件管理 - \(server.name)")
                    .font(.headline)
                Spacer()
                Button(action: uploadFile) {
                    Label("上传", systemImage: "arrow.up.doc")
                }
            }
            .padding(10)
            .background(Color(.windowBackgroundColor))

            // Navigation bar
            HStack(spacing: 8) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(pathHistory.count <= 1)

                Button(action: goUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(currentPath == "/")

                Button(action: goToHome) {
                    Image(systemName: "house")
                }

                TextField("路径", text: $pathInput, onCommit: {
                    navigateTo(pathInput)
                })
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                Button("前往") { navigateTo(pathInput) }

                Button("刷新") { loadFiles() }
                    .disabled(isLoading)
            }
            .padding(8)

            Divider()

            // Status messages
            if let status = uploadStatus {
                HStack {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                    Button("✕") { uploadStatus = nil }
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
            }

            if let status = downloadStatus {
                HStack {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    Button("✕") { downloadStatus = nil }
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
            }

            // File list
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                List(files) { file in
                    FileRow(file: file)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if file.isDirectory {
                                navigateTo(file.path)
                            } else {
                                viewFile(file)
                            }
                        }
                        .onTapGesture(count: 1) {
                            selectedFile = file
                        }
                        .contextMenu {
                            if !file.isDirectory {
                                Button("查看/编辑") { viewFile(file) }
                                Button("下载到本地") { downloadFile(file) }
                                Divider()
                            }
                            Button("删除") { deleteFile(file) }
                                .foregroundColor(.red)
                        }
                }
                .listStyle(.inset)
            }

            // Status bar
            HStack {
                Text("\(files.count) 项")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(currentPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(6)
            .background(Color(.controlBackgroundColor))
        }
        .sheet(isPresented: $showFileContent) {
            FileContentView(
                file: selectedFile,
                initialContent: fileContent ?? "",
                server: server,
                onSaved: { loadFiles() }
            )
        }
        .onAppear { loadFiles() }
    }

    // MARK: - Navigation

    func navigateTo(_ path: String) {
        currentPath = path
        pathInput = path
        pathHistory.append(path)
        loadFiles()
    }

    func goBack() {
        if pathHistory.count > 1 {
            pathHistory.removeLast()
            currentPath = pathHistory.last ?? "/"
            pathInput = currentPath
            loadFiles()
        }
    }

    func goUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        navigateTo(parent.isEmpty ? "/" : parent)
    }

    func goToHome() {
        navigateTo("/root")
    }

    // MARK: - File Operations

    func loadFiles() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let cmd = "ls -la \(currentPath) | tail -n +2"
                let output = try await SSHService.exec(server, command: cmd)
                let lines = output.split(separator: "\n").map { String($0) }

                var items: [FileItem] = []
                for line in lines {
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    guard parts.count >= 9 else { continue }

                    let perms = String(parts[0])
                    let owner = String(parts[2])
                    let size = String(parts[4])
                    let month = String(parts[5])
                    let day = String(parts[6])
                    let timeOrYear = String(parts[7])
                    let name = parts[8...].joined(separator: " ")

                    if name == "." || name == ".." { continue }

                    let isDir = perms.hasPrefix("d") || perms.hasPrefix("l")
                    let fullPath = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"

                    items.append(FileItem(
                        name: name,
                        path: fullPath,
                        isDirectory: isDir,
                        size: size,
                        permissions: perms,
                        modified: "\(month) \(day) \(timeOrYear)",
                        owner: owner
                    ))
                }

                files = items.sorted { a, b in
                    if a.isDirectory != b.isDirectory { return a.isDirectory }
                    return a.name < b.name
                }
            } catch {
                errorMessage = "加载失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func viewFile(_ file: FileItem) {
        selectedFile = file
        fileContent = nil
        showFileContent = true

        Task {
            fileContent = try? await SSHService.exec(server, command: "cat '\(file.path)' | head -1000")
            if fileContent?.isEmpty ?? true {
                fileContent = "(空文件或无法读取)"
            }
        }
    }

    func uploadFile() {
        let panel = NSOpenPanel()
        panel.title = "选择要上传的文件"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            let localPath = url.path
            let remotePath = currentPath == "/" ? "/\(url.lastPathComponent)" : "\(currentPath)/\(url.lastPathComponent)"

            uploadStatus = "上传中: \(url.lastPathComponent)..."

            Task {
                do {
                    let remote = "\(server.user)@\(server.host):\(remotePath)"
                    let args = SSHService.scpArgs(for: server, source: localPath, destination: remote)
                    _ = try await ShellService.runAsync(args[0], arguments: Array(args.dropFirst()))
                    uploadStatus = "✅ 上传成功: \(url.lastPathComponent)"
                    loadFiles()
                } catch {
                    uploadStatus = "❌ 上传失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func downloadFile(_ file: FileItem) {
        let panel = NSSavePanel()
        panel.title = "保存文件"
        panel.nameFieldStringValue = file.name
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")

        if panel.runModal() == .OK, let url = panel.url {
            downloadStatus = "下载中: \(file.name)..."

            Task {
                do {
                    let remote = "\(server.user)@\(server.host):\(file.path)"
                    let args = SSHService.scpArgs(for: server, source: remote, destination: url.path)
                    _ = try await ShellService.runAsync(args[0], arguments: Array(args.dropFirst()))
                    downloadStatus = "✅ 下载完成: \(url.path)"
                } catch {
                    downloadStatus = "❌ 下载失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func deleteFile(_ file: FileItem) {
        Task {
            _ = try? await SSHService.exec(server, command: "rm -rf '\(file.path)'")
            loadFiles()
        }
    }
}

struct FileRow: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.icon)
                .foregroundColor(file.isDirectory ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Text(file.permissions)
                        .font(.caption2)
                    Text(file.owner)
                        .font(.caption2)
                    Text(file.modified)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            if !file.isDirectory {
                Text(file.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct FileContentView: View {
    let file: FileItem?
    let initialContent: String
    let server: Server
    let onSaved: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var content: String = ""
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var saveStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                Text(file?.name ?? "文件")
                    .font(.headline)
                Spacer()
                if let path = file?.path {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if isEditing {
                    Button(action: saveFile) {
                        HStack(spacing: 4) {
                            if isSaving { ProgressView().scaleEffect(0.5) }
                            Text("保存")
                        }
                    }
                    .disabled(isSaving)
                    Button("取消") {
                        content = initialContent
                        isEditing = false
                    }
                } else {
                    Button("编辑") {
                        isEditing = true
                    }
                }
                Button("关闭") { dismiss() }
            }
            .padding()

            // Save status
            if let status = saveStatus {
                HStack {
                    Text(status)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(status.contains("✅") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            }

            Divider()

            // Content
            if isEditing {
                TextEditor(text: $content)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(.textBackgroundColor))
            } else {
                ScrollView {
                    Text(content.isEmpty ? "加载中..." : content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(.textBackgroundColor))
            }
        }
        .frame(width: 750, height: 550)
        .onAppear {
            content = initialContent
        }
        .onChange(of: initialContent) {
            if !isEditing { content = initialContent }
        }
    }

    func saveFile() {
        guard let path = file?.path else { return }
        isSaving = true
        saveStatus = nil

        Task {
            do {
                // Write content to temp file, then SCP to remote
                let tempPath = "/tmp/project-hub-edit-\(UUID().uuidString).txt"
                try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
                defer { try? FileManager.default.removeItem(atPath: tempPath) }

                let remote = "\(server.user)@\(server.host):\(path)"
                let args = SSHService.scpArgs(for: server, source: tempPath, destination: remote)
                _ = try await ShellService.runAsync(args[0], arguments: Array(args.dropFirst()))

                saveStatus = "✅ 保存成功"
                isEditing = false
                onSaved()
            } catch {
                saveStatus = "❌ 保存失败: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}
