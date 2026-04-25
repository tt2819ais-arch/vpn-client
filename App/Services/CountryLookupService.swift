import Foundation

public actor CountryLookupService {

    public init() {}

    private struct IPInfo: Decodable {
        let country: String?
        let country_code: String?
    }

    /// Returns "🇷🇺 RU" style label, or nil on failure.
    /// Uses ip-api.com — no API key required, IPv4 only.
    public func lookup() async -> String? {
        let url = URL(string: "https://ipwho.is/?fields=country,country_code")!
        var req = URLRequest(url: url, timeoutInterval: 6)
        req.setValue("Mozilla/5.0 VPNClient", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let info = try JSONDecoder().decode(IPInfo.self, from: data)
            let code = info.country_code?.uppercased() ?? ""
            let flag = flag(for: code)
            if let country = info.country, !country.isEmpty {
                return "\(flag) \(country) (\(code))"
            }
            return flag.isEmpty ? code : "\(flag) \(code)"
        } catch {
            return nil
        }
    }

    private func flag(for code: String) -> String {
        guard code.count == 2 else { return "" }
        let base: UInt32 = 127397
        var result = ""
        for scalar in code.unicodeScalars {
            if let s = UnicodeScalar(base + scalar.value) {
                result.unicodeScalars.append(s)
            }
        }
        return result
    }
}
