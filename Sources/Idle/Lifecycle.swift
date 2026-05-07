import Foundation
import AppKit

enum AppStatus {
    case notInstalled
    case installedNotRunning
    case running
}

@MainActor
final class Lifecycle: ObservableObject {
    @Published private(set) var statuses: [String: AppStatus] = [:]
    private var timer: Timer?

    init() { refresh() }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        var next: [String: AppStatus] = [:]
        for app in AppRegistry.all {
            next[app.id] = status(for: app)
        }
        statuses = next
    }

    func status(for app: DePinApp) -> AppStatus {
        guard app.kind == .nativeApp else {
            return .notInstalled
        }
        guard let path = app.appPath, FileManager.default.fileExists(atPath: path) else {
            return .notInstalled
        }
        if let bundleID = app.bundleIdentifier,
           !NSWorkspace.shared.runningApplications.filter({ $0.bundleIdentifier == bundleID }).isEmpty {
            return .running
        }
        return .installedNotRunning
    }

    func launch(_ app: DePinApp) {
        guard let path = app.appPath else { return }
        let url = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func quit(_ app: DePinApp) {
        guard let bundleID = app.bundleIdentifier else { return }
        for running in NSWorkspace.shared.runningApplications where running.bundleIdentifier == bundleID {
            running.terminate()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.refresh()
        }
    }

    func openSignup(_ app: DePinApp) {
        NSWorkspace.shared.open(app.signupURL)
    }

    func openDashboard(_ app: DePinApp) {
        NSWorkspace.shared.open(app.dashboardURL)
    }

    func openDownload(_ app: DePinApp) {
        if let url = app.downloadURL {
            NSWorkspace.shared.open(url)
        }
    }
}
