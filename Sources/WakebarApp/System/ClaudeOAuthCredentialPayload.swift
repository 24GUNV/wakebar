import Foundation

struct ClaudeOAuthCredentialPayload: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Date?

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case expiresAt
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try values.decodeIfPresent(String.self, forKey: .accessToken)
        refreshToken = try values.decodeIfPresent(String.self, forKey: .refreshToken)

        if let rawValue = try? values.decode(Double.self, forKey: .expiresAt) {
            let seconds = rawValue > 10_000_000_000 ? rawValue / 1_000 : rawValue
            expiresAt = Date(timeIntervalSince1970: seconds)
        } else if let value = try? values.decode(String.self, forKey: .expiresAt) {
            expiresAt = try? Date(value, strategy: .iso8601)
        } else {
            expiresAt = nil
        }
    }
}
