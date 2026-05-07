# Privacy policy — Idle

Last updated: 2026-05-07

Idle is a native macOS app that you run on your own Mac. It is not a web service, and "we" means the operator who builds and distributes Idle. This policy describes the data Idle handles.

## Data Idle stores on your Mac

- **Email address**: the email you use for DePIN signups. Stored in macOS UserDefaults under `idle.vault.email`.
- **Per-app passwords**: 20-character random passwords Idle generates for each DePIN signup. Stored in UserDefaults under `idle.vault.passwords`.
- **Completion state**: which onboarding steps you've marked complete. UserDefaults under `idle.vault.completed`.
- **Consent timestamps**: when you accepted the welcome screen consents. UserDefaults under `idle.welcome.*`.

UserDefaults is plain text on disk in `~/Library/Preferences/`. v0.5 will migrate this to the macOS Keychain so it's encrypted at rest.

## Data Idle does not store

- Your DePIN earnings, payment methods, or wallet seed phrases.
- Your browsing history outside the embedded DePIN dashboards.
- Your contacts, files, or anything from other apps.

## Data Idle reads from external services

- **ipapi.co** — for the pre-flight residential-IP check. Idle sends one HTTP GET to `https://ipapi.co/json/` and reads the public JSON response. ipapi.co sees your public IP. We do not transmit anything else.
- **Embedded WKWebViews** — when you open the dashboards or onboarding window, each app's web dashboard runs in an embedded browser inside Idle. Cookies and form state are stored in the standard `WKWebsiteDataStore.default()`, which is sandboxed per-app on macOS.
- **Gmail (v0.5+, opt-in)** — if you configure Gmail integration, Idle requests `gmail.readonly` scope only, fetches messages from a hard-coded allowlist of DePIN sender domains, and parses OTPs and verification links. Idle never reads other emails. Tokens are stored in the Keychain.

## Data Idle never collects

Idle has no analytics, telemetry, crash reporting, or any phone-home of any kind. There are no third-party SDKs in the binary.

## Referrals

Each DePIN service signup link routes through the operator's referral code. The DePIN service may credit the operator with a 10% lifetime commission on your earnings — paid by the service, not by you. Your earnings are unchanged. The DePIN service knows it was a referral; it does not share any data with Idle.

## Your rights

- Delete all Idle data: drag `Idle.app` to the trash, then `defaults delete ai.ashlr.idle`.
- Export the credential vault: read `~/Library/Preferences/ai.ashlr.idle.plist`.
- Revoke OAuth scopes (when v0.5 ships): `myaccount.google.com/security` → Third-party access.

## Contact

Open an issue at github.com/your-org/idle.
