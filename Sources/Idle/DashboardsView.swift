import SwiftUI
import WebKit

/// Unified dashboards window — sidebar lists every supported DePIN app,
/// main panel renders the selected app's web dashboard inside a WKWebView.
/// Each app gets its own persistent webview so signed-in cookies and form
/// state survive when the user clicks between apps.
struct DashboardsView: View {
    @ObservedObject var lifecycle: Lifecycle
    @State private var selection: String

    init(lifecycle: Lifecycle) {
        self.lifecycle = lifecycle
        _selection = State(initialValue: AppRegistry.all.first?.id ?? "pawns")
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
    }

    private var sidebar: some View {
        List(AppRegistry.all, selection: $selection) { app in
            HStack(spacing: 10) {
                Circle()
                    .fill(dotColor(for: app))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.body.weight(.medium))
                    Text(payoutLabel(for: app))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tag(app.id)
            .contextMenu {
                Button("Sign up (referral)") { lifecycle.openSignup(app) }
                if app.downloadURL != nil {
                    Button(app.kind == .chromeExtension ? "Install extension" : "Download installer") {
                        lifecycle.openDownload(app)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
    }

    private var detail: some View {
        Group {
            if let app = AppRegistry.all.first(where: { $0.id == selection }) {
                WebDashboard(app: app)
                    .navigationTitle(app.name)
            } else {
                Text("Select an app")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dotColor(for app: DePinApp) -> Color {
        switch lifecycle.statuses[app.id] ?? .notInstalled {
        case .running: return .green
        case .installedNotRunning: return .orange
        case .notInstalled: return .gray
        }
    }

    private func payoutLabel(for app: DePinApp) -> String {
        switch app.payoutKind {
        case .usd: return "USD"
        case .token(let symbol): return symbol
        }
    }
}

/// One persistent WKWebView per app, cached so cookies/auth survive selection.
struct WebDashboard: View {
    let app: DePinApp

    var body: some View {
        WebView(url: app.dashboardURL, key: "dashboard.\(app.id)")
            .id(app.id)
    }
}
