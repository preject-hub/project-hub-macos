import SwiftUI

struct BuildTab: View {
    let project: Project
    @State private var output = ""
    @State private var isBuilding = false
    @State private var customCommand = ""

    var body: some View {
        VStack(spacing: 0) {
            // Quick build buttons
            HStack(spacing: 8) {
                BuildButton(title: "📦 npm build", action: { build("npm run build") })
                BuildButton(title: "📦 pnpm build", action: { build("pnpm build") })
                BuildButton(title: "🔨 HAP 打包", action: { build(hapCommand) })
                BuildButton(title: "🧹 Clean", action: { build("npm run clean") })
            }
            .padding(10)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Custom command
            HStack {
                TextField("自定义命令...", text: $customCommand)
                    .textFieldStyle(.plain)
                Button("运行") {
                    if !customCommand.isEmpty {
                        build(customCommand)
                    }
                }
                .disabled(customCommand.isEmpty || isBuilding)
            }
            .padding(10)

            Divider()

            // Output
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("构建输出")
                        .font(.headline)
                    Spacer()
                    if isBuilding {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Button("清空") { output = "" }
                        .font(.caption)
                }

                ScrollView {
                    Text(output.isEmpty ? "点击上方按钮开始构建" : output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
            }
            .padding()
        }
    }

    var hapCommand: String {
        """
        /Applications/IDE/DevEco-Studio.app/Contents/tools/node/bin/node \
        /Applications/IDE/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
        --mode module -p product=default assembleHap \
        --analyze=normal --parallel --incremental
        """
    }

    private func build(_ command: String) {
        isBuilding = true
        output = "执行: \(command)\n\n"

        Task {
            do {
                let result = try await ShellService.runAsync("bash", arguments: ["-c", command], at: project.paths.resolvedSource)
                output += result
                output += "\n\n✅ 构建完成"
            } catch {
                output += "\n\n❌ 构建失败: \(error.localizedDescription)"
            }
            isBuilding = false
        }
    }
}

struct BuildButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
