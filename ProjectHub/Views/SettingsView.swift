import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ProjectStore
    @AppStorage("registryPath") private var registryPath = "~/.openclaw/skills/workspace-governance/registry"
    @AppStorage("defaultEditor") private var defaultEditor = "Visual Studio Code"

    var body: some View {
        Form {
            Section("注册表") {
                TextField("注册表路径", text: $registryPath)
                    .textFieldStyle(.roundedBorder)
                Text("workspace-governance 的 projects.yaml 所在目录")
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
