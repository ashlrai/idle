import Foundation
import Combine

/// Fetches `https://idle.ashlr.ai/config.json` on launch so the operator
/// can update referral codes (and surface in-app announcements) without
/// shipping a new app build.
///
/// Falls back to the compile-time defaults in `AppRegistry.referrals` if the
/// fetch fails or any code is null. Cached on disk for 1h so subsequent
/// launches don't block on network.
@MainActor
final class RemoteConfig: ObservableObject {
    struct Payload: Decodable {
        struct Referrals: Decodable {
            let pawns: String?
            let grass: String?
            let honeygain: String?
            let earnApp: String?
            let mystNodes: String?
            let nodepay: String?
            let repocket: String?
        }
        let version: String?
        let minClientVersion: String?
        let downloadURL: String?
        let referrals: Referrals
        let announcements: [String]?
    }

    @Published private(set) var lastFetched: Date?
    @Published private(set) var announcements: [String] = []

    static let endpoint = URL(string: "https://idle.ashlr.ai/config.json")!
    private let cacheKey = "idle.remoteConfig.cache"
    private let fetchedAtKey = "idle.remoteConfig.fetchedAt"

    init() {
        loadCachedAndApply()
    }

    func refresh() async {
        do {
            var request = URLRequest(url: Self.endpoint)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            apply(payload)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: fetchedAtKey)
            self.lastFetched = Date()
        } catch {
            // Silent failure — degraded mode falls back to compile-time codes.
        }
    }

    private func loadCachedAndApply() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }
        apply(payload)
        self.lastFetched = UserDefaults.standard.object(forKey: fetchedAtKey) as? Date
    }

    private func apply(_ payload: Payload) {
        AppRegistry.referrals = AppRegistry.ReferralCodes(
            pawns: payload.referrals.pawns ?? AppRegistry.referrals.pawns,
            grass: payload.referrals.grass ?? AppRegistry.referrals.grass,
            honeygain: payload.referrals.honeygain ?? AppRegistry.referrals.honeygain,
            earnApp: payload.referrals.earnApp ?? AppRegistry.referrals.earnApp,
            mystNodes: payload.referrals.mystNodes ?? AppRegistry.referrals.mystNodes,
            nodepay: payload.referrals.nodepay ?? AppRegistry.referrals.nodepay,
            repocket: payload.referrals.repocket ?? AppRegistry.referrals.repocket
        )
        if let list = payload.announcements {
            self.announcements = list
        }
    }
}
