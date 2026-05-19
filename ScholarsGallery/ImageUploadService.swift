import Combine
import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class ImageUploadService: ObservableObject {
    static let shared = ImageUploadService()

    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var uploadedImages: [UploadedImageRecord] = []
    @Published var isUploading = false
    @Published var uploadError: String?

    private let uploadSession = AppHTTPSession.shared

    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UserUploads", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        loadLocalRecords()
    }

    func processSelectedItems() async {
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        for item in selectedItems {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }

            let id = UUID()
            let filename = "\(id.uuidString).jpg"
            let thumbnailFilename = "\(id.uuidString)-thumb.jpg"
            let localURL = documentsURL.appendingPathComponent(filename)
            let thumbnailURL = documentsURL.appendingPathComponent(thumbnailFilename)

            do {
                let preparedAssets = try await Task.detached(priority: .userInitiated) {
                    try GalleryImageProcessing.prepareAssets(from: data)
                }.value

                try preparedAssets.uploadData.write(to: localURL, options: .atomic)
                try preparedAssets.thumbnailData.write(to: thumbnailURL, options: .atomic)
                let record = UploadedImageRecord(
                    id: id,
                    localFilename: filename,
                    thumbnailFilename: thumbnailFilename,
                    uploadedAt: Date(),
                    syncedToServer: false,
                    serverURL: nil
                )
                uploadedImages.insert(record, at: 0)
                saveLocalRecords()
                await syncToServer(record: record, data: preparedAssets.uploadData)
            } catch {
                uploadError = "Failed to save image: \(error.localizedDescription)"
            }
        }
        selectedItems = []
    }

    func imageURL(for record: UploadedImageRecord) -> URL {
        documentsURL.appendingPathComponent(record.localFilename)
    }

    func previewImageURL(for record: UploadedImageRecord) -> URL {
        if let thumbnailFilename = record.thumbnailFilename {
            let thumbnailURL = documentsURL.appendingPathComponent(thumbnailFilename)
            if FileManager.default.fileExists(atPath: thumbnailURL.path) {
                return thumbnailURL
            }
        }
        return imageURL(for: record)
    }

    func syncPendingUploads() async {
        for record in uploadedImages where !record.syncedToServer {
            let url = documentsURL.appendingPathComponent(record.localFilename)
            guard let data = try? Data(contentsOf: url) else { continue }
            await syncToServer(record: record, data: data)
        }
    }

    private func syncToServer(record: UploadedImageRecord, data: Data) async {
        let baseURL = GalleryAPIConfiguration.baseURL
        var request = URLRequest(url: baseURL.appendingPathComponent("api/collection/upload"))
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"artworkId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(record.id.uuidString)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(record.localFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (responseData, response) = try await uploadSession.upload(for: request, from: body)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            if let serverResponse = try? JSONDecoder().decode(UploadResponse.self, from: responseData) {
                if let idx = uploadedImages.firstIndex(where: { $0.id == record.id }) {
                    uploadedImages[idx].syncedToServer = true
                    uploadedImages[idx].serverURL = serverResponse.imageURL
                    saveLocalRecords()
                }
            }
        } catch {
            // Will retry on next sync pass
        }
    }

    private func loadLocalRecords() {
        let recordsURL = documentsURL.appendingPathComponent("records.json")
        guard let data = try? Data(contentsOf: recordsURL),
              let records = try? JSONDecoder().decode([UploadedImageRecord].self, from: data) else {
            return
        }
        uploadedImages = records
    }

    private func saveLocalRecords() {
        let recordsURL = documentsURL.appendingPathComponent("records.json")
        guard let data = try? JSONEncoder().encode(uploadedImages) else { return }
        try? data.write(to: recordsURL)
    }
}

struct UploadedImageRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let localFilename: String
    let thumbnailFilename: String?
    let uploadedAt: Date
    var syncedToServer: Bool
    var serverURL: String?
}

private struct UploadResponse: Decodable {
    let imageURL: String
}
