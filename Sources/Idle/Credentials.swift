import Foundation
import Combine

/// Local credential vault for the onboarding flow.
///
/// MVP: backed by UserDefaults so it survives relaunch and so the JS prefill
/// script can pull values via WKWebView. Production should migrate to the
/// macOS Keychain so the data is encrypted at rest and isolated per-app.
@MainActor
final class Vault: ObservableObject {
    @Published var email: String
    @Published private(set) var passwords: [String: String]
    @Published var completed: Set<String>

    private let store = UserDefaults.standard
    private let emailKey = "idle.vault.email"
    private let passwordsKey = "idle.vault.passwords"
    private let completedKey = "idle.vault.completed"

    init() {
        email = UserDefaults.standard.string(forKey: emailKey) ?? ""
        passwords = (UserDefaults.standard.dictionary(forKey: passwordsKey) as? [String: String]) ?? [:]
        completed = Set(UserDefaults.standard.stringArray(forKey: completedKey) ?? [])
    }

    func setEmail(_ value: String) {
        email = value
        store.set(value, forKey: emailKey)
    }

    /// Returns the password for an app, generating + persisting a fresh one if absent.
    func password(for appId: String) -> String {
        if let existing = passwords[appId] { return existing }
        let generated = Self.generatePassword()
        passwords[appId] = generated
        persistPasswords()
        return generated
    }

    func setCompleted(_ appId: String, _ value: Bool) {
        if value { completed.insert(appId) } else { completed.remove(appId) }
        store.set(Array(completed), forKey: completedKey)
    }

    func isCompleted(_ appId: String) -> Bool { completed.contains(appId) }

    private func persistPasswords() {
        store.set(passwords, forKey: passwordsKey)
    }

    /// 20 chars, mixed case + digits + a special char for services that require it.
    static func generatePassword() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        let core = (0..<19).map { _ in alphabet.randomElement()! }
        return String(core) + "!"
    }
}
