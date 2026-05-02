//
//  ScholarsGalleryApp.swift
//  ScholarsGallery
//
//  Created by Christopher Appiah-Thompson  on 30/4/2026.
//

import SwiftUI
import SwiftData

@main
struct ScholarsGalleryApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try GalleryPersistence.makeContainer()
        } catch {
            modelContainer = try! GalleryPersistence.makeFallbackContainer()
        }
        _ = ICloudKeyValueSync.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(GalleryTheme.accent)
        }
        .modelContainer(modelContainer)
    }
}
