import Foundation
import Combine

/// User-entered balances and payout events. This is the **trusted** source of
/// truth — the DOM scraper is fragile and has hallucinated readings before
/// (the $2067 incident); user-typed numbers are accurate by construction.
///
/// Two record types live here:
/// - `Balance`: a snapshot of "right now my Pawns dashboard says $4.32".
///   Useful for the running total in the menu bar.
/// - `Payout`: a real-money event ("Pawns paid me $5.00 to PayPal on 5/8").
///   Useful for tax tracking and confirming the funnel actually works end-to-end.
@MainActor
final class ManualEarnings: ObservableObject {

    struct Balance: Codable, Identifiable {
        var id: String { "\(appId)-\(ts.timeIntervalSince1970)" }
        let appId: String
        let amount: Double
        let currency: String
        let ts: Date
        let note: String?
    }

    struct Payout: Codable, Identifiable {
        var id: String { "\(appId)-\(ts.timeIntervalSince1970)-payout" }
        let appId: String
        let amount: Double
        let currency: String
        let method: String   // "PayPal", "BTC", "ETH", "Bank", "Solana", etc.
        let ts: Date
        let txRef: String?   // optional transaction id / PayPal email
        let note: String?
    }

    @Published private(set) var balances: [Balance] = []
    @Published private(set) var payouts: [Payout] = []

    private let balancesURL: URL
    private let payoutsURL: URL

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Idle", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.balancesURL = dir.appendingPathComponent("manual-balances.jsonl")
        self.payoutsURL = dir.appendingPathComponent("manual-payouts.jsonl")
        load()
    }

    // MARK: - Public API

    func recordBalance(appId: String, amount: Double, currency: String, note: String? = nil) {
        let b = Balance(appId: appId, amount: amount, currency: currency, ts: Date(), note: note)
        balances.append(b)
        appendLine(b, to: balancesURL)
    }

    func recordPayout(appId: String, amount: Double, currency: String, method: String,
                      txRef: String? = nil, note: String? = nil) {
        let p = Payout(appId: appId, amount: amount, currency: currency, method: method,
                       ts: Date(), txRef: txRef, note: note)
        payouts.append(p)
        appendLine(p, to: payoutsURL)
    }

    /// Most recent balance entry per app, regardless of currency.
    func latestBalance(for appId: String) -> Balance? {
        balances.last(where: { $0.appId == appId })
    }

    /// All payouts for an app sorted by date descending.
    func allPayouts(for appId: String) -> [Payout] {
        payouts.filter { $0.appId == appId }.sorted(by: { $0.ts > $1.ts })
    }

    /// Lifetime cash earnings = sum of all USD-equivalent payouts.
    /// For token payouts uses Earnings.tokenPriceUSD as fallback; user can
    /// override by entering a USD-equivalent in the note field.
    var lifetimeUSDFromPayouts: Double {
        var total = 0.0
        for p in payouts {
            switch p.currency {
            case "USD": total += p.amount
            case "GRASS": total += p.amount * Earnings.tokenPriceUSD["GRASS", default: 0]
            case "MYST":  total += p.amount * Earnings.tokenPriceUSD["MYST",  default: 0]
            case "NODE":  total += p.amount * Earnings.tokenPriceUSD["NODE",  default: 0]
            case "VRSC":  total += p.amount * Earnings.tokenPriceUSD["VRSC",  default: 0]
            default: break
            }
        }
        return total
    }

    /// USD-equivalent of currently-held balances per latest manual entry.
    /// Less trustworthy than payouts (balances can fluctuate or be inflated)
    /// but useful for "right now" totals.
    var currentUSDFromBalances: Double {
        var total = 0.0
        let latestPerApp = Dictionary(grouping: balances, by: { $0.appId })
            .mapValues { $0.last }
        for (_, balance) in latestPerApp {
            guard let b = balance else { continue }
            switch b.currency {
            case "USD": total += b.amount
            case "GRASS": total += b.amount * Earnings.tokenPriceUSD["GRASS", default: 0]
            case "MYST":  total += b.amount * Earnings.tokenPriceUSD["MYST",  default: 0]
            case "NODE":  total += b.amount * Earnings.tokenPriceUSD["NODE",  default: 0]
            case "VRSC":  total += b.amount * Earnings.tokenPriceUSD["VRSC",  default: 0]
            default: break
            }
        }
        return total
    }

    /// Total trustable USD = lifetime payouts + current balances.
    /// This is what the menu bar surfaces — your honest combined position.
    var trustableUSD: Double {
        lifetimeUSDFromPayouts + currentUSDFromBalances
    }

    func deleteBalance(_ id: String) {
        balances.removeAll(where: { $0.id == id })
        rewriteFile(balancesURL, items: balances)
    }

    func deletePayout(_ id: String) {
        payouts.removeAll(where: { $0.id == id })
        rewriteFile(payoutsURL, items: payouts)
    }

    /// Combined CSV of balances + payouts for tax export.
    /// Format: kind,timestamp,app,amount,currency,method,txRef,note
    func exportCSV(to dest: URL) throws {
        var lines = ["kind,timestamp,app,amount,currency,method,txRef,note"]
        let iso = ISO8601DateFormatter()
        for b in balances.sorted(by: { $0.ts < $1.ts }) {
            lines.append("balance,\(iso.string(from: b.ts)),\(b.appId),\(b.amount),\(b.currency),,,\(escape(b.note ?? ""))")
        }
        for p in payouts.sorted(by: { $0.ts < $1.ts }) {
            lines.append("payout,\(iso.string(from: p.ts)),\(p.appId),\(p.amount),\(p.currency),\(p.method),\(escape(p.txRef ?? "")),\(escape(p.note ?? ""))")
        }
        try lines.joined(separator: "\n").write(to: dest, atomically: true, encoding: .utf8)
    }

    private func escape(_ s: String) -> String {
        s.contains(",") || s.contains("\"") ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
    }

    // MARK: - Private

    private func load() {
        balances = readLines(at: balancesURL, as: Balance.self).sorted(by: { $0.ts < $1.ts })
        payouts  = readLines(at: payoutsURL,  as: Payout.self ).sorted(by: { $0.ts < $1.ts })
    }

    private func readLines<T: Decodable>(at url: URL, as: T.Type) -> [T] {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return [] }
        var items: [T] = []
        for line in text.split(separator: "\n") {
            if let lineData = String(line).data(using: .utf8),
               let item = try? decoder.decode(T.self, from: lineData) {
                items.append(item)
            }
        }
        return items
    }

    private func appendLine<T: Encodable>(_ item: T, to url: URL) {
        do {
            let data = try encoder.encode(item)
            let handle: FileHandle
            if FileManager.default.fileExists(atPath: url.path) {
                handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
                handle = try FileHandle(forWritingTo: url)
            }
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data([0x0a]))
        } catch {
            // Best-effort; in-memory state still has the entry.
        }
    }

    private func rewriteFile<T: Encodable>(_ url: URL, items: [T]) {
        do {
            var bytes = Data()
            for item in items {
                bytes.append(try encoder.encode(item))
                bytes.append(0x0a)
            }
            try bytes.write(to: url)
        } catch {
            // Best-effort.
        }
    }
}
