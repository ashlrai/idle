import SwiftUI

/// First-launch screen. Shows the value proposition, runs pre-flight checks,
/// gets ISP / legal consent, then transitions into the onboarding wizard.
struct WelcomeView: View {
    @ObservedObject var preflight: Preflight
    @ObservedObject var vault: Vault
    let onContinue: () -> Void

    @State private var consentISP = false
    @State private var consentLegal = false
    @State private var consentExpectations = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                expectationsCard
                preflightCard
                consentCard
                continueButton
            }
            .padding(40)
            .frame(maxWidth: 720)
        }
        .frame(minWidth: 720, minHeight: 720)
        .onAppear {
            if preflight.checks.isEmpty { preflight.run() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill").foregroundStyle(.green).font(.title)
                Text("Welcome to Idle").font(.largeTitle.bold())
            }
            Text("Your Mac earns you small, steady passive income by sharing idle bandwidth with verified networks. Idle handles installs, signups, status, and earnings tracking in one place.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var expectationsCard: some View {
        Card(title: "Realistic earnings", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 8) {
                Row(label: "Cash (USD)", value: "$15 – $35 / month")
                Row(label: "Plus speculative", value: "GRASS / MYST / NODE tokens")
                Row(label: "First payout", value: "~Month 2 (Pawns $5 minimum)")
                Text("Influencers will tell you $200-500/mo. That's almost always survey stacking, not pure DePIN. Single-IP DePIN realistically nets $10-35.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var preflightCard: some View {
        Card(title: "Pre-flight", icon: "checkmark.shield") {
            if preflight.isRunning && preflight.checks.isEmpty {
                ProgressView("Running checks...")
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(preflight.checks) { check in
                        PreflightRow(check: check)
                    }
                    Button("Re-run checks") { preflight.run() }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var consentCard: some View {
        Card(title: "Acknowledge before continuing", icon: "hand.raised") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $consentExpectations) {
                    Text("I understand earnings are typically $15-35/month and there's no guaranteed minimum.")
                        .font(.subheadline)
                }
                Toggle(isOn: $consentISP) {
                    Text("My residential ISP's terms may prohibit reselling bandwidth (Comcast/Spectrum). I accept that risk.")
                        .font(.subheadline)
                }
                Toggle(isOn: $consentLegal) {
                    Text("My IP becomes the egress for buyers' traffic (mostly AI training and BI). I accept that I may receive ISP notices for traffic I didn't generate.")
                        .font(.subheadline)
                }
            }
            .toggleStyle(.checkbox)
        }
    }

    private var continueButton: some View {
        HStack {
            Spacer()
            Button(action: complete) {
                Text("Continue to setup")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!(consentExpectations && consentISP && consentLegal))
        }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "idle.welcome.completed")
        UserDefaults.standard.set(true, forKey: "idle.welcome.consentISP")
        UserDefaults.standard.set(true, forKey: "idle.welcome.consentLegal")
        UserDefaults.standard.set(true, forKey: "idle.welcome.consentExpectations")
        UserDefaults.standard.set(Date(), forKey: "idle.welcome.consentedAt")
        onContinue()
    }
}

private struct Card<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
    }
}

private struct Row: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.weight(.medium))
        }
    }
}

private struct PreflightRow: View {
    let check: Preflight.Check

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title).font(.subheadline.weight(.medium))
                Text(check.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var iconName: String {
        switch check.severity {
        case .ok: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch check.severity {
        case .ok: return .green
        case .warn: return .orange
        case .fail: return .red
        }
    }
}

extension UserDefaults {
    static var hasCompletedWelcome: Bool {
        UserDefaults.standard.bool(forKey: "idle.welcome.completed")
    }
}
