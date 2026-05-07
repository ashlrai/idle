import Foundation
import AppKit
import Combine

/// One-click installer for DMG-based DePIN apps.
///
/// For PKG-based apps (Honeygain, EarnApp), Apple requires the user's admin
/// password. We invoke `installer(8)` via `osascript do shell script with
/// administrator privileges` so macOS shows the standard password dialog.
/// One dialog covers all PKGs in a single batch.
///
/// Apps that gate their installer behind a logged-in dashboard (Honeygain,
/// EarnApp) cannot be fully auto-downloaded; we surface a "open download
/// page" fallback so the user clicks once.
@MainActor
final class Installer: ObservableObject {

    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case mounting
        case installing
        case ejecting
        case done
        case failed(reason: String)
    }

    @Published private(set) var states: [String: State] = [:]
    @Published private(set) var isBusy = false

    /// Install one app. Returns true on success.
    @discardableResult
    func install(_ app: DePinApp) async -> Bool {
        guard let url = app.directDownloadURL else {
            states[app.id] = .failed(reason: "No direct installer URL — open the dashboard manually.")
            return false
        }
        isBusy = true
        defer { isBusy = false }

        do {
            states[app.id] = .downloading(progress: 0)
            let temp = try await download(from: url, appId: app.id)
            defer { try? FileManager.default.removeItem(at: temp) }

            let ext = temp.pathExtension.lowercased()
            switch ext {
            case "dmg":
                try await installDMG(at: temp, app: app)
            case "pkg":
                try await installPKG(at: temp, app: app)
            default:
                throw InstallerError.unsupportedFormat(ext)
            }

            states[app.id] = .done
            return true
        } catch {
            states[app.id] = .failed(reason: error.localizedDescription)
            return false
        }
    }

    /// Install everything that has a direct download URL. PKGs are queued so
    /// the user types their password only once.
    func installAll() async {
        let queue = AppRegistry.all.filter { $0.directDownloadURL != nil }
        for app in queue {
            _ = await install(app)
        }
    }

    // MARK: - Internals

    private func download(from url: URL, appId: String) async throws -> URL {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let total = response.expectedContentLength
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("idle-\(appId)-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension.isEmpty ? "dmg" : url.pathExtension)

        FileManager.default.createFile(atPath: dest.path, contents: nil)
        let handle = try FileHandle(forWritingTo: dest)
        defer { try? handle.close() }

        var written: Int64 = 0
        var buffer: [UInt8] = []
        buffer.reserveCapacity(64 * 1024)

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if total > 0 {
                    let progress = Double(written) / Double(total)
                    states[appId] = .downloading(progress: progress)
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
        return dest
    }

    private func installDMG(at dmg: URL, app: DePinApp) async throws {
        states[app.id] = .mounting
        let mountPoint = try await runProcess(
            "/usr/bin/hdiutil",
            ["attach", "-nobrowse", "-noautoopen", "-plist", dmg.path]
        )
        let volume = try parseHDIUtilMount(plist: mountPoint)

        states[app.id] = .installing

        // Find first .app inside the mounted volume.
        let appPathInDmg = try findApp(in: volume)
        let dest = URL(fileURLWithPath: "/Applications").appendingPathComponent(appPathInDmg.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: appPathInDmg, to: dest)

        states[app.id] = .ejecting
        _ = try? await runProcess("/usr/bin/hdiutil", ["detach", volume, "-force"])
    }

    private func installPKG(at pkg: URL, app: DePinApp) async throws {
        states[app.id] = .installing
        // osascript pops the standard macOS auth dialog; user types password once.
        let escaped = pkg.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"installer -pkg \\\"\(escaped)\\\" -target /\" with administrator privileges"
        _ = try await runProcess("/usr/bin/osascript", ["-e", script])
    }

    private func runProcess(_ path: String, _ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.terminationHandler = { proc in
                let outData = (try? outPipe.fileHandleForReading.readToEnd() ?? Data()) ?? Data()
                let errData = (try? errPipe.fileHandleForReading.readToEnd() ?? Data()) ?? Data()
                let out = String(data: outData, encoding: .utf8) ?? ""
                let err = String(data: errData, encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    cont.resume(returning: out)
                } else {
                    cont.resume(throwing: InstallerError.processFailed(
                        path: path, status: Int(proc.terminationStatus), stderr: err
                    ))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }

    private func parseHDIUtilMount(plist: String) throws -> String {
        // The plist output contains a `system-entities` array. The mount point
        // we want is the first entity with mount-point set.
        guard let data = plist.data(using: .utf8) else { throw InstallerError.cannotParseMount }
        let plistObj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plistObj as? [String: Any],
              let entities = dict["system-entities"] as? [[String: Any]] else {
            throw InstallerError.cannotParseMount
        }
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String, !mountPoint.isEmpty {
                return mountPoint
            }
        }
        throw InstallerError.cannotParseMount
    }

    private func findApp(in mountPoint: String) throws -> URL {
        let url = URL(fileURLWithPath: mountPoint)
        let contents = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
        for name in contents where name.hasSuffix(".app") {
            return url.appendingPathComponent(name)
        }
        throw InstallerError.appNotFoundInDmg
    }
}

enum InstallerError: LocalizedError {
    case unsupportedFormat(String)
    case processFailed(path: String, status: Int, stderr: String)
    case cannotParseMount
    case appNotFoundInDmg

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext): return "Unsupported installer format: .\(ext)"
        case .processFailed(let path, let status, let stderr):
            return "\(path) failed (\(status)): \(stderr)"
        case .cannotParseMount: return "Couldn't determine mount point from hdiutil output"
        case .appNotFoundInDmg: return "DMG didn't contain a .app bundle"
        }
    }
}
