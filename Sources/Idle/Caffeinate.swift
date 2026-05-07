import Foundation
import Combine

@MainActor
final class Caffeinate: ObservableObject {
    @Published private(set) var isActive: Bool = false
    private var process: Process?

    init() {
        isActive = checkExternalCaffeinate()
    }

    func start() {
        guard process == nil else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-imsu"]
        do {
            try p.run()
            process = p
            isActive = true
        } catch {
            isActive = false
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isActive = checkExternalCaffeinate()
    }

    /// True if any caffeinate process is running, even one we didn't start
    /// (e.g. the LaunchAgent that the install script set up).
    private func checkExternalCaffeinate() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-x", "caffeinate"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    func refresh() {
        if process == nil {
            isActive = checkExternalCaffeinate()
        }
    }
}
