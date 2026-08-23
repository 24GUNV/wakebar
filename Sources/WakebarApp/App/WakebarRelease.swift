import Foundation

enum WakebarRelease {
    static let releasesURL: URL = {
        guard let url = URL(string: "https://github.com/24GUNV/wakebar/releases") else {
            preconditionFailure("The Wakebar releases URL is invalid.")
        }
        return url
    }()

    static var currentVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        return version ?? "Development"
    }
}
