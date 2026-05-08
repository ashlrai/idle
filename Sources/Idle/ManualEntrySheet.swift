import SwiftUI

/// Modal sheet for entering current balance and recording payouts.
/// Surfaces in the Earnings dashboard via "Update" button on each app card.
struct ManualEntrySheet: View {
    let app: DePinApp
    @ObservedObject var manual: ManualEarnings
    let onClose: () -> Void

    @State private var newBalanceAmount: String = ""
    @State private var newBalanceNote: String = ""
    @State private var payoutAmount: String = ""
    @State private var payoutMethod: String = "PayPal"
    @State private var payoutRef: String = ""
    @State private var payoutNote: String = ""
    @State private var tab: Tab = .balance

    enum Tab: String, CaseIterable, Identifiable {
        case balance = "Update balance"
        case payout = "Log a payout"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            ScrollView {
                Group {
                    switch tab {
                    case .balance: balanceForm
                    case .payout:  payoutForm
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()
            footer
        }
        .frame(width: 540, height: 580)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.and.outline")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.headline)
                Text("Manual entry — your typed-in numbers are the trusted source of truth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Button("Cancel", action: onClose)
            Spacer()
            Button(saveLabel) { save() }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding(16)
    }

    private var saveLabel: String {
        tab == .balance ? "Save balance" : "Log payout"
    }

    private var canSave: Bool {
        switch tab {
        case .balance: return Double(newBalanceAmount.trimmingCharacters(in: .whitespaces)) != nil
        case .payout:  return Double(payoutAmount.trimmingCharacters(in: .whitespaces)) != nil
        }
    }

    @ViewBuilder
    private var balanceForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let last = manual.latestBalance(for: app.id) {
                LabeledContent("Last entered") {
                    Text(formatAmount(last.amount, currency: last.currency))
                        .font(.body.monospacedDigit())
                    + Text("  ·  \(last.ts.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            HStack(alignment: .center, spacing: 8) {
                Text(currencySymbol).font(.title3.weight(.medium))
                TextField("0.00", text: $newBalanceAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .font(.title3.monospacedDigit())
                Text(currencyCode).font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            TextField("Note (optional — e.g. 'after withdrawal')", text: $newBalanceNote)
                .textFieldStyle(.roundedBorder)
            Text("Open \(app.name) dashboard, copy the balance number, type it here. Replaces any prior auto-scraped value for this app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Divider().padding(.vertical, 8)

            Text("Recent balance history").font(.subheadline.weight(.medium))
            ForEach(history, id: \.id) { b in
                HStack {
                    Text(formatAmount(b.amount, currency: b.currency)).font(.body.monospacedDigit())
                    Spacer()
                    Text(b.ts.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                    if let note = b.note, !note.isEmpty {
                        Text("· \(note)").font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        manual.deleteBalance(b.id)
                    } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            if history.isEmpty {
                Text("No history yet").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var payoutForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(currencySymbol).font(.title3.weight(.medium))
                TextField("0.00", text: $payoutAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .font(.title3.monospacedDigit())
                Text(currencyCode).font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text("To:").foregroundStyle(.secondary)
                Picker("", selection: $payoutMethod) {
                    Text("PayPal").tag("PayPal")
                    Text("Venmo").tag("Venmo")
                    Text("Bank").tag("Bank")
                    Text("Bitcoin").tag("Bitcoin")
                    Text("Solana").tag("Solana")
                    Text("Ethereum").tag("Ethereum")
                    Text("Gift Card").tag("Gift Card")
                    Text("Other").tag("Other")
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }
            TextField("Transaction ID / PayPal email / wallet (optional)", text: $payoutRef)
                .textFieldStyle(.roundedBorder)
            TextField("Note (optional)", text: $payoutNote)
                .textFieldStyle(.roundedBorder)
            Text("Logging a payout records that money actually arrived. Counts toward your lifetime earnings — the most trusted total.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Divider().padding(.vertical, 8)

            Text("Payout history for \(app.name)").font(.subheadline.weight(.medium))
            ForEach(payoutHistory, id: \.id) { p in
                HStack {
                    Text(formatAmount(p.amount, currency: p.currency)).font(.body.monospacedDigit())
                    Text("→ \(p.method)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(p.ts.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                    Button { manual.deletePayout(p.id) } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            if payoutHistory.isEmpty {
                Text("No payouts logged yet").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var currencySymbol: String {
        switch app.payoutKind {
        case .usd: return "$"
        default:   return ""
        }
    }

    private var currencyCode: String {
        switch app.payoutKind {
        case .usd: return "USD"
        case .token(let s): return s
        }
    }

    private var history: [ManualEarnings.Balance] {
        manual.balances.filter { $0.appId == app.id }.sorted(by: { $0.ts > $1.ts }).prefix(8).map { $0 }
    }

    private var payoutHistory: [ManualEarnings.Payout] {
        manual.allPayouts(for: app.id).prefix(8).map { $0 }
    }

    private func formatAmount(_ v: Double, currency: String) -> String {
        switch currency {
        case "USD": return String(format: "$%.2f", v)
        default: return String(format: "%.4f %@", v, currency)
        }
    }

    private func save() {
        switch tab {
        case .balance:
            guard let amt = Double(newBalanceAmount.trimmingCharacters(in: .whitespaces)) else { return }
            manual.recordBalance(
                appId: app.id, amount: amt, currency: currencyCode,
                note: newBalanceNote.isEmpty ? nil : newBalanceNote
            )
            newBalanceAmount = ""
            newBalanceNote = ""
        case .payout:
            guard let amt = Double(payoutAmount.trimmingCharacters(in: .whitespaces)) else { return }
            manual.recordPayout(
                appId: app.id, amount: amt, currency: currencyCode,
                method: payoutMethod,
                txRef: payoutRef.isEmpty ? nil : payoutRef,
                note: payoutNote.isEmpty ? nil : payoutNote
            )
            payoutAmount = ""
            payoutRef = ""
            payoutNote = ""
        }
    }
}
