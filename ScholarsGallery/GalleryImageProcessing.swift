import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum GalleryImageProcessing {
    struct PreparedAssets {
        let uploadData: Data
        let thumbnailData: Data
    }

    static func prepareAssets(
        from sourceData: Data,
        maxUploadDimension: Int = 2048,
        thumbnailDimension: Int = 480,
        compressionQuality: Double = 0.82
    ) throws -> PreparedAssets {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil) else {
            throw CocoaError(.coderReadCorrupt)
        }

        let uploadData = try makeJPEGData(
            from: source,
            maxPixelSize: max(1, maxUploadDimension),
            compressionQuality: compressionQuality
        )
        let thumbnailData = try makeJPEGData(
            from: source,
            maxPixelSize: max(1, thumbnailDimension),
            compressionQuality: compressionQuality
        )

        return PreparedAssets(uploadData: uploadData, thumbnailData: thumbnailData)
    }

    private static func makeJPEGData(
        from source: CGImageSource,
        maxPixelSize: Int,
        compressionQuality: Double
    ) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CocoaError(.coderReadCorrupt)
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return output as Data
    }
}
