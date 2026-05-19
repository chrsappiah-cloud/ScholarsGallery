import Foundation
import ImageIO
import Testing
import UIKit
@testable import ScholarsGallery

@Suite("Generated Artwork History Cache")
struct GeneratedArtworkHistoryCacheTests {
    @Test
    func mergeKeepsNewestEntryFirstAndDeduplicates() {
        let cache = GeneratedArtworkHistoryCache()
        let sharedID = UUID()
        let older = GeneratedArtwork(
            id: sharedID,
            status: "completed",
            imageURL: "https://example.com/older.jpg",
            prompt: "Older",
            provider: "mock",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let other = GeneratedArtwork(
            id: UUID(),
            status: "completed",
            imageURL: "https://example.com/other.jpg",
            prompt: "Other",
            provider: "mock",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let newer = GeneratedArtwork(
            id: sharedID,
            status: "completed",
            imageURL: "https://example.com/newer.jpg",
            prompt: "Newer",
            provider: "openai",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let merged = cache.merge(newer, into: [older, other], limit: 20)

        #expect(merged.count == 2)
        #expect(merged[0].prompt == "Newer")
        #expect(merged.filter { $0.id == sharedID }.count == 1)
    }

    @Test
    func saveAndLoadRoundTripUsesExpectedCacheKey() {
        let suiteName = "ScholarsGalleryTests.generated-cache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let cache = GeneratedArtworkHistoryCache(cache: AppJSONCache(defaults: defaults))
        let records = [
            GeneratedArtwork(
                id: UUID(),
                status: "completed",
                imageURL: "https://example.com/image.jpg",
                prompt: "Cached prompt",
                provider: "mock",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]

        cache.save(records, limit: 50)
        let loaded = cache.load(limit: 50)

        #expect(loaded?.count == 1)
        #expect(loaded?.first?.prompt == "Cached prompt")
    }
}

@Suite("Gallery Image Processing")
struct GalleryImageProcessingTests {
    @Test
    func prepareAssetsCreatesDownsampledUploadAndThumbnail() throws {
        let sourceData = makeJPEG(width: 3200, height: 2400)

        let prepared = try GalleryImageProcessing.prepareAssets(
            from: sourceData,
            maxUploadDimension: 2048,
            thumbnailDimension: 480,
            compressionQuality: 0.82
        )

        let uploadSize = try pixelSize(for: prepared.uploadData)
        let thumbnailSize = try pixelSize(for: prepared.thumbnailData)

        #expect(max(uploadSize.width, uploadSize.height) <= 2048)
        #expect(max(thumbnailSize.width, thumbnailSize.height) <= 480)
        #expect(prepared.thumbnailData.count < prepared.uploadData.count)
    }

    private func makeJPEG(width: CGFloat, height: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            for row in stride(from: 0, to: Int(height), by: 40) {
                UIColor(
                    hue: CGFloat(row % 360) / 360,
                    saturation: 0.9,
                    brightness: 0.95,
                    alpha: 1
                ).setFill()
                context.fill(CGRect(x: 0, y: CGFloat(row), width: width, height: 20))
            }
        }
        return image.jpegData(compressionQuality: 0.95)!
    }

    private func pixelSize(for data: Data) throws -> CGSize {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            throw CocoaError(.coderReadCorrupt)
        }

        return CGSize(width: width, height: height)
    }
}
