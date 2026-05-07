import SwiftUI

struct MenuBarView: View {
    @ObservedObject var lifecycle: Lifecycle
    @ObservedObject var caffeinate: Caffeinate
    @ObservedObject var launchAtLogin: LaunchAtLogin
    let openDashboards: () -> Void
    let openOnboarding: () -> Void
    let openEarnings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(AppRegistry.all) { app in
                        AppRow(app: app, status: lifecycle.statuses[app.id] ?? .notInstalled, lifecycle: lifecycle)
                    }
                }
                .padding(12)
            }
            Divider()
            HStack(spacing: 0) {
                MenuBarLink(systemImage: "wand.and.stars", title: "Setup", action: openOnboarding)
                Divider().frame(height: 24)
                MenuBarLink(systemImage: "chart.line.uptrend.xyaxis", title: "Earnings", action: openEarnings)
                Divider().frame(height: 24)
                MenuBarLink(systemImage: "square.grid.2x2", title: "Dashboards", action: openDashboards)
            }
            Divider()
            footer
        }
        .frame(width: 380, height: 540)
    }

    private var header: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
            Text("Idle")
                .font(.headline)
            Spacer()
            Toggle(isOn: Binding(
                get: { caffeinate.isActive },
                set: { newValue in newValue ? caffeinate.start() : caffeinate.stop() }
            )) {
                Text("Stay awake")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Refresh") { lifecycle.refresh() }
                .buttonStyle(.borderless)
            if launchAtLogin.isAvailable {
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )) {
                    Text("Launch at login")
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            Spacer()
            Button("Quit Idle") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .font(.caption)
    }
}

private struct MenuBarLink: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AppRow: View {
    let app: DePinApp
    let status: AppStatus
    @ObservedObject var lifecycle: Lifecycle

    var body: some View {
        HStack(spacing: 10) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            actionButton
            Menu {
                Button("Open dashboard") { lifecycle.openDashboard(app) }
                Button("Sign up (referral)") { lifecycle.openSignup(app) }
                if app.downloadURL != nil {
                    Button(app.kind == .chromeExtension ? "Install extension" : "Download installer") {
                        lifecycle.openDownload(app)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
    }

    private var dotColor: Color {
        switch status {
        case .running: return .green
        case .installedNotRunning: return .orange
        case .notInstalled: return .gray
        }
    }

    private var subtitle: String {
        switch status {
        case .running: return "Running · \(payoutLabel)"
        case .installedNotRunning: return "Installed · \(payoutLabel)"
        case .notInstalled:
            return app.kind == .chromeExtension ? "Chrome extension" : "Not installed · \(payoutLabel)"
        }
    }

    private var payoutLabel: String {
        switch app.payoutKind {
        case .usd: return "USD"
        case .token(let symbol): return symbol
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .running:
            Button("Quit") { lifecycle.quit(app) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .installedNotRunning:
            Button("Launch") { lifecycle.launch(app) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .notInstalled:
            if app.kind == .chromeExtension {
                Button("Install") { lifecycle.openDownload(app) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else if app.downloadURL != nil {
                Button("Get") { lifecycle.openDownload(app) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
