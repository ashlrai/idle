# Contributing to Idle

Thanks for considering a contribution. Idle is a small project with a clear
scope: orchestrate DePIN passive-income apps natively on Apple Silicon. This
document explains what we'll merge and what we won't, and how to get started.

## What we want

- **Bug fixes** — pre-flight check false positives, scraper drift when a
  DePIN dashboard's DOM changes, install / launch flow regressions on new
  macOS versions.
- **Earnings scraper improvements** — the per-app DOM extractors in
  `Sources/Idle/Earnings.swift` are best-effort. If you spot a service whose
  balance isn't being read, a more specific selector is welcome.
- **New DePIN integrations** — adding another bandwidth-sharing or compute
  service is a single file change in `AppRegistry.swift` (model + signup
  URL builder) plus an entry in `Marketing/config.json` for the operator
  referral. See `Repocket` in `AppRegistry.swift` for the cleanest example.
- **Native macOS polish** — VoiceOver, keyboard navigation, Stage Manager
  compatibility, dark/light mode tuning.
- **Translations** — Idle is English-only today. Localization is welcome;
  start with `en.lproj` and submit one language per PR.

## What we won't merge

- **Schemes that violate DePIN service terms** — multi-account farms,
  proxying through datacenter IPs, automated KYC bypass, etc. These get
  users banned.
- **Bundling GPL code into the MIT-licensed app bundle** — the cpuminer
  binary is GPLv3; that's why `Scripts/install_verus.sh` downloads it
  separately. Keep that pattern for any GPL dependencies you add.
- **Auto-creating accounts on third-party services** — Apple's safety
  guidelines and most services' ToS require human consent for account
  creation. Idle facilitates the human's signups; it does not do them.
- **Telemetry of any kind** — Idle has no analytics, no crash reporting,
  no phone-home. PRs adding any of these will be closed.

## Getting started

```bash
git clone https://github.com/ashlrai/idle.git
cd idle
swift run Idle    # dev mode (terminal-bound)
# or:
./Scripts/build_app.sh --install   # builds and installs Idle.app
```

Requires Xcode 15+, macOS 13+, Apple Silicon for testing the production
path. Linux contributors can compile-check via `swift build` but can't run.

## Pull request flow

1. Open an issue first if your change is non-trivial — saves us both time.
2. One feature per PR. Bug fixes can group small fixes if they're in the
   same area.
3. Run `swift build` and the smoke test in `.github/workflows/build.yml`
   locally before submitting.
4. Match the existing code style: SwiftUI, `@MainActor` on observable
   stores, no third-party dependencies (intentional — Idle has zero deps).

## Code of conduct

Be civil. We'll close issues and PRs that aren't, no second chances.

## Security

If you find a vulnerability, see [SECURITY.md](./SECURITY.md). Please don't
open a public issue for it.

## License

Contributions are licensed under MIT. By submitting a PR you agree to that.
