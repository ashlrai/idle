import Foundation
import Combine

/// Persists earnings readings over time so the dashboard can show trends.
///
/// Storage: a JSON-lines file at
/// `~/Library/Application Support/Idle/earnings.jsonl`
/// One line per reading. Cheap to append, easy to parse, easy to inspect with
/// `cat`. Schema:
/// ```
/// {"appId":"pawns","ts":"2026-05-07T12:34:56Z","amount":1.23,"currency":"USD"}
/// ```
@MainActor
final class EarningsHistory: ObservableObject {

    struct Entry: Codable, Identifiable {
        var id: String { "\(appId)-\(ts.timeIntervalSince1970)" }
        let appId: String
        let ts: Date
        let amount: Double
        let currency: String
    }

    @Published private(set) var entries: [Entry] = []

    private let url: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Idle", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("earnings.jsonl")
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init() {
        load()
    }

    /// Record a snapshot of all current readings. Only appends entries whose
    /// amount changed vs the most recent prior reading (so we don't bloat the
    /// log when nothing's moving).
    func record(_ readings: [String: Earnings.Reading]) {
        let now = Date()
        var newEntries: [Entry] = []
        for (appId, reading) in readings {
            guard let amount = reading.amount else { continue }
            let prev = mostRecent(for: appId)
            if prev == nil || prev!.amount != amount {
                newEntries.append(Entry(
                    appId: appId,
                    ts: now,
                    amount: amount,
                    currency: reading.currency
                ))
            }
        }
        guard !newEntries.isEmpty else { return }
        entries.append(contentsOf: newEntries)
        appendToDisk(newEntries)
    }

    /// Most recent entry per appId.
    func mostRecent(for appId: String) -> Entry? {
        entries.last(where: { $0.appId == appId })
    }

    /// Entries within the last `days` days. For chart views.
    func entries(within days: Int) -> [Entry] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return entries.filter { $0.ts >= cutoff }
    }

    /// CSV export for tax/accounting. Headers: timestamp, app, amount, currency.
    /// Token entries are tagged with their symbol so the user can compute USD
    /// cost basis using historical prices later.
    func exportCSV(to dest: URL) throws {
        var lines = ["timestamp,app,amount,currency"]
        for entry in entries.sorted(by: { $0.ts < $1.ts }) {
            let ts = isoFormatter.string(from: entry.ts)
            lines.append("\(ts),\(entry.appId),\(entry.amount),\(entry.currency)")
        }
        try lines.joined(separator: "\n").write(to: dest, atomically: true, encoding: .utf8)
    }

    func clear() {
        entries = []
        try? FileManager.default.removeItem(at: url)
    }

    var fileURL: URL { url }

    // MARK: - Private

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        var loaded: [Entry] = []
        for line in text.split(separator: "\n") {
            guard let lineData = String(line).data(using: .utf8),
                  let entry = try? jsonDecoder.decode(Entry.self, from: lineData) else { continue }
            loaded.append(entry)
        }
        entries = loaded.sorted { $0.ts < $1.ts }
    }

    private func appendToDisk(_ newEntries: [Entry]) {
        do {
            let handle: FileHandle
            if FileManager.default.fileExists(atPath: url.path) {
                handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
                handle = try FileHandle(forWritingTo: url)
            }
            defer { try? handle.close() }

            for entry in newEntries {
                let data = try jsonEncoder.encode(entry)
                try handle.write(contentsOf: data)
                try handle.write(contentsOf: Data([0x0a]))
            }
        } catch {
            // Best-effort persistence; in-memory state still has the entries.
        }
    }

    private lazy var jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private lazy var jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
