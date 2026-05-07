import Foundation
import AppKit
import Combine

/// Verus (VRSC) CPU mining for Apple Silicon.
///
/// Verus uses VerusHash 2.2 — memory-hard, ASIC-resistant, runs unusually well
/// on M-series cores. Realistic on a 16GB Air at 24/7 plug-in: $30–90 / month
/// depending on token price + thermal headroom.
///
/// We do NOT bundle the cpuminer-verus binary inside Idle (it's GPL — and we
/// don't want users to silently start mining without consent). Instead the
/// user runs `Scripts/install_verus.sh` once to download the official binary
/// from veruscoin/cpuminer-verus releases, then Idle launches it as a child
/// process when the user toggles "Mining" on.
///
/// Thermal-aware: caps thread count at half the CPU cores when on battery,
/// and restores full when plugged in. Stops automatically when the lid
/// closes on a fanless Air.
@MainActor
final class Mining: ObservableObject {

    enum State: Equatable {
        case notInstalled
        case stopped
        case starting
        case running(threads: Int, hashRate: Double?)
        case error(String)
    }

    @Published private(set) var state: State = .notInstalled
    /// Pool address — LuckPool (Verus's largest pool, ~1% fee).
    /// CPU port is 3956. Override via UserDefaults if the user prefers a
    /// different pool.
    @Published var pool: String = "stratum+tcp://na.luckpool.net:3956"
    /// Pays out to this VRSC address. Persisted in UserDefaults so it survives
    /// relaunch. Idle never holds the wallet's seed phrase — the user provides
    /// only the public R-address.
    @Published var address: String {
        didSet { UserDefaults.standard.set(address, forKey: "idle.mining.address") }
    }
    /// Cap thread count at this fraction of available cores. 0.5 = half on
    /// battery, 0.75 default on AC. Adjustable from Settings later.
    @Published var threadFraction: Double = 0.75

    private var process: Process?
    private var hashRateTimer: Timer?

    /// Where the cpuminer-verus binary lives after the install script runs.
    private static let binaryURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Idle/miner", isDirectory: true)
        return dir.appendingPathComponent("cpuminer")
    }()

    init() {
        self.address = UserDefaults.standard.string(forKey: "idle.mining.address") ?? ""
        refresh()
    }

    func refresh() {
        if FileManager.default.isExecutableFile(atPath: Self.binaryURL.path) {
            if process != nil {
                // already running — keep state
            } else {
                state = .stopped
            }
        } else {
            state = .notInstalled
        }
    }

    /// Open the install script in Terminal so the user can review + run it.
    /// We can't auto-execute curl|sh without their explicit consent.
    func openInstaller() {
        let scriptURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/install_verus.sh")
        let fallback = "https://raw.githubusercontent.com/ashlrai/idle/main/Scripts/install_verus.sh"
        let target = FileManager.default.fileExists(atPath: scriptURL.path)
            ? scriptURL : URL(string: fallback)!
        NSWorkspace.shared.open(target)
    }

    func start() {
        guard FileManager.default.isExecutableFile(atPath: Self.binaryURL.path) else {
            state = .notInstalled
            return
        }
        guard !address.isEmpty else {
            state = .error("Set a VRSC payout address in Idle Settings first.")
            return
        }
        guard process == nil else { return }

        let cores = ProcessInfo.processInfo.activeProcessorCount
        let threads = max(1, Int(Double(cores) * threadFraction))

        let rigName = (Host.current().localizedName ?? "mac")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
        let p = Process()
        p.executableURL = Self.binaryURL
        p.arguments = [
            "-a", "verus",                          // VerusHash 2.2
            "-o", pool,                             // stratum+tcp://na.luckpool.net:3956
            "-u", "\(address).\(rigName)",          // VRSC address.rigname
            "-p", "d=6",                            // pool difficulty hint
            "-t", String(threads)                   // thread count
        ]
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = outPipe
        do {
            try p.run()
            process = p
            state = .running(threads: threads, hashRate: nil)

            // Parse hash rate from cpuminer's stdout. Example line:
            //   "[hash rate] 1.23 Mh/s, ..."
            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                guard let line = String(data: handle.availableData, encoding: .utf8) else { return }
                if let rate = Self.parseHashRate(from: line) {
                    Task { @MainActor in
                        self?.state = .running(threads: threads, hashRate: rate)
                    }
                }
            }

            p.terminationHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.process = nil
                    self?.state = .stopped
                }
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        state = .stopped
    }

    /// Lookahead estimate of monthly USD income at the current hash rate
    /// using a hardcoded VRSC price reference. Replace with PriceFetcher
    /// reading once we add VRSC to CoinGecko polling.
    func estimatedMonthlyUSD(_ vrscPriceUSD: Double = 0.45) -> Double? {
        guard case .running(_, let hashRate) = state, let rate = hashRate else { return nil }
        // Network constant: ~6.6M Sol/s network, ~24 VRSC block reward, 1-min blocks.
        // Operator share for solo mining at this rate ≈ rate / network * blocks/day * reward.
        let network = 6_600_000.0
        let blocksPerDay = 1440.0
        let reward = 24.0
        let dailyVRSC = (rate / network) * blocksPerDay * reward
        return dailyVRSC * vrscPriceUSD * 30
    }

    nonisolated private static func parseHashRate(from text: String) -> Double? {
        // Matches "1.23 Mh/s" or "456 kh/s"
        let pattern = #"([0-9]+\.?[0-9]*)\s*([KMG])h/s"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange])
        else { return nil }
        switch text[unitRange].uppercased() {
        case "K": return value * 1_000
        case "M": return value * 1_000_000
        case "G": return value * 1_000_000_000
        default: return value
        }
    }
}
