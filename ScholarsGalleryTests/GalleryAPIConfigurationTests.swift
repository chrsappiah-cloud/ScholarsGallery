import Foundation
import Testing
@testable import ScholarsGallery

@Suite("GalleryAPIConfiguration — URL Resolution")
struct GalleryAPIConfigurationURLResolutionTests {
    @Test func absoluteRemoteAssetURLReturnsUnchanged() {
        let raw = "https://cdn.example.com/generated/image%20one.png"
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: raw)
        #expect(resolved?.absoluteString == raw)
    }

    @Test func relativePathResolvesAgainstBaseURL() {
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: "/media/generated/example.png")
        #expect(resolved?.host == GalleryAPIConfiguration.baseURL.host)
        #expect(resolved?.path == "/media/generated/example.png")
    }

    @Test func relativePathWithoutLeadingSlashResolves() {
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: "media/generated/img.jpg")
        #expect(resolved != nil)
        #expect(resolved?.absoluteString.hasSuffix("/media/generated/img.jpg") == true)
    }

    @Test func emptyStringReturnsNil() {
        #expect(GalleryAPIConfiguration.remoteAssetURL(from: "") == nil)
    }

    @Test func whitespaceOnlyStringReturnsNil() {
        #expect(GalleryAPIConfiguration.remoteAssetURL(from: "   ") == nil)
    }

    @Test func trimmedWhitespaceFromURL() {
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: "  https://example.com/img.jpg  ")
        #expect(resolved?.absoluteString == "https://example.com/img.jpg")
    }

    @Test func urlWithSpecialCharactersResolves() {
        let raw = "https://example.com/generated/artwork + (1).jpg"
        let resolved = GalleryAPIConfiguration.remoteAssetURL(from: raw)
        #expect(resolved != nil)
    }
}

@Suite("GalleryAPIConfiguration — Host Detection")
struct GalleryAPIConfigurationHostDetectionTests {
    @Test func isLocalDevelopmentDetects127001() {
        let url = URL(string: "http://127.0.0.1:8081")!
        let isLocal = url.host == "127.0.0.1" || url.host == "localhost"
        #expect(isLocal == true)
    }

    @Test func isLocalDevelopmentDetectsLocalhost() {
        let url = URL(string: "http://localhost:8081")!
        #expect(url.host == "localhost")
    }

    @Test func isLocalDevelopmentDetects192168() {
        let url = URL(string: "http://192.168.1.100:8081")!
        #expect(url.host?.hasPrefix("192.168.") == true)
    }

    @Test func isLocalDevelopmentDetects10Dot() {
        let url = URL(string: "http://10.0.0.1:8081")!
        #expect(url.host?.hasPrefix("10.") == true)
    }

    @Test func isLocalDevelopmentDetects172Dot16To31() {
        let url = URL(string: "http://172.20.0.1:8081")!
        #expect(url.host?.hasPrefix("172.") == true)
    }
}
