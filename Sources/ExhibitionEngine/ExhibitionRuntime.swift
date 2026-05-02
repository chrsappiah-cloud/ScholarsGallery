import Foundation
import CoreModels

public struct ExhibitionRuntimeState: Sendable {
    public let manifest: RoomManifest
    public var currentRoomID: String

    public init(manifest: RoomManifest, currentRoomID: String) {
        self.manifest = manifest
        self.currentRoomID = currentRoomID
    }

    public mutating func transition(to roomID: String) -> Bool {
        guard let room = manifest.rooms.first(where: { $0.id == currentRoomID }) else { return false }
        guard room.transitions.contains(roomID) else { return false }
        currentRoomID = roomID
        return true
    }
}
