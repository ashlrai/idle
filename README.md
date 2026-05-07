# Idle — DePIN orchestrator for macOS

[![Build](https://github.com/ashlrai/idle/actions/workflows/build.yml/badge.svg)](https://github.com/ashlrai/idle/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/ashlrai/idle?label=latest)](https://github.com/ashlrai/idle/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-purple)](https://support.apple.com/en-us/HT211814)

A native menu-bar app that turns spare bandwidth on your Mac into small,
steady passive income. One window for the seven supported DePIN services
(Pawns, Grass, Honeygain, EarnApp, MystNodes, Nodepay, Repocket), an
embedded onboarding wizard with credential prefill and OTP capture, an
aggregated earnings dashboard with Swift Charts trend lines, and an
optional Verus CPU-mining toggle that's actually profitable on Apple
Silicon.

**Realistic earnings**: $15–35 / month from one residential US IP for the
six core bandwidth services, plus another $30–90 / month if you turn on
Verus mining 24/7 on AC. See [`OPPORTUNITIES.md`](OPPORTUNITIES.md) for the
honest breakdown.

**One-line install** (requires Homebrew):

```bash
curl -L https://github.com/ashlrai/idle/releases/latest/download/Idle.dmg -o /tmp/Idle.dmg && hdiutil attach /tmp/Idle.dmg && cp -R /Volumes/Idle/Idle.app /Applications/ && hdiutil detach /Volumes/Idle && xattr -d com.apple.quarantine /Applications/Idle.app && open /Applications/Idle.app
```

Or [download the DMG](https://github.com/ashlrai/idle/releases/latest/download/Idle.dmg)
and follow the [install walkthrough](https://idle.ashlr.ai/install).

**Why not Hivello?** Hivello shut down its DePIN orchestrator Jan 30, 2026.
It was Docker-based and heavy on a 16GB Mac. Idle is native Swift, runs as a
menu-bar accessory, ships with no Docker dependency, and has zero runtime
dependencies on third-party Swift packages.

**Business model: referral aggregation.** Each signup link in the app routes
through the operator's referral code (configured via remote JSON at
`idle.ashlr.ai/config.json`, no rebuild required). The user gets the same
earnings they would otherwise; the operator earns the 10% lifetime referral
commission per sub. Scale is the moat.

---

## Build + run

Requires Xcode 15+ on macOS 13+ (Apple Silicon).

### Dev mode (terminal-bound)

```bash
cd Idle
swift run Idle
```

A "Idle" item appears in the menu bar. Closing the terminal kills the app.

### App bundle (recommended)

```bash
cd Idle
./Scripts/build_app.sh --install
open /Applications/Idle.app
```

Produces a proper `.app` bundle (`build/Idle.app`) with `LSUIElement=true` (no
Dock icon, menu-bar only), ad-hoc codesigned. The `--install` flag also copies
it to `/Applications/`.

After installing, the popover footer shows a "Launch at login" toggle that
registers the bundle with `SMAppService.mainApp`. macOS will pop a permission
dialog the first time. Approve it once and the app starts at every login.

---

## What's in the popover

- **Stay awake toggle** — wraps `/usr/bin/caffeinate -imsu`. If a system
  LaunchAgent already runs caffeinate (for example, the one created by the
  setup script in `Desktop/passive income/`), the toggle reflects that state.
- **Per-app row** for each of the 6 supported DePIN apps:
  - Status dot (green = running, orange = installed not running, gray = not installed)
  - Action button: Get / Launch / Quit (depending on state)
  - Overflow menu: open dashboard, signup with referral, install/download
- **Open dashboards** button — opens the unified dashboards window
  (sidebar + WKWebView per app, persistent cookies so you stay logged in).
- **Refresh / Quit Idle** in the footer.

The status check polls every 5 seconds while the popover is open.

## The unified dashboards window

Click "Open dashboards" in the popover footer to open a single window with
every supported app embedded in WKWebViews. Pick an app from the sidebar →
its dashboard renders in the main panel. Cookies and form state persist
between selections via a shared `WKProcessPool`, so you stay signed in
when bouncing between apps. No more 9 browser tabs.

---

## Adding your referral codes

Edit `Sources/Idle/AppRegistry.swift`:

```swift
static var referrals = ReferralCodes(
    pawns: "EARN3",                  // your Pawns code (visible at pawns.app/referral)
    grass: "your-grass-code",        // app.grass.io/dashboard → Refer & Earn
    honeygain: "your-honeygain-code",
    earnApp: "your-earnapp-code",
    mystNodes: "your-mystnodes-code",
    nodepay: "your-nodepay-code"
)
```

Each app pages includes the operator referral as a query parameter on the
signup URL. Empty codes fall back to the bare signup URL.

---

## Distributing as a `.app` bundle

`Scripts/build_app.sh` produces an ad-hoc-signed bundle that runs locally. For
broader distribution:

1. Replace the ad-hoc `codesign --sign -` line with `codesign --sign
   "Developer ID Application: <Your Team>"`.
2. Notarize via `xcrun notarytool submit Idle.app --apple-id <id> --team-id
   <team> --password <app-specific>`.
3. Staple: `xcrun stapler staple Idle.app`.
4. Wrap in a DMG and host the download.

For App Store delivery, auto-update (Sparkle), and telemetry, convert this Swift
package into a proper `.xcodeproj`.

---

## Roadmap

**v0.1** — install/launch/quit + referral signup links + caffeinate toggle. ✅

**v0.2** — embedded dashboards window (`WKWebView` per app, persistent
cookies). Embedded onboarding wizard with email/password JS prefill. ✅

**v0.3** — `.app` bundle + launch at login via `SMAppService`. ✅

**v0.4** — Clipboard OTP monitor. Detects 4-8 digit codes and verification
links the user copies (from Messages / Mail / notification), surfaces a banner
in the onboarding window with one-click insert into the embedded signup form.
Handles both single-input and multi-box (Grass-style) OTP layouts. ✅

**v0.5** — Gmail OAuth integration (scaffolded; needs Google Cloud client ID
in `Config.swift`). App reads only verification emails for known DePIN domains,
extracts OTPs / clicks magic links, auto-fills into the embedded webview.
Eliminates the email blocker entirely.

**v0.6** — guided installer chain. Downloads DMG/PKG, mounts, copies `.app`
files, and runs `installer(8)` for PKGs via `osascript do shell script with
administrator privileges` (single password prompt for the whole batch).

**v0.7** — earnings aggregation. DOM-scraping per dashboard, total earnings
counter at top of unified window, CSV export tagged for tax (1099 USD vs
token cost basis).

**v0.8** — referral attribution telemetry. Track which sub-installations route
through the operator's referral so we can confirm commissions are flowing.

---

## What this app cannot automate (and why)

These are platform limits, not bugs:

- **SMS verification** (Pawns) — code is delivered to the user's phone. Idle
  v0.4 detects when the user copies the code from Messages and offers
  one-click insert into the active signup. Full automation needs Twilio.
- **Email OTP / verification links** (Grass, MystNodes) — copy + insert works
  today; v0.5 will add Gmail OAuth for full hands-free.
- **Admin password for `.pkg`** — Apple requires the user to type it. v0.6
  will consolidate to a single prompt for the whole install batch.
- **Google OAuth signup** (EarnApp) — OAuth providers verify human consent.
- **Chrome Web Store extension installs** — Chrome blocks all scripted clicks
  on chromewebstore.google.com (`extensions gallery cannot be scripted`).
- **Phantom seed phrase** — must be on paper to retain self-custody.

Idle reduces friction around everything else (downloading, mounting, copying,
launching, monitoring, status indication, referral routing, caffeinate
management, credential prefill, OTP capture). The human-in-the-loop steps
remain human, but each one is one-click instead of a manual hunt.
