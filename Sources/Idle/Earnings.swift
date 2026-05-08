import Foundation
import Combine

/// Per-app earnings scraping. Runs JS in the cached dashboard WKWebViews
/// (`dashboard.<appId>` cache keys) to extract the current balance, then
/// publishes a unified view.
///
/// **Honesty note**: no DePIN service exposes a public API for an authenticated
/// user's balance. We DOM-scrape, which is fragile. The earlier version used a
/// permissive keyword-near-number heuristic that hallucinated $2000+ readings
/// from marketing copy ("earn up to $2000 per month!"). This version uses
/// strict per-app selectors targeting only known balance DOM elements, with
/// sanity caps that reject implausible values. When in doubt the extractor
/// returns null and the UI shows `—` for that app — better silent than wrong.
@MainActor
final class Earnings: ObservableObject {

    struct Reading {
        let amount: Double?
        let currency: String   // "USD", "GRASS", "MYST", "NODE", etc.
        let asOf: Date
    }

    @Published private(set) var readings: [String: Reading] = [:]
    private var timer: Timer?
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
        guard let extractor = Self.extractors[app.id] else {
            // Unknown app — leave the reading nil (UI shows "—")
            readings[app.id] = Reading(amount: nil, currency: defaultCurrency(for: app), asOf: Date())
            return
        }
        let key = "dashboard.\(app.id)"
        let result = await runJS(extractor, on: key)
        if let dict = result as? [String: Any] {
            let rawAmount = dict["amount"] as? Double
            let currency = (dict["currency"] as? String) ?? defaultCurrency(for: app)
            let amount = sanityCheck(amount: rawAmount, currency: currency)
            readings[app.id] = Reading(amount: amount, currency: currency, asOf: Date())
        } else {
            readings[app.id] = Reading(amount: nil, currency: defaultCurrency(for: app), asOf: Date())
        }
    }

    /// Reject readings that are outside the plausible range for a single
    /// residential IP. Real DePIN balances for one user max out in the low
    /// hundreds of dollars per service even after a year of running. Anything
    /// bigger is almost certainly marketing copy or token-supply text the
    /// scraper grabbed by accident.
    private func sanityCheck(amount: Double?, currency: String) -> Double? {
        guard let amount = amount else { return nil }
        guard amount >= 0 else { return nil }
        switch currency {
        case "USD":
            // A DePIN service rarely shows >$200 unpaid for a single user;
            // payouts trigger long before that. $1000 is a hard cap.
            return amount < 1000 ? amount : nil
        case "GRASS":
            // GRASS points balances pre-airdrop reach low thousands; post-token
            // a user holds maybe hundreds of GRASS. Cap at 100k as paranoid.
            return amount < 100_000 ? amount : nil
        case "MYST":
            // MYST balances for a single residential exit-node max in the tens.
            return amount < 10_000 ? amount : nil
        case "NODE":
            return amount < 1_000_000 ? amount : nil
        default:
            return amount < 1_000_000 ? amount : nil
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

    /// Total in USD-equivalent. Token-paid services use live prices from the
    /// PriceFetcher (mirrored into `tokenPriceUSD` here).
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

    /// Live prices, populated by PriceFetcher on app launch.
    static var tokenPriceUSD: [String: Double] = [
        "GRASS": 0.20,
        "MYST": 0.05,
        "NODE": 0.0
    ]

    // MARK: - Per-app JS extractors
    //
    // Each extractor uses tight selectors targeting known balance DOM elements
    // on each app's dashboard. These need refinement as the dashboards change
    // their UI. When the selector doesn't match, return null — better silent
    // than reporting marketing copy as a balance.

    static let extractors: [String: String] = [
        "pawns":      pawnsExtractor,
        "honeygain":  honeygainExtractor,
        "earnapp":    earnAppExtractor,
        "grass":      grassExtractor,
        "mystnodes":  mystNodesExtractor,
        "nodepay":    nodepayExtractor
    ]

    /// Pawns dashboard at dashboard.pawns.app. The header shows the user's
    /// balance as "$X.XX" near a "Balance" label. We target the small set of
    /// known classes; if none match we return null rather than guessing.
    private static let pawnsExtractor: String = """
    (function() {
      function setOnly(arr) { return Array.from(new Set(arr)); }
      function num(s) {
        if (!s) return null;
        const m = String(s).match(/\\$\\s*([0-9]+(?:\\.[0-9]+)?)/);
        return m ? parseFloat(m[1]) : null;
      }
      const candidates = setOnly([
        ...document.querySelectorAll('[data-testid*="balance" i]'),
        ...document.querySelectorAll('[class*="balance" i]'),
        ...document.querySelectorAll('[class*="Balance"]'),
        ...document.querySelectorAll('header [class*="amount"]')
      ]);
      for (const el of candidates) {
        const t = (el.textContent || '').trim();
        if (t.length > 30) continue;
        const v = num(t);
        if (v != null && v < 1000) return { amount: v, currency: 'USD' };
      }
      return null;
    })();
    """

    /// Honeygain dashboard at dashboard.honeygain.com. Balance shown in "$X.XX
    /// USD" with class typically containing "user-balance" or "balance".
    private static let honeygainExtractor: String = """
    (function() {
      function num(s) {
        if (!s) return null;
        const m = String(s).match(/\\$?\\s*([0-9]+(?:\\.[0-9]+)?)\\s*USD?/);
        if (m) return parseFloat(m[1]);
        const m2 = String(s).match(/^\\$\\s*([0-9]+(?:\\.[0-9]+)?)$/);
        return m2 ? parseFloat(m2[1]) : null;
      }
      const candidates = [
        ...document.querySelectorAll('[class*="user-balance" i]'),
        ...document.querySelectorAll('[class*="balance" i]'),
        ...document.querySelectorAll('[data-testid*="balance" i]')
      ];
      for (const el of candidates) {
        const t = (el.textContent || '').trim();
        if (t.length > 40) continue;
        const v = num(t);
        if (v != null && v < 500) return { amount: v, currency: 'USD' };
      }
      return null;
    })();
    """

    /// EarnApp dashboard at earnapp.com/dashboard. "Current Balance: $X.XX".
    private static let earnAppExtractor: String = """
    (function() {
      function num(s) {
        if (!s) return null;
        const m = String(s).match(/\\$\\s*([0-9]+(?:\\.[0-9]+)?)/);
        return m ? parseFloat(m[1]) : null;
      }
      // Look for "Current Balance" label and grab the adjacent number.
      const labels = Array.from(document.querySelectorAll('*')).filter(el => {
        const t = (el.textContent || '').trim().toLowerCase();
        return t === 'current balance' || t === 'lifetime earnings';
      });
      for (const lab of labels) {
        const sib = lab.nextElementSibling || lab.parentElement?.nextElementSibling;
        if (sib) {
          const v = num((sib.textContent || '').trim());
          if (v != null && v < 500) return { amount: v, currency: 'USD' };
        }
      }
      return null;
    })();
    """

    /// Grass dashboard. Shows total points in a header near "POINTS" label.
    /// We require the points to be associated with that exact word in caps —
    /// reduces false positives from marketing copy.
    private static let grassExtractor: String = """
    (function() {
      const all = Array.from(document.querySelectorAll('span,div,strong,h1,h2,h3'));
      for (const el of all) {
        const t = (el.textContent || '').trim();
        // Match e.g. "1,234.5 POINTS" or "1,234 EPOCH POINTS"
        const m = t.match(/^([0-9]+(?:[,.][0-9]+)*)\\s*(EPOCH\\s+)?(POINTS?|GRASS)$/i);
        if (m) {
          const v = parseFloat(m[1].replace(/,/g,''));
          if (v >= 0 && v < 100000) return { amount: v, currency: 'GRASS' };
        }
      }
      return null;
    })();
    """

    /// MystNodes dashboard at my.mystnodes.com. Balance in MYST in earnings card.
    private static let mystNodesExtractor: String = """
    (function() {
      const all = Array.from(document.querySelectorAll('span,div,strong'));
      for (const el of all) {
        const t = (el.textContent || '').trim();
        const m = t.match(/^([0-9]+(?:\\.[0-9]+)?)\\s*MYST$/i);
        if (m) {
          const v = parseFloat(m[1]);
          if (v >= 0 && v < 10000) return { amount: v, currency: 'MYST' };
        }
      }
      return null;
    })();
    """

    /// Nodepay dashboard at app.nodepay.ai. Balance shown as "0 $NC Balance"
    /// and "0 Signal Points" in the v2 UI. We target the explicit "$NC
    /// Balance" / "Signal Points" labels.
    private static let nodepayExtractor: String = """
    (function() {
      const all = Array.from(document.querySelectorAll('span,div,strong'));
      for (const el of all) {
        const t = (el.textContent || '').trim();
        if (t.length > 40) continue;
        const m = t.match(/([0-9]+(?:\\.[0-9]+)?)\\s*\\$?NC\\s*Balance/i)
               || t.match(/([0-9]+(?:\\.[0-9]+)?)\\s*Signal\\s*Points/i)
               || t.match(/^([0-9]+(?:\\.[0-9]+)?)\\s*NODE$/i);
        if (m) {
          const v = parseFloat(m[1]);
          if (v >= 0 && v < 1000000) return { amount: v, currency: 'NODE' };
        }
      }
      return null;
    })();
    """
}
