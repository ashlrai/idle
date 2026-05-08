import SwiftUI
import Charts
import AppKit

/// Dedicated earnings dashboard — separate window from the WKWebView dashboards.
/// Shows total $ across all six apps, 30-day trend chart, per-app cards with
/// last-known balance, and a CSV export button.
struct EarningsDashboardView: View {
    @ObservedObject var earnings: Earnings
    @ObservedObject var history: EarningsHistory
    @ObservedObject var prices: PriceFetcher
    @ObservedObject var manual: ManualEarnings

    @State private var range: TimeRange = .last7d
    @State private var entrySheet: DePinApp? = nil

    enum TimeRange: String, CaseIterable, Identifiable {
        case last24h, last7d, last30d, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .last24h: return "24h"
            case .last7d: return "7d"
            case .last30d: return "30d"
            case .all: return "All"
            }
        }
        var days: Int? {
            switch self {
            case .last24h: return 1
            case .last7d: return 7
            case .last30d: return 30
            case .all: return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                totalsCard
                chartCard
                perAppGrid
                pricesCard
            }
            .padding(24)
        }
        .frame(minWidth: 900, minHeight: 700)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.green).font(.title2)
            Text("Earnings").font(.largeTitle.bold())
            Spacer()
            Picker("Range", selection: $range) {
                ForEach(TimeRange.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            Button {
                Task { await earnings.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
            Button {
                exportCSV()
            } label: {
                Label("Export CSV", systemImage: "tray.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
    }

    private var totalsCard: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trusted total — your typed-in numbers")
                    .font(.caption).foregroundStyle(.secondary)
                Text(formatUSD(manual.trustableUSD))
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                    .foregroundStyle(.green)
                Text("\(manual.payouts.count) payouts logged · \(uniqueAppsWithBalance) apps with current balance")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Scraper estimate").font(.caption).foregroundStyle(.secondary)
                Text(formatUSD(earnings.totalUSD))
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(.orange)
                Text("auto, less reliable")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Active apps").font(.caption).foregroundStyle(.secondary)
                Text("\(activeAppCount) / \(AppRegistry.all.count)")
                    .font(.title2.bold().monospacedDigit())
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private var uniqueAppsWithBalance: Int {
        Set(manual.balances.map(\.appId)).count
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend").font(.headline)
            if chartEntries.isEmpty {
                emptyChart
            } else {
                Chart(chartEntries) { entry in
                    LineMark(
                        x: .value("Time", entry.ts),
                        y: .value("USD", usdValue(of: entry))
                    )
                    .foregroundStyle(by: .value("App", entry.appId))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Time", entry.ts),
                        y: .value("USD", usdValue(of: entry))
                    )
                    .foregroundStyle(by: .value("App", entry.appId))
                    .symbolSize(20)
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 260)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private var emptyChart: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundStyle(.secondary)
            Text("No history yet — Idle starts recording the first time the dashboards window stays open.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var perAppGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Per app").font(.headline)
                Spacer()
                Text("Click any card to enter your own number")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(AppRegistry.all) { app in
                    AppEarningCard(
                        app: app,
                        reading: earnings.readings[app.id],
                        manualBalance: manual.latestBalance(for: app.id),
                        payoutTotal: manual.allPayouts(for: app.id).reduce(0) { $0 + $1.amount },
                        onUpdate: { entrySheet = app }
                    )
                }
            }
        }
        .sheet(item: $entrySheet) { app in
            ManualEntrySheet(app: app, manual: manual) {
                entrySheet = nil
            }
        }
    }

    private var pricesCard: some View {
        HStack(spacing: 20) {
            Image(systemName: "bitcoinsign.circle").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Token prices (USD)").font(.subheadline.weight(.medium))
                if let last = prices.lastFetched {
                    Text("Updated \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Cached defaults — Idle refreshes from CoinGecko every 6h")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            ForEach(prices.prices.sorted(by: { $0.key < $1.key }), id: \.key) { (sym, usd) in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(sym).font(.caption).foregroundStyle(.secondary)
                    Text(formatTokenPrice(usd)).font(.body.monospacedDigit().weight(.medium))
                }
            }
            Button {
                Task { await prices.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    // MARK: - Helpers

    private var activeAppCount: Int {
        earnings.readings.values.filter { $0.amount != nil && ($0.amount ?? 0) > 0 }.count
    }

    private var chartEntries: [EarningsHistory.Entry] {
        let entries: [EarningsHistory.Entry]
        if let days = range.days {
            entries = history.entries(within: days)
        } else {
            entries = history.entries
        }
        return entries
    }

    private func usdValue(of entry: EarningsHistory.Entry) -> Double {
        switch entry.currency {
        case "USD": return entry.amount
        default:
            let price = Earnings.tokenPriceUSD[entry.currency, default: 0]
            return entry.amount * price
        }
    }

    private func formatUSD(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private func formatTokenPrice(_ v: Double) -> String {
        v >= 1 ? String(format: "$%.2f", v) : String(format: "$%.4f", v)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "idle-earnings-\(Int(Date().timeIntervalSince1970)).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? history.exportCSV(to: url)
        }
    }
}

private struct AppEarningCard: View {
    let app: DePinApp
    let reading: Earnings.Reading?
    let manualBalance: ManualEarnings.Balance?
    let payoutTotal: Double
    let onUpdate: () -> Void

    var body: some View {
        Button(action: onUpdate) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "leaf.fill").foregroundStyle(.green).font(.caption)
                    Text(app.name).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(payoutLabel).font(.caption2).foregroundStyle(.secondary)
                }
                Text(primaryLabel).font(.title3.bold().monospacedDigit())
                    .foregroundStyle(primaryColor)
                Text(secondaryLabel).font(.caption2).foregroundStyle(.secondary)
                if payoutTotal > 0 {
                    Text("paid out: \(String(format: "%.2f %@", payoutTotal, currencyCode))")
                        .font(.caption2).foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var payoutLabel: String { currencyCode }

    private var currencyCode: String {
        switch app.payoutKind {
        case .usd: return "USD"
        case .token(let s): return s
        }
    }

    /// Prefer manual balance over scraper reading. Manual is trusted; scraper is fragile.
    private var primaryLabel: String {
        if let manual = manualBalance {
            switch manual.currency {
            case "USD": return String(format: "$%.2f", manual.amount)
            default: return String(format: "%.4f %@", manual.amount, manual.currency)
            }
        }
        guard let amount = reading?.amount else { return "—" }
        switch reading?.currency {
        case "USD": return String(format: "$%.2f", amount)
        case let s?: return String(format: "%.2f %@", amount, s)
        default: return String(format: "%.2f", amount)
        }
    }

    private var primaryColor: Color {
        manualBalance != nil ? .primary : .secondary
    }

    private var secondaryLabel: String {
        if let manual = manualBalance {
            return "Manual entry · \(manual.ts.formatted(.relative(presentation: .numeric)))"
        }
        if let asOf = reading?.asOf, reading?.amount != nil {
            return "Auto-scraped · \(asOf.formatted(.relative(presentation: .numeric)))"
        }
        return "Click to enter your balance"
    }
}
