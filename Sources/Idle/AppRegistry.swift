import Foundation

struct DePinApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let appPath: String?
    let signupURL: URL
    let dashboardURL: URL
    let downloadURL: URL?
    /// Direct DMG/PKG URL for one-click install. nil for apps whose installer
    /// is gated behind a logged-in dashboard (Honeygain, EarnApp).
    let directDownloadURL: URL?
    let kind: Kind
    let payoutKind: PayoutKind

    enum Kind: Hashable {
        case nativeApp
        case chromeExtension
    }

    enum PayoutKind: Hashable {
        case usd
        case token(symbol: String)
    }
}

enum AppRegistry {
    /// The operator's referral code for each supported DePIN app.
    /// Each service uses a different URL format — see the per-app builders below.
    /// Default is nil (uses the bare signup URL with no commission to operator);
    /// `RemoteConfig` overrides these from idle.ashlr.ai/config.json on launch.
    struct ReferralCodes {
        var pawns: String?
        var grass: String?
        var honeygain: String?
        var earnApp: String?
        var mystNodes: String?
        var nodepay: String?
        var repocket: String?
        var salad: String?
    }

    static var referrals = ReferralCodes(
        pawns: nil,
        grass: nil,
        honeygain: nil,
        earnApp: nil,
        mystNodes: nil,
        nodepay: nil,
        repocket: nil,
        salad: nil
    )

    static var all: [DePinApp] {
        [
            DePinApp(
                id: "pawns",
                name: "Pawns",
                bundleIdentifier: "com.pawns.desktop",
                appPath: "/Applications/Pawns app.app",
                signupURL: pawnsSignupURL(),
                dashboardURL: URL(string: "https://dashboard.pawns.app/")!,
                downloadURL: URL(string: "https://cdn.pawns.app/download/app/releases/darwin64/latest/Pawns.app.dmg"),
                directDownloadURL: URL(string: "https://cdn.pawns.app/download/app/releases/darwin64/latest/Pawns.app.dmg"),
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "grass",
                name: "Grass",
                bundleIdentifier: "io.getgrass.desktop",
                appPath: nil,
                signupURL: grassSignupURL(),
                dashboardURL: URL(string: "https://app.grass.io/dashboard")!,
                downloadURL: URL(string: "https://app.grass.io/dashboard/download/item/desktop"),
                directDownloadURL: nil,
                kind: .nativeApp,
                payoutKind: .token(symbol: "GRASS")
            ),
            DePinApp(
                id: "honeygain",
                name: "Honeygain",
                bundleIdentifier: "com.honeygain.honeygain",
                appPath: "/Applications/Honeygain.app",
                signupURL: honeygainSignupURL(),
                dashboardURL: URL(string: "https://dashboard.honeygain.com/")!,
                downloadURL: URL(string: "https://dashboard.honeygain.com/get-app"),
                directDownloadURL: nil,
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "earnapp",
                name: "EarnApp",
                bundleIdentifier: "com.earnapp.app",
                appPath: "/Applications/EarnApp.app",
                signupURL: earnAppSignupURL(),
                dashboardURL: URL(string: "https://earnapp.com/dashboard")!,
                downloadURL: URL(string: "https://earnapp.com/dashboard"),
                directDownloadURL: nil,
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "mystnodes",
                name: "MystNodes",
                bundleIdentifier: "network.mysterium.launcher",
                appPath: "/Applications/MystNodes Launcher.app",
                signupURL: mystNodesSignupURL(),
                dashboardURL: URL(string: "https://my.mystnodes.com/")!,
                downloadURL: URL(string: "https://github.com/mysteriumnetwork/myst-launcher-release/releases/latest/download/MystNodesLauncher.dmg"),
                directDownloadURL: URL(string: "https://github.com/mysteriumnetwork/myst-launcher-release/releases/latest/download/MystNodesLauncher.dmg"),
                kind: .nativeApp,
                payoutKind: .token(symbol: "MYST")
            ),
            DePinApp(
                id: "nodepay",
                name: "Nodepay",
                bundleIdentifier: nil,
                appPath: nil,
                signupURL: nodepaySignupURL(),
                dashboardURL: URL(string: "https://app.nodepay.ai/dashboard")!,
                downloadURL: URL(string: "https://chromewebstore.google.com/detail/nodepay-extension/lgmpfmgeabnnlemejacfljbmonaomfmm"),
                directDownloadURL: nil,
                kind: .chromeExtension,
                payoutKind: .token(symbol: "NODE")
            ),
            DePinApp(
                id: "repocket",
                name: "Repocket",
                bundleIdentifier: "io.repocket.repocket",
                appPath: "/Applications/Repocket.app",
                signupURL: repocketSignupURL(),
                dashboardURL: URL(string: "https://link.repocket.com/")!,
                downloadURL: URL(string: "https://link.repocket.com/"),
                directDownloadURL: nil,
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "salad",
                // Salad pays cash/gift-cards for compute (CPU/GPU cycles, AI workloads).
                // Different category from the bandwidth-resale DePIN apps above —
                // doesn't conflict with bandwidth IP fingerprinting, so it's the
                // primary recommended add-on for users with a 32GB+ second Mac.
                name: "Salad",
                bundleIdentifier: "com.salad.SaladDesktop",
                appPath: "/Applications/Salad.app",
                signupURL: saladSignupURL(),
                dashboardURL: URL(string: "https://app.salad.com/")!,
                downloadURL: URL(string: "https://salad.com/download"),
                directDownloadURL: nil,
                kind: .nativeApp,
                payoutKind: .usd
            )
        ]
    }

    // MARK: - Per-service signup URL builders
    //
    // Each DePIN service uses a different referral URL format. We can't share
    // one templated builder because some are query-param style and some are
    // path-based. Centralized here so RemoteConfig can change the codes
    // without touching the URL shapes.

    private static func pawnsSignupURL() -> URL {
        // Pawns referral param is `r`, lands on the marketing site which then
        // redirects into dashboard.pawns.app/register with the referral cookie set.
        if let code = referrals.pawns {
            return URL(string: "https://pawns.app/?r=\(code)")!
        }
        return URL(string: "https://dashboard.pawns.app/register")!
    }

    private static func grassSignupURL() -> URL {
        // Grass uses ?referralCode= (not ?ref=).
        if let code = referrals.grass {
            return URL(string: "https://app.grass.io/register?referralCode=\(code)")!
        }
        return URL(string: "https://app.grass.io/register")!
    }

    private static func honeygainSignupURL() -> URL {
        // Honeygain referrals are path-based on a separate join. subdomain.
        if let code = referrals.honeygain {
            return URL(string: "https://join.honeygain.com/\(code)")!
        }
        return URL(string: "https://dashboard.honeygain.com/sign-up")!
    }

    private static func earnAppSignupURL() -> URL {
        // EarnApp referrals are path-based on /i/<code>.
        if let code = referrals.earnApp {
            return URL(string: "https://earnapp.com/i/\(code)")!
        }
        return URL(string: "https://earnapp.com/dashboard/signup")!
    }

    private static func mystNodesSignupURL() -> URL {
        // MystNodes uses ?referral_code= and the .co alias domain that
        // redirects to my.mystnodes.com/registration with the cookie set.
        if let code = referrals.mystNodes {
            return URL(string: "https://mystnodes.co/?referral_code=\(code)")!
        }
        return URL(string: "https://my.mystnodes.com/registration")!
    }

    private static func nodepaySignupURL() -> URL {
        // Nodepay referrals are path-based on /ref/<code>.
        if let code = referrals.nodepay {
            return URL(string: "https://nodepay.ai/ref/\(code)")!
        }
        return URL(string: "https://app.nodepay.ai/register")!
    }

    private static func repocketSignupURL() -> URL {
        // Repocket uses ?aid= as the referral parameter on link.repocket.com.
        if let code = referrals.repocket {
            return URL(string: "https://link.repocket.com/?aid=\(code)")!
        }
        return URL(string: "https://link.repocket.com/")!
    }

    private static func saladSignupURL() -> URL {
        // Salad uses ?referral=<code> on the signup flow.
        if let code = referrals.salad {
            return URL(string: "https://salad.com/?referral=\(code)")!
        }
        return URL(string: "https://salad.com/")!
    }
}
