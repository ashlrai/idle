# Launch playbook — distribute Idle without Apple Developer

Pre-written posts. Copy/paste into each channel. **Post on a Tuesday or Wednesday between 8-10am PT** for max HN visibility; Reddit and Twitter are less time-sensitive.

---

## 1. Show HN — Hacker News

URL: https://news.ycombinator.com/submit

**Title** (under 80 chars):
```
Show HN: Idle – Native macOS DePIN orchestrator (Hivello successor)
```

**URL field**: `https://idle.ashlr.ai`

**Text field** (leave empty unless HN asks for one — if it does, paste this):
```
Built this after Hivello shut down its DePIN orchestrator on Jan 30, 2026. The existing alternatives (money4band) are Docker-based and heavy on a 16GB Mac.

Idle is native Swift, runs as a menu-bar accessory, zero runtime dependencies. It orchestrates 8 DePIN services (Pawns, Grass, Honeygain, EarnApp, MystNodes, Nodepay, Repocket, Salad) plus optional Verus CPU mining (VerusHash 2.2 runs unusually well on M-series).

Realistic earnings: $15-35/mo from a single residential US IP, with speculative crypto-token upside on top. Not the "$500/mo passive income" you'll see on YouTube — that's almost always survey stacking, not pure DePIN.

What's interesting (technically):
- Embedded WKWebView per signup with JS prefill of email/password
- Clipboard OTP detection so SMS codes from Messages.app auto-fill into the active form
- Manual earnings entry as the trusted source of truth (the auto-scraper hallucinated a $2067 reading at one point — manual numbers are now the canonical total)
- Pre-flight checks (Apple Silicon, AC power, no VPN, residential IP) before you waste time signing up
- Zero telemetry, zero analytics, no third-party SDKs

Distributed via Homebrew tap (no Gatekeeper warnings) since I haven't paid for an Apple Developer cert yet. Will add notarization once there's traction.

Code: github.com/ashlrai/idle (MIT)
```

---

## 2. Reddit — r/MacApps

URL: https://reddit.com/r/MacApps/submit

**Title**:
```
Idle - native macOS menu-bar app for DePIN passive income (Hivello successor)
```

**Body**:
```
After Hivello shut down its orchestrator in January, I built a native Swift replacement. It manages 8 DePIN services + optional Verus CPU mining in a single menu-bar app.

**Install**: `brew install --cask ashlrai/idle/idle`

(or DMG download if you don't use Homebrew — there's a one-line Terminal command to bypass Gatekeeper since I haven't paid for the $99/yr Apple Developer cert yet)

**Realistic earnings**: $15-35/mo from a single residential US IP. Honest expectations on the landing page — no "$500/mo" bullshit.

**Features**:
- Embedded WKWebView onboarding wizard with JS credential prefill
- Clipboard OTP detection (copy SMS code → auto-fills the form)
- Manual earnings tracker (CSV export for taxes, USD total in menu bar)
- Pre-flight checks before signup
- Verus CPU mining toggle (Apple Silicon's hidden gem — VerusHash 2.2 runs well on M-series)
- Zero telemetry

Source: github.com/ashlrai/idle (MIT)
Site: idle.ashlr.ai

Happy to answer questions about how I picked the 8 services, the multi-device-same-IP rules, or the architecture.
```

---

## 3. Reddit — r/passive_income

Same URL pattern, same title. Lead with **earnings honesty** since this subreddit is wary of scams:

```
**Honest framing first**: this is *not* a $500/mo passive income tool. Realistic earnings from a single residential US IP are $15-35/mo cash plus speculative crypto-token accumulation. If you've seen "$500/mo passive income from your laptop" claims, those are almost always survey stacking, not DePIN.

What this is: a native macOS menu-bar app that orchestrates 8 DePIN services (Pawns, Grass, Honeygain, EarnApp, MystNodes, Nodepay, Repocket, Salad) + optional Verus CPU mining in one place. After Hivello shut down its orchestrator in January, I built this in Swift — no Docker, native menu bar, zero telemetry.

Install: `brew install --cask ashlrai/idle/idle`
(or DMG download with one-line Gatekeeper workaround at idle.ashlr.ai/install)

Source: github.com/ashlrai/idle (MIT, fully open source)

Why I built it: Hivello died, money4band is Docker-heavy, and the existing tooling all assumed Linux servers. I wanted a Mac-native version with honest numbers.

Multi-device note: bandwidth-sharing apps fingerprint by residential IP, so adding a second account from another device on the same household IP earns $0 marginal. The new mac in your house doesn't double your bandwidth income — it can only add via compute (Verus mining) or storage (Storj).

Happy to answer technical or earnings-reality questions.
```

---

## 4. Reddit — r/beermoney

Title: `[App] Idle — native macOS DePIN orchestrator, 8 services in one menu-bar app`

```
For Mac users running DePIN bandwidth apps. Replaces Hivello (which shut down in Jan).

`brew install --cask ashlrai/idle/idle`

Manages signups, installs, status, and earnings tracking for Pawns / Grass / Honeygain / EarnApp / MystNodes / Nodepay / Repocket / Salad. Plus Verus CPU mining toggle.

Honest: $15-35/mo from a single residential US IP. Open source: github.com/ashlrai/idle

I did the research (which apps actually pay in 2026, multi-device IP rules, ISP AUP risk) and packed it into the welcome screen so you don't have to hunt around. CSV export for tax season.
```

---

## 5. Twitter / X thread

Post from @ashlrai:

**Tweet 1**:
```
Hivello shut down their macOS DePIN orchestrator in January. So I built a native Swift replacement.

Idle: 8 DePIN services + optional Verus CPU mining, one menu-bar app, zero telemetry, MIT licensed.

brew install --cask ashlrai/idle/idle

🌿 idle.ashlr.ai
```

**Tweet 2**:
```
Realistic income from one residential US IP: $15-35/mo cash + speculative crypto-token accumulation.

If you've seen "$500/mo passive from your laptop" — that's survey stacking, not pure DePIN. The honest cap on actual DePIN income for a single home Mac is closer to $30/mo.
```

**Tweet 3**:
```
Things I built into Idle that I wanted but couldn't find elsewhere:

• Embedded WKWebView onboarding with JS credential prefill
• Clipboard OTP detection — Messages.app codes auto-fill into the active signup
• Manual earnings entry that overrides the (fragile) auto-scraper
• Pre-flight checks (no VPN, residential IP, AC power)
```

**Tweet 4**:
```
What it deliberately doesn't do:

• No analytics. No crash reporting. No third-party SDKs.
• No automation that violates DePIN service ToS (multi-account-per-IP, etc.)
• No fake earnings figures. The $15-35/mo number is conservative; we cap auto-scraped readings to reject hallucinated marketing copy.
```

**Tweet 5**:
```
Source: github.com/ashlrai/idle
Homebrew tap: github.com/ashlrai/homebrew-idle
Site: idle.ashlr.ai

Open to PRs. Especially want help on the Gmail OAuth integration for auto-OTP in v0.9. ✉️
```

---

## 6. "Awesome list" submissions (PR drafts)

### awesome-mac (sindresorhus/awesome-macos-applications) → category "Productivity" or new "Passive Income"

```markdown
- [Idle](https://idle.ashlr.ai) - Native menu-bar orchestrator for DePIN passive-income services (Pawns, Grass, Honeygain, EarnApp, MystNodes, Nodepay, Repocket, Salad) + optional Verus CPU mining. Zero telemetry, MIT licensed. `brew install --cask ashlrai/idle/idle`
```

Open a PR at https://github.com/iCHAIT/awesome-macOS

### awesome-depin (jhaiduce/awesome-depin or similar) → "Tools" section

```markdown
- [Idle](https://github.com/ashlrai/idle) - Native macOS menu-bar orchestrator for 8 DePIN services. Successor to Hivello. Swift, zero telemetry, MIT.
```

---

## 7. Posting cadence

Same day:
- HN at 8am PT (Tuesday or Wednesday)
- 30 min later: r/MacApps
- 1 hour later: r/passive_income
- 2 hours later: r/beermoney
- 3 hours later: Twitter thread
- Day 2: awesome-list PRs

This avoids cross-platform spam-detector flags while maximizing same-day pickup if HN takes off.

---

## 8. Conversion expectations

Realistic numbers:
- HN front page (top 30): 5,000-30,000 visits, **50-300 installs** typical for a niche dev tool
- r/MacApps top: 1,000-5,000 visits, **30-150 installs**
- r/passive_income / r/beermoney: 500-3,000 visits, **20-100 installs**
- Twitter (cold launch from <1k followers): 100-500 visits, **5-30 installs**

**Combined ~100-500 installs in launch week.** At $20/mo per active user × 10% Ashlr referral kickback = **$200-1,000/mo recurring revenue from week-one launch**, ramping as users hit DePIN payout thresholds (Pawns $5, Honeygain $20, EarnApp $2.50) over the following 30-60 days.

The math: every 50 installs ≈ $100/mo recurring. To clear $500/mo pure-passive Ashlr revenue you need ~250 active users, achievable with one HN front-page hit.
