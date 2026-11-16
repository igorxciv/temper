import Foundation

/// Where Settings sends someone for the privacy policy or for help. The pages come from `site/`, which the Pages
/// workflow publishes.
enum SupportLinks {
    static let address = "support@temper.example"
    /// Optional only because `URL(string:)` is; the tests hold it to a real address.
    static let privacyPolicy = URL(string: "https://igorxciv.github.io/temper/privacy/")

    /// A new email to support, its subject naming the app's version and build, and its body the iPhone's iOS version,
    /// so a report arrives with what's needed to reproduce it.
    static func email(version: String, build: String, systemVersion: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Temper \(version) (\(build))"),
            URLQueryItem(name: "body", value: "\n\n—\niOS \(systemVersion)"),
        ]
        return components.url
    }
}
