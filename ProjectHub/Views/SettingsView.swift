import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ProjectStore
    @AppStorage("workspacePath") private var workspacePath = "~/workspace"

    @AppStorage("defaultEditor") private var defaultEditor = "Visual Studio Code"
    @AppStorage("defaultProjectDirectory") private var defaultProjectDirectory = ""

    var body: some View {
        Form {
            Section("Workspace") {
                HStack {
                    TextField("~/workspace", text: $workspacePath)
                        .textFieldStyle(.roundedBorder)
                    Button("选择...") {
                        let panel = NSOpenPanel()
                        panel.title = "选择 Workspace 根目录"
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true
                        panel.allowsMultipleSelection = false
                        let expanded = (workspacePath as NSString).expandingTildeInPath
                        if !workspacePath.isEmpty {
                            panel.directoryURL = URL(fileURLWithPath: expanded)
                        }
                        if panel.runModal() == .OK, let url = panel.url {
                            let home = FileManager.default.homeDirectoryForCurrentUser.path
                            if url.path.hasPrefix(home) {
                                workspacePath = "~" + url.path.dropFirst(home.count)
                            } else {
                                workspacePath = url.path
                            }
                        }
                    }
                }
                Text("workspace 根目录，新建项目的默认存放位置。修改后仅影响后续新建项目。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("注册表自动位于 \(workspacePath)/registry/")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("注册表") {
                HStack {
                    Text("路径")
                    Spacer()
                    Text("\(workspacePath)/registry")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Text("注册表位于 workspace 根目录下的 registry/ 子目录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("默认项目目录") {
                HStack {
                    TextField("未设置", text: $defaultProjectDirectory)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button("选择...") {
                        let panel = NSOpenPanel()
                        panel.title = "选择默认项目目录"
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true
                        panel.allowsMultipleSelection = false
                        if !defaultProjectDirectory.isEmpty {
                            panel.directoryURL = URL(fileURLWithPath: (defaultProjectDirectory as NSString).expandingTildeInPath)
                        }
                        if panel.runModal() == .OK, let url = panel.url {
                            let home = FileManager.default.homeDirectoryForCurrentUser.path
                            if url.path.hasPrefix(home) {
                                defaultProjectDirectory = "~" + url.path.dropFirst(home.count)
                            } else {
                                defaultProjectDirectory = url.path
                            }
                        }
                    }
                    if !defaultProjectDirectory.isEmpty {
                        Button("清除") {
                            defaultProjectDirectory = ""
                        }
                    }
                }
                Text("新建项目时的默认存放目录，留空则不限定")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("默认编辑器") {
                Picker("编辑器", selection: $defaultEditor) {
                    Text("Visual Studio Code").tag("Visual Studio Code")
                    Text("Xcode").tag("Xcode")
                    Text("DevEco Studio").tag("DevEco Studio")
                    Text("WebStorm").tag("WebStorm")
                    Text("IntelliJ IDEA").tag("IntelliJ IDEA")
                }
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("0.1.0")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("项目")
                    Spacer()
                    Button("GitHub") {
                        ShellService.openURL("https://github.com/mapmiao/project-hub")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("设置")
    }
}
