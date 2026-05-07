import AppKit
import Combine
import Foundation

/// Polls the macOS pasteboard for things that look like verification codes
/// or magic links, and surfaces them so the onboarding flow can offer to
/// auto-fill the embedded webview.
///
/// macOS Continuity routes iPhone SMS codes into the keyboard QuickType bar
/// for Apple-native fields, but not into WKWebViews. The next-best UX is to
/// notice when the user copies a code from Messages / Mail / a notification,
/// and offer one-click insert into whichever onboarding step is active.
@MainActor
final class Clipboard: ObservableObject {
    @Published private(set) var detectedOTP: String?
    @Published private(set) var detectedLink: URL?

    private var changeCount: Int
    private var timer: Timer?
    private var dismissedSnapshots: Set<String> = []

    init() {
        self.changeCount = NSPasteboard.general.changeCount
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func dismiss() {
        if let otp = detectedOTP { dismissedSnapshots.insert("otp:\(otp)") }
        if let link = detectedLink { dismissedSnapshots.insert("link:\(link.absoluteString)") }
        detectedOTP = nil
        detectedLink = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != changeCount else { return }
        changeCount = pb.changeCount

        guard let raw = pb.string(forType: .string) else {
            detectedOTP = nil
            detectedLink = nil
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let otp = extractOTP(from: trimmed), !dismissedSnapshots.contains("otp:\(otp)") {
            detectedOTP = otp
        } else {
            detectedOTP = nil
        }

        if let link = extractVerificationURL(from: trimmed),
           !dismissedSnapshots.contains("link:\(link.absoluteString)") {
            detectedLink = link
        } else {
            detectedLink = nil
        }
    }

    /// Heuristic: a bare 4-8 digit number, or "Your code is 123456" style.
    /// Avoid false positives like 8-digit account numbers by requiring the
    /// digits to be either the entire string, or follow a "code"/"verify"
    /// keyword within the same line.
    private func extractOTP(from text: String) -> String? {
        // Whole-string OTP (most common when copying from Messages).
        let bareDigits = #"^\d{4,8}$"#
        if text.range(of: bareDigits, options: .regularExpression) != nil {
            return text
        }

        // Pattern with surrounding context. Only consider strings short enough
        // that the user almost certainly copied them on purpose for an OTP.
        guard text.count <= 200 else { return nil }
        let patterns = [
            #"(?:code|otp|verification|verify)[^\d]{0,12}(\d{4,8})"#,
            #"(\d{4,8})[^\d]{0,12}(?:code|otp|verification)"#
        ]
        for p in patterns {
            if let range = text.range(of: p, options: [.regularExpression, .caseInsensitive]) {
                let match = String(text[range])
                if let digitsRange = match.range(of: #"\d{4,8}"#, options: .regularExpression) {
                    return String(match[digitsRange])
                }
            }
        }
        return nil
    }

    /// Detects URLs that look like verification / confirmation links from a
    /// known DePIN sender. We're conservative — only HTTPS URLs from domains
    /// the registry knows about, with verification-ish path components.
    private func extractVerificationURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let knownHosts = [
            "pawns.app", "grass.io", "honeygain.com", "earnapp.com",
            "mystnodes.com", "mysterium.network", "nodepay.ai"
        ]
        let hints = ["verify", "confirm", "activate", "validation", "auth"]

        var best: URL?
        detector?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let url = match?.url, url.scheme == "https" else { return }
            guard let host = url.host?.lowercased() else { return }
            guard knownHosts.contains(where: { host.contains($0) }) else { return }
            let path = url.path.lowercased()
            guard hints.contains(where: { path.contains($0) }) else { return }
            best = url
        }
        return best
    }
}
