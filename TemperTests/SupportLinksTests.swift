import Foundation
import Testing

@testable import Temper

struct SupportLinksTests {
    private func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test
    func `The support email goes to the support address`() throws {
        let url = try #require(SupportLinks.email(version: "1.0", build: "7", systemVersion: "27.2"))

        #expect(url.scheme == "mailto")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == SupportLinks.address)
    }

    @Test
    func `The support email names the version, build and iOS version`() throws {
        let url = try #require(SupportLinks.email(version: "1.0", build: "7", systemVersion: "27.2"))

        #expect(query(url)["subject"] == "Temper 1.0 (7)")
        #expect(query(url)["body"]?.hasSuffix("iOS 27.2") == true)
    }

    @Test
    func `The privacy policy is a web page served over HTTPS`() throws {
        let url = try #require(SupportLinks.privacyPolicy)
        #expect(url.scheme == "https")
        #expect(url.host() != nil)
    }
}
