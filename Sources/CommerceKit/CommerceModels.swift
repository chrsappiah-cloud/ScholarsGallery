import Foundation
import CoreModels

public struct EditionListing: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let artworkID: UUID
    public let editionNumber: Int
    public let editionSize: Int
    public let priceMinor: Int
    public let currency: String

    public init(
        id: UUID = UUID(),
        artworkID: UUID,
        editionNumber: Int,
        editionSize: Int,
        priceMinor: Int,
        currency: String
    ) {
        self.id = id
        self.artworkID = artworkID
        self.editionNumber = editionNumber
        self.editionSize = editionSize
        self.priceMinor = priceMinor
        self.currency = currency
    }
}

public struct CheckoutResponse: Codable, Hashable, Sendable {
    public let checkoutURL: String

    public init(checkoutURL: String) {
        self.checkoutURL = checkoutURL
    }
}
