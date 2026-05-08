import AppKit
import SwiftUI
import Combine

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
    private let installer = Installer()
    private let earnings = Earnings()
    private let earningsHistory = EarningsHistory()
    private let prices = PriceFetcher()
    private let mining = Mining()
    private let manualEarnings = ManualEarnings()
    private var welcomeWindow: NSWindow?
    private var earningsWindow: NSWindow?
    private var earningsObserver: AnyObject?

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
                mining: mining,
                openDashboards: { [weak self] in self?.showDashboards() },
                openOnboarding: { [weak self] in self?.showOnboarding() },
                openEarnings: { [weak self] in self?.showEarnings() }
            )
        )

        lifecycle.startPolling()
        clipboard.startPolling()
        earnings.history = earningsHistory
        prices.startPolling()
        Task { await remoteConfig.refresh() }

        // Pre-load each app's dashboard WKWebView at launch so the earnings
        // scraper has DOM to read against. Without this the cache is empty
        // until the user opens the Dashboards window.
        preloadDashboardWebViews()

        // Earnings polling runs continuously from launch, not only when the
        // user opens a window. The JSONL log fills in passively in the
        // background.
        earnings.startPolling()

        // Update menu bar title with live total whenever earnings or manual
        // entries change. Trusted total (manual) wins over scraper estimate.
        earningsObserver = Publishers.CombineLatest(
            earnings.$readings,
            Publishers.Merge(manualEarnings.$balances.map { _ in () }, manualEarnings.$payouts.map { _ in () })
        )
        .sink { [weak self] _ in
            Task { @MainActor in self?.refreshStatusBarTitle() }
        }

        if !UserDefaults.hasCompletedWelcome {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showWelcome()
            }
        }
    }

    /// Initialize a hidden WKWebView per app so cookies/auth load and the
    /// scraper has data to read. We do NOT add them to a window — they live
    /// in WebViewCache.shared and are queried by Earnings.refreshAll().
    private func preloadDashboardWebViews() {
        for app in AppRegistry.all {
            _ = WebViewCache.shared.view(for: "dashboard.\(app.id)", url: app.dashboardURL)
        }
    }

    /// Refresh the menu bar status item.
    /// Trusted total (manual entries + payouts) wins. Scraper estimate is
    /// only used as a fallback when no manual data exists.
    private func refreshStatusBarTitle() {
        guard let button = statusItem.button else { return }
        let trusted = manualEarnings.trustableUSD
        if trusted > 0 {
            button.title = String(format: "Idle · $%.2f", trusted)
        } else {
            button.title = "Idle"
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
            rootView: DashboardsView(lifecycle: lifecycle, earnings: earnings)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow = window
        earnings.startPolling()
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

    func showEarnings() {
        popover.performClose(nil)

        if let window = earningsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Idle Earnings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: EarningsDashboardView(
                earnings: earnings,
                history: earningsHistory,
                prices: prices,
                manual: manualEarnings
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        earningsWindow = window
        // Make sure earnings polling is running so the dashboard isn't empty.
        earnings.startPolling()
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
            rootView: OnboardingView(vault: vault, clipboard: clipboard, installer: installer, lifecycle: lifecycle)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
