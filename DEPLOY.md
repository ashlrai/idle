# Deploying Idle

Two pieces ship independently:

1. **Landing page + legal docs** → `idle.ashlr.ai` (Vercel)
2. **Idle.dmg binary** → GitHub Releases (free CDN, version-tagged)

The app fetches `idle.ashlr.ai/config.json` on launch to update referral codes — meaning **you can update referrals without rebuilding the app**.

---

## 1. Get your referral codes (do this first, once)

Idle's revenue comes from the 10% lifetime referral commission each DePIN service pays. Until you have your own codes, every signup goes via the bare URL and earns Ashlr nothing.

Sign up for each service yourself, then grab the referral code from each dashboard:

| Service | Where to find your code |
|---|---|
| Pawns | dashboard.pawns.app → Referrals → copy code |
| Grass | app.grass.io/dashboard → Refer & Earn → copy referral link, take query param |
| Honeygain | dashboard.honeygain.com → Refer a friend |
| EarnApp | earnapp.com/dashboard → Referrals |
| MystNodes | my.mystnodes.com/me/referral |
| Nodepay | app.nodepay.ai → Referrals |

Paste them all into `Marketing/config.json`:

```json
"referrals": {
  "pawns": "EARN3XYZ",
  "grass": "abcd1234",
  "honeygain": "honey-code",
  "earnApp": "earnapp-code",
  "mystNodes": "myst-code",
  "nodepay": "node-code"
}
```

---

## 2. Deploy the landing page to Vercel (idle.ashlr.ai)

The `Marketing/` directory is the deploy root. It contains:

```
Marketing/
├── index.html        landing page (with download CTA)
├── install.html      Gatekeeper-bypass walkthrough
├── privacy.html      privacy policy
├── terms.html        terms of service
├── _layout.css       shared styling
├── config.json       referral codes (fetched by the app)
└── vercel.json       caching + clean URL config
```

### Option A — Vercel CLI (fastest)

```bash
cd Marketing
npx vercel --prod
# First time: link to your Vercel account, scope to Ashlr team
# Subsequent: just runs the deploy
```

### Option B — Connect GitHub repo

1. Push the project to `github.com/ashlr/idle`.
2. Vercel dashboard → Add New → Project → import `ashlr/idle`.
3. Set **Root Directory** to `Marketing`.
4. Framework preset: **Other** (it's static HTML).
5. Build command: leave empty.
6. Output directory: leave empty (uses Marketing/ directly).
7. Deploy.

### Add the subdomain

Since `ashlr.ai` is already on Vercel, you can add `idle.ashlr.ai` as a subdomain to the new Idle project:

1. Vercel project → Settings → Domains → Add → `idle.ashlr.ai`.
2. Vercel will show a CNAME or A record to add. If `ashlr.ai` is already on Vercel, the records are auto-configured.
3. SSL provisions automatically within ~60 seconds.

Verify: `curl -I https://idle.ashlr.ai/config.json` should return 200 with the right Cache-Control header.

---

## 3. Host the DMG on GitHub Releases

The landing page links to `https://github.com/ashlr/idle/releases/latest/download/Idle.dmg`. Set up the repo and create the first release:

```bash
cd Idle
git init
git add .
git commit -m "v0.4.0 — trust + distribution"
gh repo create ashlr/idle --public --source=. --push

# Build the DMG
./Scripts/build_app.sh --dmg

# Tag and release
git tag v0.4.0
git push origin v0.4.0
gh release create v0.4.0 build/Idle.dmg \
    --title "v0.4.0 — Trust + Distribution" \
    --notes "Welcome screen, pre-flight checks, ISP/legal consent, Vercel landing page."
```

The download URL is now live at `https://github.com/ashlr/idle/releases/latest/download/Idle.dmg`. The landing page already points there. Future releases just need a new tag + `gh release create`.

---

## 4. Updating referrals without re-releasing

Once `idle.ashlr.ai` is live, updating referrals is just:

1. Edit `Marketing/config.json`.
2. `cd Marketing && npx vercel --prod` (or push to git if connected).
3. Wait 5 minutes for the cache to expire (or hit "Purge cache" in Vercel).

Idle clients fetch the new config on next launch and use the updated codes for any subsequent signups. Existing signups already routed under your old code — those keep paying lifetime commissions per the DePIN service's terms.

---

## 5. When to add Apple Developer Program ($99/yr)

Skip it for now. Revisit when:

- You have at least 50 active users (because at that point, conversion friction matters more than the $99).
- Or when at least one user has hit a meaningful payout via your referral code (proof the model works).
- Or when you want to submit a Show HN / r/MacApps post (Gatekeeper warning kills these).

Once you're ready:

```bash
# Inside the Idle Apple Developer Program account, create:
#   - Apple ID
#   - 16-char team ID (visible at developer.apple.com/account)
#   - App-specific password at appleid.apple.com → Sign-In and Security

export APPLE_ID="you@ashlr.ai"
export APPLE_TEAM_ID="XXXXXXXXXX"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./Scripts/build_app.sh --notarize --dmg
```

`build_app.sh` already has the notarize path scripted (lines around the `--notarize` flag). The DMG and `.app` get stapled, the Gatekeeper warning disappears, and the install walkthrough page becomes irrelevant.

---

## Smoke tests (run after each deploy)

```bash
# Landing page
curl -I https://idle.ashlr.ai/                 # 200
curl -I https://idle.ashlr.ai/install          # 200, Content-Type: text/html
curl -I https://idle.ashlr.ai/privacy          # 200
curl -I https://idle.ashlr.ai/terms            # 200

# Remote config
curl -s https://idle.ashlr.ai/config.json | jq '.referrals'

# DMG download
curl -ILo /dev/null -w "%{http_code}\n" \
    https://github.com/ashlr/idle/releases/latest/download/Idle.dmg
```

---

## Honest assessment

Without notarization, **expect ~20-40% of non-technical users to bounce at the Gatekeeper warning**, even with the install walkthrough. The remaining users are the ones who'll actually convert into your referral funnel — they're more committed than average, which is good. But the absolute ceiling is lower than with notarization.

Bite the $99 once you've validated the funnel works at small scale.
