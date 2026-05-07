import Foundation

/// User-configurable settings. For MVP these live in source so they can be
/// changed by editing this file and rebuilding. v0.5+ should expose these
/// in a Settings window backed by UserDefaults.
enum Config {
    /// Set this to your Google Cloud OAuth 2.0 Client ID (Desktop app type)
    /// to enable v0.4's Gmail integration. Leave nil to keep the feature disabled.
    ///
    /// To create one:
    /// 1. console.cloud.google.com → New project ("Idle Inbox" or similar)
    /// 2. APIs & Services → Library → enable "Gmail API"
    /// 3. APIs & Services → OAuth consent screen → External, add yourself as test user
    /// 4. APIs & Services → Credentials → Create credentials → OAuth client ID
    ///    → Desktop app
    /// 5. Copy the Client ID into the constant below.
    /// 6. Add scope: https://www.googleapis.com/auth/gmail.readonly
    static let gmailClientID: String? = nil

    /// Twilio credentials for v0.5 SMS integration. Same drill: leave nil to disable.
    static let twilioAccountSID: String? = nil
    static let twilioAuthToken: String? = nil
}
