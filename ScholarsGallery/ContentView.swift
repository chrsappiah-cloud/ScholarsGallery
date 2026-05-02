import SwiftUI
import SwiftData
import Foundation
import Combine

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}

private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @StateObject private var collectionStore = CollectionStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var galleryBackendMeta = GalleryBackendMetaModel()
    @State private var hasRestoredBackup = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(String(localized: "tab.exhibitions"), systemImage: "square.grid.2x2")
                }
            GenerationStudioView()
                .tabItem {
                    Label(String(localized: "tab.studio"), systemImage: "sparkles.rectangle.stack")
                }
            ScholarshipHomeView()
                .tabItem {
                    Label(String(localized: "tab.scholarship"), systemImage: "book.closed")
                }
            CollectorLibraryView()
                .tabItem {
                    Label(String(localized: "tab.collection"), systemImage: "rectangle.stack")
                }
        }
        .environmentObject(collectionStore)
        .environmentObject(favoritesStore)
        .environmentObject(galleryBackendMeta)
        .task {
            await galleryBackendMeta.refresh()
            guard !hasRestoredBackup else { return }
            hasRestoredBackup = true
            await restoreFromAllBackups()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await galleryBackendMeta.refresh() }
            }
            guard phase == .background else { return }
            Task { await performFullBackup() }
        }
    }

    private func restoreFromAllBackups() async {
        if let legacy = try? await CloudBackupService.shared.fetchLatestSnapshot() {
            collectionStore.restore(rawRecords: legacy.collectionRaw)
            favoritesStore.restore(rawIDs: legacy.favoritesRaw)
        }

        await CloudKitSyncManager.shared.restoreIntoSwiftData(context: modelContext)
        syncSwiftDataToStores()
    }

    private func syncSwiftDataToStores() {
        let collectionRecords = (try? modelContext.fetch(FetchDescriptor<PersistedCollectionRecord>())) ?? []
        for record in collectionRecords {
            if collectionStore.recordsByArtworkID[record.artworkID] == nil {
                collectionStore.restoreSingle(artworkID: record.artworkID,
                                               acquiredAt: record.acquiredAt,
                                               certificateID: record.certificateID)
            }
        }

        let favorites = (try? modelContext.fetch(FetchDescriptor<PersistedFavorite>())) ?? []
        for fav in favorites {
            if !favoritesStore.isFavoriteByString(artworkID: fav.artworkID) {
                favoritesStore.insertFavorite(artworkID: fav.artworkID)
            }
        }
    }

    private func performFullBackup() async {
        let legacySnapshot = BackupSnapshot(
            collectionRaw: collectionStore.exportRawRecords(),
            favoritesRaw: favoritesStore.exportRawIDs(),
            modifiedAt: Date()
        )
        try? await CloudBackupService.shared.upload(snapshot: legacySnapshot)

        persistStoresToSwiftData()

        let allRecords = (try? modelContext.fetch(FetchDescriptor<PersistedCollectionRecord>())) ?? []
        await CloudKitSyncManager.shared.syncCollectionRecords(allRecords)
        await CloudKitSyncManager.shared.syncFavorites(favoritesStore.favoriteArtworkIDs)

        for record in allRecords where !record.syncedToCloud {
            record.syncedToCloud = true
        }
        try? modelContext.save()

        ICloudKeyValueSync.shared.updateCountSnapshots(
            favorites: favoritesStore.favoriteArtworkIDs.count,
            collection: collectionStore.recordsByArtworkID.count
        )

        ICloudDocumentBackup.exportSnapshot(context: modelContext)
    }

    private func persistStoresToSwiftData() {
        for (artworkID, record) in collectionStore.recordsByArtworkID {
            let descriptor = FetchDescriptor<PersistedCollectionRecord>(
                predicate: #Predicate { $0.artworkID == artworkID }
            )
            if (try? modelContext.fetch(descriptor))?.first == nil {
                modelContext.insert(PersistedCollectionRecord(
                    artworkID: artworkID,
                    acquiredAt: record.acquiredAt,
                    certificateID: record.certificateID
                ))
            }
        }

        for artworkID in favoritesStore.favoriteArtworkIDs {
            let descriptor = FetchDescriptor<PersistedFavorite>(
                predicate: #Predicate { $0.artworkID == artworkID }
            )
            if (try? modelContext.fetch(descriptor))?.first == nil {
                modelContext.insert(PersistedFavorite(artworkID: artworkID))
            }
        }

        try? modelContext.save()
    }
}

@MainActor
private struct HomeView: View {
    @EnvironmentObject private var galleryBackendMeta: GalleryBackendMetaModel
    @StateObject private var vm = ExhibitionListViewModel()
    @State private var showAdministratorPanel = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.exhibitions.isEmpty {
                    ProgressView(String(localized: "home.loadingExhibitions"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.exhibitions.isEmpty {
                    ContentUnavailableView(
                        String(localized: "home.unableToLoadExhibitions"),
                        systemImage: "wifi.exclamationmark",
                        description: Text(error)
                    )
                } else if vm.exhibitions.isEmpty {
                    ContentUnavailableView(
                        String(localized: "home.noExhibitionsAvailable"),
                        systemImage: "rectangle.stack.badge.person.crop"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if let notice = galleryBackendMeta.meta?.announcement?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !notice.isEmpty {
                                Text(notice)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(GalleryTheme.sapphireDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(GalleryTheme.roseSoft.opacity(0.65))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(GalleryTheme.rose.opacity(0.35), lineWidth: 1)
                                            )
                                    )
                            }
                            ForEach(vm.exhibitions) { exhibition in
                                NavigationLink(value: exhibition) {
                                    ExhibitionCard(exhibition: exhibition)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "app.brandName"))
            .navigationDestination(for: Exhibition.self) { exhibition in
                ExhibitionDetailView(exhibition: exhibition)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let meta = galleryBackendMeta.meta {
                        Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(
                                String(
                                    format: String(localized: "api.meta.detailFormat"),
                                    meta.version,
                                    meta.catalog,
                                    meta.persistence
                                )
                            )
                    } else if galleryBackendMeta.lastRefreshFailed {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel(String(localized: "api.meta.unreachable"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Menu {
                            Button {
                                Task {
                                    await galleryBackendMeta.refresh()
                                    await vm.load()
                                }
                            } label: {
                                Label(String(localized: "common.refresh"), systemImage: "arrow.clockwise")
                            }
                            Button {
                                showAdministratorPanel = true
                            } label: {
                                Label(String(localized: "admin.openPanel"), systemImage: "gearshape.2")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("home.overflowMenu")
                    }
                }
            }
            .sheet(isPresented: $showAdministratorPanel) {
                AdministratorControlPanelView()
                    .environmentObject(galleryBackendMeta)
            }
            .task {
                await vm.load()
            }
        }
    }
}

@MainActor
private final class ExhibitionListViewModel: ObservableObject {
    @Published var exhibitions: [Exhibition] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    private let api: GalleryAPIClientProtocol

    init(api: GalleryAPIClientProtocol) {
        self.api = api
    }

    convenience init() {
        self.init(api: GalleryAPIClient.live)
    }

    func load() async {
        if let json = ProcessInfo.processInfo.environment["UITEST_EXHIBITIONS_JSON"],
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Exhibition].self, from: data) {
            exhibitions = decoded
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            exhibitions = try await api.fetchExhibitions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExhibitionCard: View {
    let exhibition: Exhibition

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GalleryTheme.heroCardGradient)
                .frame(height: 228)
                .overlay {
                    SparkleJewelOverlay()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay {
                    LinearGradient(
                        colors: [GalleryTheme.ink.opacity(0.88), .clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(exhibition.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(exhibition.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
        }
        .galleryCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exhibition.title). \(exhibition.subtitle)")
        .accessibilityIdentifier("home.exhibitionCard.\(exhibition.id.uuidString)")
    }
}

@MainActor
private struct ExhibitionDetailView: View {
    let exhibition: Exhibition
    @StateObject private var vm: ExhibitionDetailViewModel
    @State private var segment = 0

    init(exhibition: Exhibition, api: GalleryAPIClientProtocol) {
        self.exhibition = exhibition
        _vm = StateObject(wrappedValue: ExhibitionDetailViewModel(exhibition: exhibition, api: api))
    }

    init(exhibition: Exhibition) {
        self.init(exhibition: exhibition, api: GalleryAPIClient.live)
    }

    var body: some View {
        ZStack {
            GalleryAppBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                ExhibitionHeader(exhibition: exhibition)
                Picker("", selection: $segment) {
                    Text(String(localized: "detail.segmentExperience")).tag(0)
                    Text(String(localized: "detail.segmentWorks")).tag(1)
                    Text(String(localized: "detail.segmentEssay")).tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch segment {
                case 0:
                    ExhibitionExperienceView(manifest: vm.manifest, isLoading: vm.isLoading)
                case 1:
                    ArtworkGridView(artworks: vm.artworks, isLoading: vm.isLoading, errorMessage: vm.errorMessage)
                default:
                    ScholarlyEssayView(essay: vm.essay, isLoading: vm.isLoading)
                }
            }
        }
        .navigationTitle(exhibition.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }
}

private struct ExhibitionHeader: View {
    let exhibition: Exhibition

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(GalleryTheme.headerGradient)
                .frame(height: 248)
                .overlay {
                    SparkleJewelOverlay()
                        .padding(.horizontal, 8)
                }
                .overlay {
                    LinearGradient(colors: [.clear, GalleryTheme.ink.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(exhibition.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text(exhibition.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(20)
        }
    }
}

@MainActor
private final class ExhibitionDetailViewModel: ObservableObject {
    let exhibition: Exhibition
    @Published var manifest: RoomManifest?
    @Published var essay: ScholarlyEssay?
    @Published var artworks: [ArtworkPackage] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    private let api: GalleryAPIClientProtocol

    init(exhibition: Exhibition, api: GalleryAPIClientProtocol) {
        self.exhibition = exhibition
        self.api = api
    }

    convenience init(exhibition: Exhibition) {
        self.init(exhibition: exhibition, api: GalleryAPIClient.live)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let url = exhibition.manifestURL {
                manifest = try await api.fetchManifest(from: url)
                if let firstEssay = manifest?.rooms.compactMap(\.wallEssayID).first {
                    essay = try await api.fetchEssay(id: firstEssay)
                }
            }
            artworks = try await api.fetchArtworks(exhibitionSlug: exhibition.slug)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            artworks = []
        }
    }
}

private struct ExhibitionExperienceView: View {
    let manifest: RoomManifest?
    let isLoading: Bool

    var body: some View {
        if let manifest {
            TabView {
                ForEach(manifest.rooms, id: \.id) { room in
                    ZStack {
                        GalleryTheme.roomCarouselGradient
                            .ignoresSafeArea()
                        SparkleJewelOverlay()
                            .opacity(0.85)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(room.title)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text(room.kind.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(GalleryTheme.roseSoft.opacity(0.95))
                            Spacer()
                        }
                        .padding(24)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        } else {
            if isLoading {
                ProgressView(String(localized: "detail.loadingExperience"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(String(localized: "detail.noRoomExperience"), systemImage: "view.3d")
            }
        }
    }
}

private struct ArtworkGridView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let artworks: [ArtworkPackage]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(String(localized: "works.loadingWorks"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, artworks.isEmpty {
                ContentUnavailableView(
                    String(localized: "works.unableToLoadWorks"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if artworks.isEmpty {
                ContentUnavailableView(String(localized: "works.noWorksInExhibition"), systemImage: "photo.on.rectangle")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(artworks) { artwork in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink {
                                    ArtworkDetailView(artwork: artwork)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        AsyncImage(url: artwork.displayManifest.thumbnailURL) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(maxWidth: .infinity, minHeight: 140)
                                            case .success(let image):
                                                image.resizable().scaledToFill().frame(height: 140).clipped()
                                                    .accessibilityLabel(artwork.title)
                                            case .failure:
                                                Color.gray.opacity(0.2).frame(height: 140)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        Text(artwork.title)
                                            .font(.headline)
                                            .lineLimit(2)
                                            .foregroundStyle(.primary)
                                        Text(artwork.tags.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(GalleryTheme.card)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                                            )
                                    )
                                    .galleryCardShadow()
                                }
                                .buttonStyle(.plain)

                                Button {
                                    favoritesStore.toggle(artworkID: artwork.id)
                                } label: {
                                    Image(systemName: favoritesStore.isFavorite(artworkID: artwork.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(favoritesStore.isFavorite(artworkID: artwork.id) ? GalleryTheme.rose : GalleryTheme.sapphire)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                                .accessibilityIdentifier("works.favorite.\(artwork.id.uuidString)")
                                .accessibilityLabel(favoritesStore.isFavorite(artworkID: artwork.id)
                                    ? "Remove from favorites: \(artwork.title)"
                                    : "Save to favorites: \(artwork.title)")
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

private struct ArtworkDetailView: View {
    @EnvironmentObject private var collectionStore: CollectionStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let artwork: ArtworkPackage
    @State private var checkoutMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: artwork.displayManifest.heroAssetURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                    case .success(let image):
                        image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel(artwork.title)
                    case .failure:
                        Color.gray.opacity(0.2).frame(height: 220)
                    @unknown default:
                        EmptyView()
                    }
                }

                Text(artwork.title)
                    .font(.title2.bold())
                Text(.init(artwork.displayManifest.wallLabelMarkdown))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let edition = artwork.edition {
                    Button(String(format: String(localized: "artwork.acquireEdition"), edition.number, edition.total)) {
                        Task {
                            switch await GalleryAPI.performCheckout() {
                            case .success(let message):
                                checkoutMessage = message
                                collectionStore.add(artworkID: artwork.id)
                            case .policyBlocked:
                                checkoutMessage = String(localized: "checkout.policyBlocked")
                            case .failed:
                                checkoutMessage = String(localized: "checkout.currentlyUnavailable")
                            }
                        }
                    }
                    .buttonStyle(GalleryProminentButtonStyle())

                    Button(favoritesStore.isFavorite(artworkID: artwork.id) ? String(localized: "artwork.removeFavorite") : String(localized: "artwork.saveToFavorites")) {
                        favoritesStore.toggle(artworkID: artwork.id)
                    }
                    .buttonStyle(.bordered)

                    if !checkoutMessage.isEmpty {
                        Text(checkoutMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(GalleryAppBackground().ignoresSafeArea())
        .navigationTitle(String(localized: "artwork.navTitle"))
    }
}

private struct ScholarlyEssayView: View {
    let essay: ScholarlyEssay?
    let isLoading: Bool

    var body: some View {
        ScrollView {
            if let essay {
                VStack(alignment: .leading, spacing: 12) {
                    Text(essay.title).font(.title3.bold())
                    Text(String(format: String(localized: "essay.byAuthor"), essay.author)).font(.subheadline).foregroundStyle(.secondary)
                    Text(.init(essay.markdownBody))
                    if !essay.references.isEmpty {
                        Divider()
                        Text(String(localized: "essay.references")).font(.headline)
                        ForEach(essay.references, id: \.self) { ref in
                            Text("• \(ref)")
                        }
                    }
                }
                .padding()
            } else {
                if isLoading {
                    ProgressView(String(localized: "essay.loading"))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    ContentUnavailableView(String(localized: "essay.noEssayAvailable"), systemImage: "text.book.closed")
                }
            }
        }
    }
}

@MainActor
private struct ScholarshipHomeView: View {
    @StateObject private var vm = ScholarshipViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView(String(localized: "scholarship.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.essays.isEmpty {
                    ContentUnavailableView(
                        String(localized: "scholarship.unableToLoad"),
                        systemImage: "exclamationmark.circle",
                        description: Text(error)
                    )
                } else if vm.essays.isEmpty {
                    ContentUnavailableView(String(localized: "scholarship.noEssays"), systemImage: "book.closed")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(vm.essays) { essay in
                                NavigationLink {
                                    ScholarshipDetailView(summary: essay)
                                } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "book.pages.fill")
                                            .font(.title2)
                                            .foregroundStyle(GalleryTheme.accent)
                                            .frame(width: 44, height: 44)
                                            .background(GalleryTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(essay.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                            Text(essay.author)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(GalleryTheme.sapphire.opacity(0.45))
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(GalleryTheme.card)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                                            )
                                    )
                                    .galleryCardShadow()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "scholarship.navTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Label(String(localized: "scholarship.refresh"), systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("scholarship.refreshButton")
                }
            }
            .task { await vm.load() }
        }
    }
}

@MainActor
private struct CollectorLibraryView: View {
    @EnvironmentObject private var collectionStore: CollectionStore
    @StateObject private var vm = CollectorLibraryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView(String(localized: "collection.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let owned = vm.artworks.filter { collectionStore.recordsByArtworkID[$0.id.uuidString] != nil }
                    if owned.isEmpty {
                        ContentUnavailableView(
                            String(localized: "collection.emptyTitle"),
                            systemImage: "shippingbox",
                            description: Text(String(localized: "collection.emptyDescription"))
                        )
                    } else {
                        List(owned) { artwork in
                            if let record = collectionStore.recordsByArtworkID[artwork.id.uuidString] {
                                NavigationLink {
                                    CollectionRecordDetailView(artwork: artwork, record: record)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(artwork.title).font(.headline)
                                        Text(artwork.tags.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(String(localized: "collection.acquiredPrefix")) \(record.acquiredAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: String(localized: "collection.certificateLabel"), record.certificateID))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(GalleryTheme.card)
                                        .padding(.vertical, 4)
                                )
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "collection.navTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Label(String(localized: "collection.refresh"), systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("collection.refreshButton")
                }
            }
            .task { await vm.load() }
        }
    }
}

private struct CollectionRecordDetailView: View {
    let artwork: ArtworkPackage
    let record: CollectionRecord

    var body: some View {
        List {
            Section(String(localized: "acquisition.sectionArtwork")) {
                Text(artwork.title)
                Text(artwork.tags.joined(separator: " • "))
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "acquisition.sectionAcquisition")) {
                LabeledContent(String(localized: "acquisition.purchasedOn")) {
                    Text(record.acquiredAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent(String(localized: "acquisition.certificateId")) {
                    Text(record.certificateID)
                        .font(.footnote.monospaced())
                }
                LabeledContent(String(localized: "acquisition.editionRights")) {
                    Text(String(localized: "acquisition.editionRightsValue"))
                }
            }

            Section(String(localized: "acquisition.sectionDelivery")) {
                Label(String(localized: "delivery.iphoneAsset"), systemImage: "iphone")
                Label(String(localized: "delivery.hiResExport"), systemImage: "photo")
                Label(String(localized: "delivery.scholarshipPackage"), systemImage: "book.pages")
            }
        }
        .navigationTitle(String(localized: "acquisition.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum GalleryCheckoutResult: Equatable {
    case success(message: String)
    case policyBlocked
    case failed
}

private enum GalleryAPI {
    private static let baseURL = GalleryAPIConfiguration.baseURL
    private static let cache = GalleryCache()
    private static let generationToken: String? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GENERATION_API_TOKEN") as? String,
              !raw.isEmpty else { return nil }
        return raw
    }()

    static func fetchExhibitions() async throws -> [Exhibition] {
        do {
            let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("api/exhibitions"))
            try validate(response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([Exhibition].self, from: data)
            cache.save(decoded, for: .exhibitions)
            return decoded
        } catch {
            if let cached: [Exhibition] = cache.load(for: .exhibitions) {
                return cached
            }
            throw map(error)
        }
    }

    static func fetchManifest(from url: URL) async throws -> RoomManifest {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try validate(response)
            let decoded = try JSONDecoder().decode(RoomManifest.self, from: data)
            cache.save(decoded, for: .manifest(url.absoluteString))
            return decoded
        } catch {
            if let cached: RoomManifest = cache.load(for: .manifest(url.absoluteString)) {
                return cached
            }
            throw map(error)
        }
    }

    static func fetchEssay(id: String) async throws -> ScholarlyEssay {
        do {
            let url = baseURL.appendingPathComponent("api/essays/\(id)")
            let (data, response) = try await URLSession.shared.data(from: url)
            try validate(response)
            let decoded = try JSONDecoder().decode(ScholarlyEssay.self, from: data)
            cache.save(decoded, for: .essay(id))
            return decoded
        } catch {
            if let cached: ScholarlyEssay = cache.load(for: .essay(id)) {
                return cached
            }
            throw map(error)
        }
    }

    static func fetchArtworks(exhibitionSlug: String) async throws -> [ArtworkPackage] {
        do {
            let url = baseURL.appendingPathComponent("api/exhibitions/\(exhibitionSlug)/artworks")
            let (data, response) = try await URLSession.shared.data(from: url)
            try validate(response)
            let decoded = try JSONDecoder().decode([ArtworkPackage].self, from: data)
            cache.save(decoded, for: .artworks(exhibitionSlug))
            return decoded
        } catch {
            if let cached: [ArtworkPackage] = cache.load(for: .artworks(exhibitionSlug)) {
                return cached
            }
            throw map(error)
        }
    }

    static func fetchAllArtworks() async throws -> [ArtworkPackage] {
        let exhibitions = try await fetchExhibitions()
        guard let first = exhibitions.first else { return [] }
        return try await fetchArtworks(exhibitionSlug: first.slug)
    }

    static func performCheckout() async -> GalleryCheckoutResult {
        guard let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else { return .failed }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/checkout/\(id.uuidString)"))
        request.httpMethod = "POST"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if http.statusCode == 403 {
                return .policyBlocked
            }
            guard (200...299).contains(http.statusCode) else { return .failed }
            let payload = try JSONDecoder().decode(CheckoutResponse.self, from: data)
            let message = String(format: String(localized: "checkout.urlReady"), payload.checkoutURL)
            return .success(message: message)
        } catch {
            return .failed
        }
    }

    static func generateArtwork(prompt: String, artistID: UUID) async throws -> GeneratedArtwork {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/artworks/generate"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let generationToken {
            request.addValue(generationToken, forHTTPHeaderField: "X-Generation-Token")
        }
        request.httpBody = try JSONEncoder().encode(GenerateArtworkRequest(prompt: prompt, artistID: artistID))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GalleryAPIError.unexpected
        }
        if http.statusCode == 403 {
            throw GalleryAPIError.generationDisabledByPolicy
        }
        try validate(response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GeneratedArtwork.self, from: data)
    }

    static func fetchGeneratedArtworks(limit: Int = 20) async throws -> [GeneratedArtwork] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/artworks/generated"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(max(1, min(100, limit)))")]
        guard let url = components?.url else {
            throw GalleryAPIError.invalidGeneratedEndpoint
        }
        var request = URLRequest(url: url)
        if let generationToken {
            request.addValue(generationToken, forHTTPHeaderField: "X-Generation-Token")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GeneratedArtwork].self, from: data)
    }

    static func fetchEssaySummaries() async throws -> [ScholarlyEssaySummary] {
        do {
            let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("api/essays"))
            try validate(response)
            let decoded = try JSONDecoder().decode([ScholarlyEssaySummary].self, from: data)
            cache.save(decoded, for: .essaySummaries)
            return decoded
        } catch {
            if let cached: [ScholarlyEssaySummary] = cache.load(for: .essaySummaries) {
                return cached
            }
            throw map(error)
        }
    }

    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GalleryAPIError.serverInvalid
        }
    }

    static func map(_ error: Error) -> Error {
        if let error = error as? GalleryAPIError { return error }
        if error is DecodingError { return GalleryAPIError.decodingFailed }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return GalleryAPIError.networkCached
            default:
                return GalleryAPIError.networkConnect
            }
        }
        return GalleryAPIError.unexpected
    }
}

private protocol GalleryAPIClientProtocol {
    func fetchExhibitions() async throws -> [Exhibition]
    func fetchManifest(from url: URL) async throws -> RoomManifest
    func fetchEssay(id: String) async throws -> ScholarlyEssay
    func fetchArtworks(exhibitionSlug: String) async throws -> [ArtworkPackage]
    func fetchAllArtworks() async throws -> [ArtworkPackage]
    func fetchEssaySummaries() async throws -> [ScholarlyEssaySummary]
}

private struct GalleryAPIClient: GalleryAPIClientProtocol {
    fileprivate static let live = GalleryAPIClient()

    fileprivate func fetchExhibitions() async throws -> [Exhibition] {
        try await GalleryAPI.fetchExhibitions()
    }

    fileprivate func fetchManifest(from url: URL) async throws -> RoomManifest {
        try await GalleryAPI.fetchManifest(from: url)
    }

    fileprivate func fetchEssay(id: String) async throws -> ScholarlyEssay {
        try await GalleryAPI.fetchEssay(id: id)
    }

    fileprivate func fetchArtworks(exhibitionSlug: String) async throws -> [ArtworkPackage] {
        try await GalleryAPI.fetchArtworks(exhibitionSlug: exhibitionSlug)
    }

    fileprivate func fetchAllArtworks() async throws -> [ArtworkPackage] {
        try await GalleryAPI.fetchAllArtworks()
    }

    fileprivate func fetchEssaySummaries() async throws -> [ScholarlyEssaySummary] {
        try await GalleryAPI.fetchEssaySummaries()
    }
}

private struct Exhibition: Codable, Hashable, Identifiable {
    let id: UUID
    let slug: String
    let title: String
    let subtitle: String
    let openingDate: Date
    let manifestURL: URL?
}

private struct RoomManifest: Codable, Hashable {
    struct Lighting: Codable, Hashable {
        let preset: String
        let intensity: Double
    }

    struct Room: Codable, Hashable {
        let id: String
        let kind: String
        let title: String
        let artworkIDs: [String]
        let ambientAudio: String?
        let lighting: Lighting?
        let wallEssayID: String?
        let transitions: [String]
    }

    let exhibitionId: String
    let title: String
    let rooms: [Room]
}

private struct ScholarlyEssay: Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let markdownBody: String
    let references: [String]
}

private struct ScholarlyEssaySummary: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let author: String
}

private struct CheckoutResponse: Codable, Hashable {
    let checkoutURL: String
}

private struct GenerateArtworkRequest: Codable {
    let prompt: String
    let artistID: UUID
}

private struct GeneratedArtwork: Codable, Hashable, Identifiable {
    let id: UUID
    let status: String
    let imageURL: String
    let prompt: String
    let provider: String
    let createdAt: Date
}

private struct ArtworkPackage: Identifiable, Codable, Hashable {
    struct DisplayManifest: Codable, Hashable {
        let heroAssetURL: URL
        let thumbnailURL: URL
        let wallLabelMarkdown: String
    }

    struct Edition: Codable, Hashable {
        let number: Int
        let total: Int
    }

    let id: UUID
    let title: String
    let tags: [String]
    let displayManifest: DisplayManifest
    let edition: Edition?
}

@MainActor
private struct GenerationStudioView: View {
    @EnvironmentObject private var galleryBackendMeta: GalleryBackendMetaModel
    @StateObject private var vm = GenerationStudioViewModel()
    @State private var showDolaSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .font(.title2)
                                .foregroundStyle(GalleryTheme.accent)
                            Text(String(localized: "studio.promptLabel"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(GalleryTheme.sapphireDark)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(GalleryTheme.studioBannerGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(GalleryTheme.cardStroke.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        SparkleJewelOverlay()
                            .padding(12)
                    }

                    TextEditor(text: $vm.prompt)
                        .accessibilityIdentifier("studio.promptEditor")
                        .frame(minHeight: 150)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(GalleryTheme.sapphire.opacity(0.22), lineWidth: 1.5)
                        )
                        .galleryCardShadow()

                    if galleryBackendMeta.meta?.effectiveDolaAssistantEnabled ?? true {
                        Button {
                            showDolaSheet = true
                        } label: {
                            Label(String(localized: "studio.askDola"), systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(GalleryTheme.accent)
                        .accessibilityIdentifier("studio.askDolaButton")
                    }

                    Button {
                        Task { await vm.generate() }
                    } label: {
                        if vm.isGenerating {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(String(localized: "studio.generateArtwork"), systemImage: "wand.and.stars")
                                .labelStyle(.titleAndIcon)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityIdentifier("studio.generateButton")
                    .buttonStyle(GalleryProminentButtonStyle())
                    .disabled(
                        vm.isGenerating
                            || vm.prompt.trimmingCharacters(in: .whitespacesAndNewlines).count < 12
                            || !(galleryBackendMeta.meta?.effectiveGenerationEnabled ?? true)
                    )

                    if let error = vm.errorMessage {
                        Text(error)
                            .accessibilityIdentifier("studio.errorMessage")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let generated = vm.generated {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "studio.result"))
                                .font(.headline)
                            AsyncImage(url: URL(string: generated.imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    Color.gray.opacity(0.2)
                                        .frame(height: 220)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            Text(String(format: String(localized: "studio.providerFormat"), generated.provider))
                                .accessibilityIdentifier("studio.resultProvider")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: String(localized: "studio.statusFormat"), generated.status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(GalleryTheme.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                                )
                        )
                        .galleryCardShadow()
                    }

                    if !vm.recentGenerations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "studio.recentGenerations"))
                                .accessibilityIdentifier("studio.recentHeader")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(GalleryTheme.sapphireDark)
                            ForEach(vm.recentGenerations) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.prompt)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    Text("\(item.provider.uppercased()) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(GalleryTheme.card)
                                        .overlay(alignment: .leading) {
                                            Rectangle()
                                                .fill(GalleryTheme.rose.opacity(0.55))
                                                .frame(width: 4)
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(GalleryTheme.roseSoft.opacity(0.6), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "studio.navTitle"))
            .sheet(isPresented: $showDolaSheet) {
                DolaAssistantSheet(initialPrompt: vm.prompt) { picked in
                    vm.prompt = picked
                }
                .environmentObject(galleryBackendMeta)
            }
            .task {
                await vm.loadRecent()
            }
        }
    }
}

@MainActor
private final class GenerationStudioViewModel: ObservableObject {
    @Published var prompt = String(localized: "studio.defaultPrompt")
    @Published var generated: GeneratedArtwork?
    @Published var recentGenerations: [GeneratedArtwork] = []
    @Published var errorMessage: String?
    @Published var isGenerating = false

    private let artistID: UUID = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "DEFAULT_ARTIST_ID") as? String,
           let id = UUID(uuidString: raw) {
            return id
        }
        return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }()

    private static var uiTestGenerateMode: String? {
        ProcessInfo.processInfo.environment["UITEST_GENERATE_MODE"]
    }

    private static var uiTestRecentJSON: String? {
        ProcessInfo.processInfo.environment["UITEST_RECENT_GENERATIONS_JSON"]
    }

    func generate() async {
        if let mode = Self.uiTestGenerateMode {
            if mode == "success" {
                let now = Date()
                let mock = GeneratedArtwork(
                    id: UUID(),
                    status: "completed",
                    imageURL: "https://images.unsplash.com/photo-1518770660439-4636190af475",
                    prompt: prompt,
                    provider: "mock-ui-test",
                    createdAt: now
                )
                generated = mock
                recentGenerations.insert(mock, at: 0)
                errorMessage = nil
                return
            }
            if mode == "error" {
                generated = nil
                errorMessage = String(localized: "studio.uiTestError")
                return
            }
        }

        isGenerating = true
        defer { isGenerating = false }
        errorMessage = nil
        do {
            generated = try await GalleryAPI.generateArtwork(
                prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                artistID: artistID
            )
            await loadRecent()
        } catch let apiError as GalleryAPIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = AppAPIErrorMapper.map(error).localizedDescription
        }
    }

    func loadRecent() async {
        if let raw = Self.uiTestRecentJSON,
           let decoded = Self.decodeRecentFromUITestJSON(raw) {
            recentGenerations = decoded
            return
        }
        do {
            recentGenerations = try await GalleryAPI.fetchGeneratedArtworks(limit: 20)
        } catch {
            // Keep this non-blocking; studio still works if history endpoint is unavailable.
        }
    }

    private static func decodeRecentFromUITestJSON(_ raw: String) -> [GeneratedArtwork]? {
        guard let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([GeneratedArtwork].self, from: data)
    }
}

private enum GalleryAPIError: LocalizedError {
    case networkCached
    case networkConnect
    case serverInvalid
    case decodingFailed
    case unexpected
    case invalidGeneratedEndpoint
    case generationDisabledByPolicy

    var errorDescription: String? {
        switch self {
        case .networkCached:
            return String(localized: "error.networkCached")
        case .networkConnect:
            return String(localized: "error.networkConnect")
        case .serverInvalid:
            return String(localized: "error.serverInvalid")
        case .decodingFailed:
            return String(localized: "error.decodeFailed")
        case .unexpected:
            return String(localized: "error.unexpected")
        case .invalidGeneratedEndpoint:
            return String(localized: "error.invalidGeneratedEndpoint")
        case .generationDisabledByPolicy:
            return String(localized: "studio.policyGenerationDisabled")
        }
    }
}

private struct GalleryCache {
    enum Key {
        case exhibitions
        case artworks(String)
        case manifest(String)
        case essay(String)
        case essaySummaries

        var rawValue: String {
            switch self {
            case .exhibitions:
                return "cache.exhibitions"
            case .artworks(let slug):
                return "cache.artworks.\(slug)"
            case .manifest(let ref):
                return "cache.manifest.\(ref)"
            case .essay(let id):
                return "cache.essay.\(id)"
            case .essaySummaries:
                return "cache.essaySummaries"
            }
        }
    }

    private let defaults = UserDefaults.standard

    func save<T: Codable>(_ value: T, for key: Key) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    func load<T: Codable>(for key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

@MainActor
private final class CollectorLibraryViewModel: ObservableObject {
    @Published var artworks: [ArtworkPackage] = []
    @Published var isLoading = false
    private let api: GalleryAPIClientProtocol

    init(api: GalleryAPIClientProtocol) {
        self.api = api
    }

    convenience init() {
        self.init(api: GalleryAPIClient.live)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        artworks = (try? await api.fetchAllArtworks()) ?? []
    }
}

@MainActor
private final class CollectionStore: ObservableObject {
    @AppStorage("collection.records") private var rawRecords = ""
    @Published private(set) var recordsByArtworkID: [String: CollectionRecord] = [:]

    init() {
        recordsByArtworkID = Self.decode(rawRecords)
    }

    func add(artworkID: UUID) {
        let key = artworkID.uuidString
        if recordsByArtworkID[key] == nil {
            recordsByArtworkID[key] = CollectionRecord(
                artworkID: key,
                acquiredAt: Date(),
                certificateID: "CERT-\(UUID().uuidString.prefix(8))"
            )
        }
        sync()
    }

    func exportRawRecords() -> String {
        rawRecords
    }

    func restore(rawRecords: String) {
        self.rawRecords = rawRecords
        recordsByArtworkID = Self.decode(rawRecords)
    }

    func restoreSingle(artworkID: String, acquiredAt: Date, certificateID: String) {
        guard recordsByArtworkID[artworkID] == nil else { return }
        recordsByArtworkID[artworkID] = CollectionRecord(
            artworkID: artworkID, acquiredAt: acquiredAt, certificateID: certificateID
        )
        sync()
    }

    private func sync() {
        rawRecords = Self.encode(recordsByArtworkID)
    }

    private static func encode(_ records: [String: CollectionRecord]) -> String {
        guard let data = try? JSONEncoder().encode(Array(records.values)),
              let raw = String(data: data, encoding: .utf8) else { return "" }
        return raw
    }

    private static func decode(_ raw: String) -> [String: CollectionRecord] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CollectionRecord].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.artworkID, $0) })
    }
}

@MainActor
private final class FavoritesStore: ObservableObject {
    @AppStorage("favorites.artworkIDs") private var rawIDs = ""
    @Published private(set) var favoriteArtworkIDs: Set<String> = []

    init() {
        favoriteArtworkIDs = Set(rawIDs.split(separator: ",").map(String.init))
    }

    func isFavorite(artworkID: UUID) -> Bool {
        favoriteArtworkIDs.contains(artworkID.uuidString)
    }

    func toggle(artworkID: UUID) {
        if isFavorite(artworkID: artworkID) {
            favoriteArtworkIDs.remove(artworkID.uuidString)
        } else {
            favoriteArtworkIDs.insert(artworkID.uuidString)
        }
        rawIDs = favoriteArtworkIDs.sorted().joined(separator: ",")
    }

    func exportRawIDs() -> String {
        rawIDs
    }

    func restore(rawIDs: String) {
        self.rawIDs = rawIDs
        favoriteArtworkIDs = Set(rawIDs.split(separator: ",").map(String.init))
    }

    func isFavoriteByString(artworkID: String) -> Bool {
        favoriteArtworkIDs.contains(artworkID)
    }

    func insertFavorite(artworkID: String) {
        guard !favoriteArtworkIDs.contains(artworkID) else { return }
        favoriteArtworkIDs.insert(artworkID)
        rawIDs = favoriteArtworkIDs.sorted().joined(separator: ",")
    }
}

struct CollectionRecord: Codable, Hashable {
    let artworkID: String
    let acquiredAt: Date
    let certificateID: String
}

@MainActor
private final class ScholarshipViewModel: ObservableObject {
    @Published var essays: [ScholarlyEssaySummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let api: GalleryAPIClientProtocol

    init(api: GalleryAPIClientProtocol) {
        self.api = api
    }

    convenience init() {
        self.init(api: GalleryAPIClient.live)
    }

    func load() async {
        if let json = ProcessInfo.processInfo.environment["UITEST_ESSAYS_JSON"],
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ScholarlyEssaySummary].self, from: data) {
            essays = decoded
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            essays = try await api.fetchEssaySummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ScholarshipDetailView: View {
    let summary: ScholarlyEssaySummary
    @State private var essay: ScholarlyEssay?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            if let essay {
                VStack(alignment: .leading, spacing: 12) {
                    Text(essay.title).font(.title2.bold())
                    Text(String(format: String(localized: "essay.byAuthor"), essay.author)).font(.subheadline).foregroundStyle(.secondary)
                    Text(.init(essay.markdownBody))
                    if !essay.references.isEmpty {
                        Divider()
                        Text(String(localized: "essay.references")).font(.headline)
                        ForEach(essay.references, id: \.self) { ref in
                            Text("• \(ref)")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isLoading {
                ProgressView(String(localized: "scholarshipDetail.loadingEssay"))
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ContentUnavailableView(String(localized: "scholarshipDetail.essayUnavailable"), systemImage: "book.closed")
            }
        }
        .background(GalleryAppBackground().ignoresSafeArea())
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            essay = try? await GalleryAPI.fetchEssay(id: summary.id)
            isLoading = false
        }
    }
}
