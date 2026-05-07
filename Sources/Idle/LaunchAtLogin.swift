import Foundation
import ServiceManagement
import Combine

/// Wraps `SMAppService.mainApp` so the menu bar can offer a launch-at-login toggle.
///
/// Only meaningful when running from a `.app` bundle (i.e., after running
/// `Scripts/build_app.sh --install`). When running via `swift run`, the
/// service registration will fail; we degrade gracefully and surface that
/// state so the UI can hide / disable the toggle.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var isAvailable: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            isEnabled = true
            isAvailable = true
        case .requiresApproval:
            isEnabled = true // user toggled but hasn't approved in System Settings yet
            isAvailable = true
        case .notRegistered:
            isEnabled = false
            isAvailable = isRunningFromBundle()
        case .notFound:
            isEnabled = false
            isAvailable = false
        @unknown default:
            isEnabled = false
            isAvailable = false
        }
    }

    func setEnabled(_ value: Bool) {
        let service = SMAppService.mainApp
        do {
            if value {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // Best effort. SMAppService throws if running from a non-bundled
            // binary or in dev. The refresh below will reflect actual state.
        }
        refresh()
    }

    /// Heuristic: SMAppService.register() will only succeed for an `.app`
    /// bundle, so if Bundle.main has a real bundle identifier and the
    /// executable lives inside `.app/Contents/MacOS/...`, we treat it as
    /// available.
    private func isRunningFromBundle() -> Bool {
        guard let exec = Bundle.main.executableURL?.path else { return false }
        return exec.contains(".app/Contents/MacOS/")
    }
}
