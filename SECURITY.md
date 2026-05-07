# Security policy

## Reporting a vulnerability

If you find a security issue in Idle, please report it privately so we can
fix it before it's public.

**Email**: tilly@ashlr.ai with subject `[idle-security]`

Please include:
- Affected version (`Idle.app/Contents/Info.plist` → `CFBundleShortVersionString`)
- Steps to reproduce
- Impact assessment (data exposed, code execution, etc.)
- A fix or mitigation suggestion if you have one

We aim to acknowledge within 48 hours and ship a fix within 14 days for
high-severity issues. We'll credit you in the release notes unless you
prefer anonymity.

## Scope

In scope:
- The Idle macOS app (`Sources/Idle/*`)
- The build/install scripts (`Scripts/*`)
- The marketing site (`Marketing/*`) hosted at `idle.ashlr.ai`
- The remote config endpoint at `idle.ashlr.ai/config.json`

Out of scope (these are third-party — report to the respective vendor):
- Pawns, Grass, Honeygain, EarnApp, MystNodes, Nodepay, Repocket dashboards
- Phantom wallet
- Chrome / Chrome Web Store
- macOS itself

## Threat model

What Idle protects:
- The user's email and per-app generated passwords stored in UserDefaults
  (v0.5.x — moving to Keychain in v0.6+).
- Cookies/state inside the embedded WKWebViews (sandboxed by macOS).
- The local earnings history at `~/Library/Application Support/Idle/`.

What Idle does NOT protect (and never claimed to):
- Phantom wallet seed phrases (those must be on paper, by design).
- DePIN service credentials once they're inside each service's own app
  (their security model, not ours).
- Your residential IP from being used as egress for buyer traffic (that's
  the entire DePIN model).

## Common false positives

- **VPN detected on first launch** — utun* interfaces appear on every Mac
  for Continuity / iCloud / AirDrop. v0.5.1+ checks for non-link-local IPv4
  on the tunnel before flagging. Earlier versions over-reported.
- **macOS Gatekeeper warning on download** — Idle isn't notarized yet
  ($99/yr Apple Developer cert). The bypass is documented in
  [install instructions](https://idle.ashlr.ai/install). This isn't a
  security bug — it's a known operational tradeoff.

## Disclosures

None to date.
