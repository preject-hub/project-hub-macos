import SwiftUI

struct ServerMonitorView: View {
    let server: Server
    @State private var cpuUsage: String = "--"
    @State private var memoryUsage: String = "--"
    @State private var diskUsage: String = "--"
    @State private var uptime: String = "--"
    @State private var loadAvg: String = "--"
    @State private var processes: String = "--"
    @State private var processCount: String = "--"
    @State private var networkInfo: String = "--"
    @State private var isMonitoring = false
    @State private var autoRefresh = true
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                Text("服务器监控 - \(server.name)")
                    .font(.headline)
                Spacer()
                Toggle("自动刷新", isOn: $autoRefresh)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: autoRefresh) {
                        if autoRefresh { startAutoRefresh() }
                        else { stopAutoRefresh() }
                    }
                Button("刷新") { refresh() }
                    .disabled(isMonitoring)
            }
            .padding(10)
            .background(Color(.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Status cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MonitorCard(title: "CPU", value: cpuUsage, icon: "cpu", color: cpuColor)
                        MonitorCard(title: "内存", value: memoryUsage, icon: "memorychip", color: memoryColor)
                        MonitorCard(title: "磁盘", value: diskUsage, icon: "internaldrive", color: diskColor)
                        MonitorCard(title: "运行时间", value: uptime, icon: "clock", color: .blue)
                        MonitorCard(title: "负载", value: loadAvg, icon: "gauge", color: loadColor)
                        MonitorCard(title: "进程数", value: processCount, icon: "list.number", color: .purple)
                    }

                    // Network
                    VStack(alignment: .leading, spacing: 8) {
                        Label("网络信息", systemImage: "network")
                            .font(.headline)
                        Text(networkInfo)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                    }

                    // Top processes
                    VStack(alignment: .leading, spacing: 8) {
                        Label("资源占用 Top 5", systemImage: "list.number")
                            .font(.headline)
                        ScrollView {
                            Text(processes)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 120)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            refresh()
            if autoRefresh { startAutoRefresh() }
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Colors

    var cpuColor: Color { usageColor(cpuUsage) }
    var memoryColor: Color { usageColor(memoryUsage) }
    var diskColor: Color { usageColor(diskUsage) }
    var loadColor: Color {
        let val = Double(loadAvg.split(separator: " ").first ?? "0") ?? 0
        if val > 2.0 { return .red }
        if val > 1.0 { return .orange }
        return .green
    }

    func usageColor(_ str: String) -> Color {
        let val = Double(str.replacingOccurrences(of: "%", with: "")) ?? 0
        if val > 80 { return .red }
        if val > 60 { return .orange }
        return .green
    }

    // MARK: - Refresh

    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            refresh()
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        isMonitoring = true

        Task {
            // CPU
            cpuUsage = (try? await sshCmd(server, "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"
            if cpuUsage != "--" { cpuUsage = cpuUsage + "%" }

            // Memory
            memoryUsage = (try? await sshCmd(server, "free | awk '/Mem/{printf \"%.1f%%\", $3/$2*100}'"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            // Disk
            diskUsage = (try? await sshCmd(server, "df -h / | awk 'NR==2{print $5}'"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            // Uptime
            uptime = (try? await sshCmd(server, "cat /proc/uptime | awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60);printf \"%d天%d小时%d分\",d,h,m}'"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            // Load average
            loadAvg = (try? await sshCmd(server, "cat /proc/loadavg | cut -d' ' -f1-3"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            // Process count
            processCount = (try? await sshCmd(server, "ps aux | wc -l"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            // Top processes
            processes = (try? await sshCmd(server, "ps aux --sort=-%mem | head -6 | awk '{printf \"%-10s %-6s %-6s %s\\n\", $1, $3, $4, $11}'"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            // Network
            networkInfo = (try? await sshCmd(server, "ip -4 addr show | grep inet | awk '{printf \"%-15s %s\\n\", $2, $NF}'"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--"

            isMonitoring = false
        }
    }

    private func sshCmd(_ server: Server, _ command: String) async throws -> String {
        try await SSHService.exec(server, command: command)
    }
}

struct MonitorCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}
