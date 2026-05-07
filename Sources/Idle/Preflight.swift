import Foundation
import IOKit.ps
import Network
import SystemConfiguration

/// Pre-flight checks run on first launch (and surfaced in the Welcome screen)
/// so the user knows their Mac is set up to actually earn before they invest
/// time in onboarding.
@MainActor
final class Preflight: ObservableObject {
    struct Check: Identifiable {
        enum Severity { case ok, warn, fail }
        let id: String
        let title: String
        let detail: String
        let severity: Severity
    }

    @Published private(set) var checks: [Check] = []
    @Published private(set) var isRunning = false

    func run() {
        isRunning = true
        Task {
            var results: [Check] = []
            results.append(architectureCheck())
            results.append(osVersionCheck())
            results.append(powerCheck())
            results.append(vpnCheck())
            // IP geolocation is async + network-dependent.
            if let ipCheck = await ipCheck() {
                results.append(ipCheck)
            }
            self.checks = results
            self.isRunning = false
        }
    }

    private func architectureCheck() -> Check {
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        var arm64: Int32 = 0
        sysctlbyname("hw.optional.arm64", &arm64, &size, nil, 0)
        if arm64 == 1 {
            return Check(id: "arch", title: "Apple Silicon", detail: "Required for native performance", severity: .ok)
        }
        return Check(id: "arch", title: "Intel Mac detected", detail: "Apps will run via Rosetta. Earnings unaffected but battery life suffers.", severity: .warn)
    }

    private func osVersionCheck() -> Check {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let label = "macOS \(v.majorVersion).\(v.minorVersion)"
        if v.majorVersion >= 14 {
            return Check(id: "os", title: label, detail: "Charging Limit available in Battery settings.", severity: .ok)
        }
        if v.majorVersion == 13 {
            return Check(id: "os", title: label, detail: "Use AlDente to cap battery at 80% (no built-in limit).", severity: .warn)
        }
        return Check(id: "os", title: label, detail: "Idle requires macOS 13 or later.", severity: .fail)
    }

    private func powerCheck() -> Check {
        let onAC = isOnAC()
        if onAC {
            return Check(id: "power", title: "On AC power", detail: "Required for 24/7 operation. Set Charging Limit to 80% to protect battery.", severity: .ok)
        }
        return Check(id: "power", title: "On battery", detail: "Plug in. Running 24/7 on battery destroys the cell within months.", severity: .warn)
    }

    private func isOnAC() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []
        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
               let state = info[kIOPSPowerSourceStateKey] as? String {
                if state == kIOPSACPowerValue { return true }
            }
        }
        return false
    }

    private func vpnCheck() -> Check {
        // VPN tunnels appear as utun*/ipsec*/ppp* interfaces — but on a normal
        // Mac, utun* interfaces are also used for iCloud Continuity, AirDrop,
        // Personal Hotspot, and Apple system networking. They show up as
        // UP+RUNNING but carry no real IPv4 traffic.
        //
        // Real-VPN heuristic: a tunnel interface that ALSO has a non-link-local
        // IPv4 address bound to it. macOS's internal utuns get IPv6 only or
        // link-local IPv4. A real VPN client (Tailscale, ProtonVPN, NordVPN,
        // corporate IPsec, etc.) assigns a routable IPv4 to its interface.
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let first = ifaddrs else {
            return Check(id: "vpn", title: "Network status unavailable", detail: "Couldn't enumerate interfaces.", severity: .warn)
        }
        defer { freeifaddrs(ifaddrs) }

        var hasVPN = false
        var vpnInterface = ""
        var ptr = first
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            let isTunnel = name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            if isTunnel,
               let addr = ptr.pointee.ifa_addr,
               addr.pointee.sa_family == sa_family_t(AF_INET) {
                // Tunnel has a real IPv4 address — almost certainly a VPN.
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                               &hostBuf, socklen_t(hostBuf.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let ipString = String(cString: hostBuf)
                    // Skip link-local (169.254.x.x) which can appear briefly.
                    if !ipString.hasPrefix("169.254.") {
                        hasVPN = true
                        vpnInterface = "\(name) (\(ipString))"
                        break
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        if hasVPN {
            return Check(id: "vpn", title: "VPN active on \(vpnInterface)", detail: "Disable VPN before running DePIN apps. They ban datacenter/VPN IPs instantly.", severity: .fail)
        }
        return Check(id: "vpn", title: "No VPN active", detail: "Good. DePIN apps require a residential IP.", severity: .ok)
    }

    private func ipCheck() async -> Check? {
        guard let url = URL(string: "https://ipapi.co/json/") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let info = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let org = (info["org"] as? String) ?? ""
            let ip = (info["ip"] as? String) ?? "unknown"
            let city = (info["city"] as? String) ?? ""
            let region = (info["region"] as? String) ?? ""

            // Heuristic: residential ISPs include "comcast", "spectrum", "verizon",
            // "at&t", "charter", "cox", "centurylink", etc. Datacenter ASNs include
            // "amazon", "google", "linode", "digitalocean", "ovh", "hetzner".
            let datacenterMarkers = ["amazon", "google", "linode", "digitalocean", "ovh", "hetzner", "vultr", "azure", "aws"]
            let lower = org.lowercased()
            if datacenterMarkers.contains(where: { lower.contains($0) }) {
                return Check(id: "ip", title: "Datacenter IP detected", detail: "\(ip) — \(org). DePIN apps will reject this. Switch to home Wi-Fi.", severity: .fail)
            }
            return Check(id: "ip", title: "\(ip) — \(city), \(region)", detail: "\(org)", severity: .ok)
        } catch {
            return Check(id: "ip", title: "IP check failed", detail: "Couldn't reach ipapi.co. Skipping.", severity: .warn)
        }
    }
}
