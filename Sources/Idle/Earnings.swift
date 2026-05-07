import Foundation
import Combine

/// Per-app earnings scraping. Runs JS in the cached dashboard WKWebViews
/// (`dashboard.<appId>` cache keys) to extract the current balance, then
/// publishes a unified view.
///
/// No app exposes a clean public API for earnings, so we DOM-scrape with
/// best-effort selectors. Each extractor returns
/// `{ amount: Number | null, currency: String }`. `null` amount means we
/// couldn't find anything; the UI shows `—` for that app.
@MainActor
final class Earnings: ObservableObject {

    struct Reading {
        let amount: Double?
        let currency: String   // "USD", "GRASS", "MYST", "NODE", etc.
        let asOf: Date
    }

    @Published private(set) var readings: [String: Reading] = [:]
    private var timer: Timer?
    /// Optional history sink. When set, every refreshAll() snapshot also
    /// gets recorded for the trend chart.
    weak var history: EarningsHistory?

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
        Task { await refreshAll() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refreshAll() async {
        for app in AppRegistry.all {
            await refresh(app)
        }
        history?.record(readings)
    }

    func refresh(_ app: DePinApp) async {
        guard let extractor = Self.extractors[app.id] else { return }
        let key = "dashboard.\(app.id)"
        let result = await runJS(extractor, on: key)
        if let dict = result as? [String: Any] {
            let amount = dict["amount"] as? Double
            let currency = (dict["currency"] as? String) ?? defaultCurrency(for: app)
            readings[app.id] = Reading(amount: amount, currency: currency, asOf: Date())
        } else {
            readings[app.id] = Reading(amount: nil, currency: defaultCurrency(for: app), asOf: Date())
        }
    }

    private func runJS(_ js: String, on key: String) async -> Any? {
        await withCheckedContinuation { (cont: CheckedContinuation<Any?, Never>) in
            WebViewCache.shared.runJS(js, on: key) { result in
                cont.resume(returning: result)
            }
        }
    }

    private func defaultCurrency(for app: DePinApp) -> String {
        switch app.payoutKind {
        case .usd: return "USD"
        case .token(let symbol): return symbol
        }
    }

    /// Total in USD-equivalent. Token-paid services use a hardcoded approximate
    /// price (refresh manually for accuracy). Cash-paid services contribute
    /// their amount directly. Apps with no reading contribute zero.
    var totalUSD: Double {
        var sum = 0.0
        for (_, reading) in readings {
            guard let amount = reading.amount else { continue }
            switch reading.currency {
            case "USD": sum += amount
            case "GRASS": sum += amount * Self.tokenPriceUSD["GRASS", default: 0]
            case "MYST": sum += amount * Self.tokenPriceUSD["MYST", default: 0]
            case "NODE": sum += amount * Self.tokenPriceUSD["NODE", default: 0]
            default: break
            }
        }
        return sum
    }

    /// Best-effort token prices. v0.6 will fetch these from CoinGecko on launch.
    static var tokenPriceUSD: [String: Double] = [
        "GRASS": 0.20,
        "MYST": 0.05,
        "NODE": 0.0    // pre-TGE, no liquid market
    ]

    // MARK: - Per-app JS extractors

    /// Each extractor returns `{ amount: Number, currency: "USD" | "GRASS" | ... }`
    /// or `null` if nothing matched. Selectors are best-effort and may need
    /// refinement after testing each dashboard's current DOM.
    static let extractors: [String: String] = [
        "pawns": commonExtractor(currency: "USD", numericPrefixes: ["$"]),
        "grass": commonExtractor(currency: "GRASS", numericSuffixes: ["points", "GRASS", "PTS"]),
        "honeygain": commonExtractor(currency: "USD", numericPrefixes: ["$"]),
        "earnapp": commonExtractor(currency: "USD", numericPrefixes: ["$"]),
        "mystnodes": commonExtractor(currency: "MYST", numericSuffixes: ["MYST", "myst"]),
        "nodepay": commonExtractor(currency: "NODE", numericSuffixes: ["NODE", "Points"])
    ]

    /// Generic extractor: scans the document body for the largest numeric value
    /// near a balance-like keyword (balance, earnings, total, points, claim,
    /// rewards). Returns the first plausible match. Falls back to scanning for
    /// $-prefixed numbers anywhere visible.
    private static func commonExtractor(
        currency: String,
        numericPrefixes: [String] = [],
        numericSuffixes: [String] = []
    ) -> String {
        let prefixesJS = numericPrefixes.map { "\"\($0)\"" }.joined(separator: ", ")
        let suffixesJS = numericSuffixes.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        (function () {
          const PREFIXES = [\(prefixesJS)];
          const SUFFIXES = [\(suffixesJS)];
          const KEYWORDS = ['balance','earnings','total','points','claim','rewards','earned','available','wallet'];

          function parseNum(s) {
            if (!s) return null;
            const cleaned = String(s).replace(/[^0-9.,-]/g, '').replace(/,/g, '');
            const v = parseFloat(cleaned);
            return Number.isFinite(v) ? v : null;
          }

          // Strategy 1: prefix-based (e.g. "$12.34")
          for (const prefix of PREFIXES) {
            const re = new RegExp('\\\\' + prefix + '\\\\s*([0-9][0-9,]*\\\\.[0-9]{1,4}|[0-9][0-9,]*)', 'g');
            const matches = (document.body.innerText || '').match(re) || [];
            for (const m of matches) {
              const n = parseNum(m);
              if (n != null && n > 0 && n < 1e7) return { amount: n, currency: '\(currency)' };
            }
          }

          // Strategy 2: suffix-based (e.g. "1234 points")
          for (const suffix of SUFFIXES) {
            const re = new RegExp('([0-9][0-9,]*\\\\.[0-9]{1,4}|[0-9][0-9,]*)\\\\s*' + suffix, 'gi');
            const matches = (document.body.innerText || '').match(re) || [];
            for (const m of matches) {
              const n = parseNum(m);
              if (n != null) return { amount: n, currency: '\(currency)' };
            }
          }

          // Strategy 3: numbers near keywords
          const all = document.querySelectorAll('span,div,p,strong,td,h1,h2,h3,h4');
          for (const el of all) {
            const text = (el.textContent || '').trim();
            if (text.length > 200) continue;
            const lower = text.toLowerCase();
            if (KEYWORDS.some(k => lower.includes(k))) {
              const n = parseNum(text);
              if (n != null && n > 0 && n < 1e7) return { amount: n, currency: '\(currency)' };
              // Look in next sibling
              const sib = el.nextElementSibling;
              if (sib) {
                const sn = parseNum(sib.textContent || '');
                if (sn != null && sn > 0 && sn < 1e7) return { amount: sn, currency: '\(currency)' };
              }
            }
          }

          return null;
        })();
        """
    }
}
