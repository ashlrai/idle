import Foundation
import Combine

/// Fetches live USD prices for the DePIN tokens we track (GRASS, MYST, NODE).
/// Hits CoinGecko's free public API every 6h. Falls back to last cached value
/// when the network is down. Cached values feed `Earnings.tokenPriceUSD` so
/// the totalUSD calculation stays current.
@MainActor
final class PriceFetcher: ObservableObject {

    @Published private(set) var prices: [String: Double] = [
        "GRASS": 0.20, // fallback defaults; replaced after first fetch
        "MYST": 0.05,
        "NODE": 0.0
    ]
    @Published private(set) var lastFetched: Date?

    private let cacheKey = "idle.priceFetcher.cache"
    private let fetchedAtKey = "idle.priceFetcher.fetchedAt"
    private var timer: Timer?

    /// CoinGecko coin IDs for each token. NODE pre-TGE has no listing — we
    /// keep its price at 0 until it lands on an exchange.
    private let coinIDs: [String: String] = [
        "GRASS": "grass-2",
        "MYST": "mysterium"
    ]

    init() {
        loadCachedAndApply()
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        let ids = coinIDs.values.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd") else {
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else { return }

            var next = prices
            for (symbol, coinID) in coinIDs {
                if let usd = payload[coinID]?["usd"] {
                    next[symbol] = usd
                }
            }
            self.prices = next
            self.lastFetched = Date()

            // Mirror to Earnings static so totalUSD picks up the new prices.
            Earnings.tokenPriceUSD = next

            // Persist.
            if let json = try? JSONEncoder().encode(next) {
                UserDefaults.standard.set(json, forKey: cacheKey)
                UserDefaults.standard.set(Date(), forKey: fetchedAtKey)
            }
        } catch {
            // Silent — keep using cached/fallback prices.
        }
    }

    private func loadCachedAndApply() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.prices = cached
            Earnings.tokenPriceUSD = cached
        }
        self.lastFetched = UserDefaults.standard.object(forKey: fetchedAtKey) as? Date
    }
}
