import SwiftUI

/// Top-of-window earnings strip. Shows total USD-equivalent across all 6 apps,
/// plus per-app readings rolled up.
struct EarningsBar: View {
    @ObservedObject var earnings: Earnings

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total earnings")
                    .font(.caption).foregroundStyle(.secondary)
                Text(formatTotal(earnings.totalUSD))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.green)
            }

            Divider().frame(height: 36)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AppRegistry.all) { app in
                        AppEarningCell(app: app, reading: earnings.readings[app.id])
                    }
                }
            }

            Spacer(minLength: 8)

            Button {
                Task { await earnings.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now (auto-refreshes every 60s)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.06))
    }

    private func formatTotal(_ usd: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: usd)) ?? "$0.00"
    }
}

private struct AppEarningCell: View {
    let app: DePinApp
    let reading: Earnings.Reading?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(app.name).font(.caption.weight(.medium))
            Text(valueLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(reading?.amount != nil ? .primary : .secondary)
        }
        .frame(minWidth: 70, alignment: .leading)
    }

    private var valueLabel: String {
        guard let r = reading, let amount = r.amount else { return "—" }
        switch r.currency {
        case "USD":
            return String(format: "$%.2f", amount)
        default:
            return String(format: "%.2f %@", amount, r.currency)
        }
    }
}
