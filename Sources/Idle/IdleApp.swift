import AppKit
import SwiftUI

@main
struct IdleApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var dashboardWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private let lifecycle = Lifecycle()
    private let caffeinate = Caffeinate()
    private let vault = Vault()
    private let launchAtLogin = LaunchAtLogin()
    private let clipboard = Clipboard()
    private let preflight = Preflight()
    private let remoteConfig = RemoteConfig()
    private var welcomeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Idle"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 540)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                lifecycle: lifecycle,
                caffeinate: caffeinate,
                launchAtLogin: launchAtLogin,
                openDashboards: { [weak self] in self?.showDashboards() },
                openOnboarding: { [weak self] in self?.showOnboarding() }
            )
        )

        lifecycle.startPolling()
        clipboard.startPolling()
        Task { await remoteConfig.refresh() }

        if !UserDefaults.hasCompletedWelcome {
            // Slight delay so the menu bar is fully rendered when the welcome
            // window pops up — avoids the hosting controller competing with
            // status item layout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showWelcome()
            }
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            lifecycle.refresh()
            caffeinate.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func showDashboards() {
        popover.performClose(nil)

        if let window = dashboardWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Idle Dashboards"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: DashboardsView(lifecycle: lifecycle)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow = window
    }

    func showWelcome() {
        if let window = welcomeWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Idle"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: WelcomeView(
                preflight: preflight,
                vault: vault,
                onContinue: { [weak self] in
                    self?.welcomeWindow?.close()
                    self?.welcomeWindow = nil
                    self?.showOnboarding()
                }
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow = window
    }

    func showOnboarding() {
        popover.performClose(nil)

        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Idle Onboarding"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(vault: vault, clipboard: clipboard)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
