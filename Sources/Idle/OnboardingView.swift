import SwiftUI

/// Single-window onboarding wizard. Sidebar = list of 6 apps with status.
/// Main panel = embedded signup page (referral-coded URL) plus controls
/// for prefilling email + password and marking the step done.
struct OnboardingView: View {
    @ObservedObject var vault: Vault
    @ObservedObject var clipboard: Clipboard
    @State private var selection: String = AppRegistry.all.first?.id ?? "pawns"

    var body: some View {
        VStack(spacing: 0) {
            credentialsBar
            Divider()
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(minWidth: 1000, minHeight: 700)
    }

    private var credentialsBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle")
                .foregroundStyle(.secondary)
            Text("Email").font(.subheadline.weight(.medium))
            TextField("you@example.com", text: Binding(
                get: { vault.email },
                set: { vault.setEmail($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 280)

            Spacer()

            Text("\(vault.completed.count) of \(AppRegistry.all.count) signed up")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var sidebar: some View {
        List(AppRegistry.all, selection: $selection) { app in
            HStack(spacing: 10) {
                stepIndicator(for: app)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.body.weight(.medium))
                    Text(stepStatusLabel(for: app))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tag(app.id)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
    }

    @ViewBuilder
    private var detail: some View {
        if let app = AppRegistry.all.first(where: { $0.id == selection }) {
            OnboardingStepView(app: app, vault: vault, clipboard: clipboard)
                .id(app.id)
        } else {
            Text("Select an app")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func stepIndicator(for app: DePinApp) -> some View {
        if vault.isCompleted(app.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
        } else {
            Circle()
                .stroke(Color.secondary, lineWidth: 1.5)
                .frame(width: 14, height: 14)
        }
    }

    private func stepStatusLabel(for app: DePinApp) -> String {
        if vault.isCompleted(app.id) {
            return "Signed up"
        }
        return app.kind == .chromeExtension ? "Chrome extension" : "Pending"
    }
}

struct OnboardingStepView: View {
    let app: DePinApp
    @ObservedObject var vault: Vault
    @ObservedObject var clipboard: Clipboard

    var body: some View {
        VStack(spacing: 0) {
            stepHeader
            Divider()
            if clipboard.detectedOTP != nil || clipboard.detectedLink != nil {
                clipboardBanner
                Divider()
            }
            WebView(
                url: app.signupURL,
                key: "onboarding.\(app.id)",
                onLoadJS: prefillScript
            )
            Divider()
            stepFooter
        }
    }

    private var clipboardBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                if let otp = clipboard.detectedOTP {
                    Text("Detected code on clipboard: \(otp)")
                        .font(.subheadline.weight(.medium))
                    Text("Copied from Messages or Mail. Click insert to type it into this signup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let link = clipboard.detectedLink {
                    Text("Detected verification link")
                        .font(.subheadline.weight(.medium))
                    Text(link.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            if clipboard.detectedOTP != nil {
                Button("Insert code") {
                    if let otp = clipboard.detectedOTP { runOTPInsert(otp) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if let link = clipboard.detectedLink {
                Button("Open link") { NSWorkspace.shared.open(link) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            Button("Dismiss") { clipboard.dismiss() }
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
    }

    private var stepHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sign up for \(app.name)")
                    .font(.headline)
                Text(app.signupURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Prefill credentials") { runPrefill() }
                .buttonStyle(.borderedProminent)
                .disabled(vault.email.isEmpty)
        }
        .padding(12)
    }

    private var stepFooter: some View {
        HStack(spacing: 12) {
            Text("Password for \(app.name): ")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(vault.password(for: app.id))
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(vault.password(for: app.id), forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)

            Spacer()

            Toggle(isOn: Binding(
                get: { vault.isCompleted(app.id) },
                set: { vault.setCompleted(app.id, $0) }
            )) {
                Text("Mark complete").font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(12)
    }

    private func runPrefill() {
        WebViewCache.shared.runJS(prefillScript, on: "onboarding.\(app.id)")
    }

    private func runOTPInsert(_ code: String) {
        WebViewCache.shared.runJS(otpInsertScript(code: code), on: "onboarding.\(app.id)")
    }

    /// Handles two common OTP layouts: a single text/tel input, or a row of
    /// 4-8 single-character boxes (Grass uses 6 boxes). Dispatches React-
    /// friendly events so controlled components see the change.
    private func otpInsertScript(code: String) -> String {
        let safe = code.filter { $0.isNumber }
        return """
        (function () {
          function setReactValue(el, value) {
            const desc = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
            if (desc && desc.set) { desc.set.call(el, value); }
            else { el.value = value; }
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          }
          const code = '\(safe)';
          // Prefer multi-box layout when number of pin-style inputs matches the code length.
          const pinSelectors = [
            'input[type="tel"][maxlength="1"]',
            'input[inputmode="numeric"][maxlength="1"]',
            'input[autocomplete*="one-time-code"]',
            'input[name*="pin" i][maxlength="1"]',
            'input[name*="code" i][maxlength="1"]'
          ];
          let pins = [];
          for (const sel of pinSelectors) {
            const found = document.querySelectorAll(sel);
            if (found.length >= code.length) { pins = Array.from(found).slice(0, code.length); break; }
          }
          if (pins.length === code.length) {
            for (let i = 0; i < pins.length; i++) {
              setReactValue(pins[i], code[i]);
              pins[i].dispatchEvent(new KeyboardEvent('keydown', { key: code[i], bubbles: true }));
              pins[i].dispatchEvent(new KeyboardEvent('keyup', { key: code[i], bubbles: true }));
            }
            pins[pins.length - 1].focus();
            return { method: 'pinBoxes', count: pins.length };
          }
          // Single-input fallback.
          const single = document.querySelector(
            'input[autocomplete="one-time-code"], input[name*="otp" i], input[name*="code" i], input[type="tel"], input[type="text"]:not([type="email"])'
          );
          if (single) {
            setReactValue(single, code);
            single.focus();
            return { method: 'single' };
          }
          return { method: 'none' };
        })();
        """
    }

    /// JS that finds email + password fields and sets them via React-friendly
    /// native value setter, then dispatches input/change events. Matches
    /// against type=email, type=password, autocomplete attrs, and common
    /// placeholder/name patterns. Idempotent — safe to call multiple times.
    private var prefillScript: String {
        let email = vault.email.replacingOccurrences(of: "'", with: "\\'")
        let password = vault.password(for: app.id)
        return """
        (function () {
          function setReactValue(el, value) {
            const desc = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
            if (desc && desc.set) { desc.set.call(el, value); }
            else { el.value = value; }
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          }
          function find(selectors) {
            for (const s of selectors) {
              const el = document.querySelector(s);
              if (el) return el;
            }
            return null;
          }
          const emailEl = find([
            'input[type="email"]',
            'input[autocomplete="username"]',
            'input[name*="email" i]',
            'input[placeholder*="email" i]'
          ]);
          const passEl = find([
            'input[type="password"]',
            'input[autocomplete="new-password"]',
            'input[autocomplete="current-password"]',
            'input[name*="password" i]'
          ]);
          if (emailEl) setReactValue(emailEl, '\(email)');
          if (passEl) setReactValue(passEl, '\(password)');
          // Also fill confirm-password if present.
          const confirmEl = document.querySelectorAll('input[type="password"]')[1];
          if (confirmEl && confirmEl !== passEl) setReactValue(confirmEl, '\(password)');
          return { email: !!emailEl, password: !!passEl, confirm: !!confirmEl };
        })();
        """
    }
}
