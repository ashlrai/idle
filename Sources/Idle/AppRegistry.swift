import Foundation

struct DePinApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let appPath: String?
    let signupURL: URL
    let dashboardURL: URL
    let downloadURL: URL?
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
    /// These are filled in after the operator signs up. Until then, signup
    /// links go to the bare service and no referral commission is earned.
    struct ReferralCodes {
        var pawns: String?
        var grass: String?
        var honeygain: String?
        var earnApp: String?
        var mystNodes: String?
        var nodepay: String?
    }

    static var referrals = ReferralCodes(
        pawns: nil,
        grass: nil,
        honeygain: nil,
        earnApp: nil,
        mystNodes: nil,
        nodepay: nil
    )

    static var all: [DePinApp] {
        [
            DePinApp(
                id: "pawns",
                name: "Pawns",
                bundleIdentifier: "com.pawns.desktop",
                appPath: "/Applications/Pawns app.app",
                signupURL: signup("https://dashboard.pawns.app/register", refParam: "ref", refCode: referrals.pawns),
                dashboardURL: URL(string: "https://dashboard.pawns.app/")!,
                downloadURL: URL(string: "https://cdn.pawns.app/download/app/releases/darwin64/latest/Pawns.app.dmg"),
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "grass",
                name: "Grass",
                bundleIdentifier: "io.getgrass.desktop",
                appPath: nil,
                signupURL: signup("https://app.grass.io/register", refParam: "ref", refCode: referrals.grass),
                dashboardURL: URL(string: "https://app.grass.io/dashboard")!,
                downloadURL: URL(string: "https://app.grass.io/dashboard/download/item/desktop"),
                kind: .nativeApp,
                payoutKind: .token(symbol: "GRASS")
            ),
            DePinApp(
                id: "honeygain",
                name: "Honeygain",
                bundleIdentifier: "com.honeygain.honeygain",
                appPath: "/Applications/Honeygain.app",
                signupURL: signup("https://dashboard.honeygain.com/sign-up", refParam: "code", refCode: referrals.honeygain),
                dashboardURL: URL(string: "https://dashboard.honeygain.com/")!,
                downloadURL: URL(string: "https://dashboard.honeygain.com/get-app"),
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "earnapp",
                name: "EarnApp",
                bundleIdentifier: "com.earnapp.app",
                appPath: "/Applications/EarnApp.app",
                signupURL: signup("https://earnapp.com/dashboard/signup", refParam: "referral", refCode: referrals.earnApp),
                dashboardURL: URL(string: "https://earnapp.com/dashboard")!,
                downloadURL: URL(string: "https://earnapp.com/dashboard"),
                kind: .nativeApp,
                payoutKind: .usd
            ),
            DePinApp(
                id: "mystnodes",
                name: "MystNodes",
                bundleIdentifier: "network.mysterium.launcher",
                appPath: "/Applications/MystNodes Launcher.app",
                signupURL: signup("https://my.mystnodes.com/registration", refParam: "ref", refCode: referrals.mystNodes),
                dashboardURL: URL(string: "https://my.mystnodes.com/")!,
                downloadURL: URL(string: "https://github.com/mysteriumnetwork/myst-launcher-release/releases/latest/download/MystNodesLauncher.dmg"),
                kind: .nativeApp,
                payoutKind: .token(symbol: "MYST")
            ),
            DePinApp(
                id: "nodepay",
                name: "Nodepay",
                bundleIdentifier: nil,
                appPath: nil,
                signupURL: signup("https://app.nodepay.ai/register", refParam: "ref", refCode: referrals.nodepay),
                dashboardURL: URL(string: "https://app.nodepay.ai/dashboard")!,
                downloadURL: URL(string: "https://chromewebstore.google.com/detail/nodepay-extension/lgmpfmgeabnnlemejacfljbmonaomfmm"),
                kind: .chromeExtension,
                payoutKind: .token(symbol: "NODE")
            )
        ]
    }

    private static func signup(_ base: String, refParam: String, refCode: String?) -> URL {
        guard let code = refCode, var components = URLComponents(string: base) else {
            return URL(string: base)!
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: refParam, value: code))
        components.queryItems = items
        return components.url ?? URL(string: base)!
    }
}
