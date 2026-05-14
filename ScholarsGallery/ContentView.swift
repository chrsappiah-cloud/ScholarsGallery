import SwiftUI
import SwiftData
import Foundation
import Combine
import PhotosUI
import GalleryCore
import GalleryUI
import GalleryApp
import StoreKit

// MARK: - App Entry

struct ContentView: View {
    var body: some View {
        RootView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}

// MARK: - Root (backup lifecycle + meta refresh)

private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @StateObject private var collectionStore = CollectionStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var galleryBackendMeta = GalleryBackendMetaModel()
    @State private var hasRestoredBackup = false
    @State private var selectedTab: GalleryTab = .exhibitions
    @State private var isRestoringBackups = false

    var body: some View {
        ZStack(alignment: .bottom) {
            GalleryAppBackground().ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ImmersiveHomeView()
                    .tag(GalleryTab.exhibitions)
                GenerationStudioView()
                    .tag(GalleryTab.studio)
                SavedWorksView()
                    .tag(GalleryTab.saved)
                ScholarshipHomeView()
                    .tag(GalleryTab.scholarship)
                CollectorLibraryView()
                    .tag(GalleryTab.collection)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            FloatingNavBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .environmentObject(collectionStore)
        .environmentObject(favoritesStore)
        .environmentObject(galleryBackendMeta)
        .task {
            await galleryBackendMeta.refresh()
            await refreshBackups(force: true)
            await prefetchAllTabs()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await galleryBackendMeta.refresh()
                    await refreshBackups()
                }
            }
            guard phase == .background else { return }
            Task {
                await performFullBackup()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ICloudKeyValueSync.didReceiveExternalChangeNotification)) { _ in
            Task {
                await refreshBackups()
                await CloudKitSyncManager.shared.restoreIntoSwiftData(context: modelContext)
                syncSwiftDataToStores()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .galleryCollectionDidChange)) { _ in
            let allRecords = (try? modelContext.fetch(FetchDescriptor<PersistedCollectionRecord>())) ?? []
            Task.detached { @Sendable [allRecords] in
                await CloudKitSyncManager.shared.syncCollectionRecords(allRecords)
            }
        }
    }

    private func restoreFromAllBackups() async {
        ICloudKeyValueSync.shared.synchronize()

        if let legacy = try? await CloudBackupService.shared.fetchLatestSnapshot() {
            collectionStore.restore(rawRecords: legacy.collectionRaw)
            favoritesStore.restore(rawIDs: legacy.favoritesRaw)
        }

        if let documentSnapshot = ICloudDocumentBackup.loadSnapshot() {
            ICloudDocumentBackup.restoreFromSnapshot(documentSnapshot, context: modelContext)
        }

        await CloudKitSyncManager.shared.restoreIntoSwiftData(context: modelContext)
        await restoreServerCollectionState()
        syncSwiftDataToStores()
        persistStoresToSwiftData()
    }

    private func refreshBackups(force: Bool = false) async {
        guard force || hasRestoredBackup else { return }
        guard !isRestoringBackups else { return }
        isRestoringBackups = true
        defer { isRestoringBackups = false }

        hasRestoredBackup = true
        await restoreFromAllBackups()
    }

    private func restoreServerCollectionState() async {
        let remoteRecords = await SupabaseCollectionSync.shared.fetchRemoteCollection()
        for record in remoteRecords {
            collectionStore.restoreSingle(
                artworkID: record.artworkID,
                acquiredAt: record.acquiredAt,
                certificateID: record.certificateID
            )
        }

        let remoteFavorites = await SupabaseCollectionSync.shared.fetchRemoteFavorites()
        for artworkID in remoteFavorites {
            favoritesStore.insertFavorite(artworkID: artworkID)
        }
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

        await SupabaseCollectionSync.shared.syncCollection(
            records: collectionStore.allSyncRecords()
        )
        await SupabaseCollectionSync.shared.syncFavorites(
            artworkIDs: Array(favoritesStore.favoriteArtworkIDs).sorted()
        )
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

    private func prefetchAllTabs() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .userInitiated) {
                _ = try? await GalleryAPI.fetchExhibitions()
            }
            group.addTask(priority: .userInitiated) {
                _ = try? await GalleryAPI.fetchAllArtworks()
            }
            group.addTask(priority: .userInitiated) {
                _ = try? await GalleryAPI.fetchEssaySummaries()
            }
            group.addTask(priority: .userInitiated) {
                _ = try? await GalleryAPI.fetchGeneratedArtworks(limit: 20)
            }
            group.addTask(priority: .utility) {
                await ImageUploadService.shared.syncPendingUploads()
            }
        }
    }
}

// MARK: - Tab Model

private enum GalleryTab: Int, CaseIterable {
    case exhibitions, studio, saved, scholarship, collection

    var icon: String {
        switch self {
        case .exhibitions: return "square.grid.2x2"
        case .studio:      return "sparkles.rectangle.stack"
        case .saved:       return "heart"
        case .scholarship: return "book.closed"
        case .collection:  return "rectangle.stack"
        }
    }

    var label: String {
        switch self {
        case .exhibitions: return String(localized: "tab.exhibitions")
        case .studio:      return String(localized: "tab.studio")
        case .saved:       return "Saved"
        case .scholarship: return String(localized: "tab.scholarship")
        case .collection:  return String(localized: "tab.collection")
        }
    }
}

// MARK: - Floating Bottom Navigation

private struct FloatingNavBar: View {
    @Binding var selectedTab: GalleryTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GalleryTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? "\(tab.icon).fill" : tab.icon)
                            .font(.system(size: 18, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.3)
                    }
                    .foregroundStyle(selectedTab == tab ? GalleryTheme.accent : GalleryTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassCard(cornerRadius: 28)
        .galleryCardShadow()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. IMMERSIVE HOME (Exhibitions)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
private struct ImmersiveHomeView: View {
    @EnvironmentObject private var galleryBackendMeta: GalleryBackendMetaModel
    @StateObject private var vm = ExhibitionListViewModel()
    @State private var showAdministratorPanel = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    stickyHeader
                    announcementBanner

                    if vm.isLoading && vm.exhibitions.isEmpty {
                        loadingState
                    } else if let error = vm.errorMessage, vm.exhibitions.isEmpty {
                        errorState(error)
                    } else if vm.exhibitions.isEmpty {
                        emptyState
                    } else {
                        exhibitionContent
                    }
                }
                .padding(.bottom, 100)
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdministratorPanel) {
                AdministratorControlPanelView()
                    .environmentObject(galleryBackendMeta)
            }
            .task { await vm.load() }
        }
    }

    // Sticky cinematic header
    private var stickyHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "app.brandName"))
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(GalleryTheme.textPrimary)
                    .tracking(1)
                Text("CURATED DIGITAL GALLERY")
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .tracking(3)
                    .foregroundStyle(GalleryTheme.accent)
            }

            Spacer()

            if let meta = galleryBackendMeta.meta {
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(GalleryTheme.accent)
                    .accessibilityLabel(
                        String(format: String(localized: "api.meta.detailFormat"),
                               meta.version, meta.catalog, meta.persistence)
                    )
            } else if galleryBackendMeta.lastRefreshFailed {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(GalleryTheme.textTertiary)
            }

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
                    .font(.system(size: 20))
                    .foregroundStyle(GalleryTheme.textSecondary)
            }
            .accessibilityIdentifier("home.overflowMenu")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var announcementBanner: some View {
        if let notice = galleryBackendMeta.meta?.announcement?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notice.isEmpty {
            Text(notice)
                .font(.caption.weight(.medium))
                .foregroundStyle(GalleryTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(GalleryTheme.accent.opacity(0.15))
                .overlay(
                    Rectangle()
                        .fill(GalleryTheme.accent)
                        .frame(width: 3),
                    alignment: .leading
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    private var exhibitionContent: some View {
        VStack(spacing: 28) {
            // Full-bleed hero for first exhibition
            if let featured = vm.exhibitions.first {
                NavigationLink(value: featured) {
                    ImmersiveHeroCard(exhibition: featured)
                }
                .buttonStyle(.plain)
            }

            // "Now Showing" section
            if vm.exhibitions.count > 1 {
                VStack(alignment: .leading, spacing: 14) {
                    GallerySectionHeader(title: "NOW SHOWING", subtitle: "Current exhibitions")
                        .padding(.horizontal, 20)

                    ForEach(vm.exhibitions.dropFirst()) { exhibition in
                        NavigationLink(value: exhibition) {
                            CinematicExhibitionCard(exhibition: exhibition)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                }
            }

            // Featured artworks horizontal grid
            FeaturedArtworkGridRow()

            // Journal / editorial teaser
            JournalTeaser()
                .padding(.horizontal, 20)

            // Artist spotlight
            ArtistSpotlightSection()
                .padding(.horizontal, 20)

            // Collector CTA
            CollectorCTACard()
                .padding(.horizontal, 20)
        }
        .navigationDestination(for: Exhibition.self) { exhibition in
            ExhibitionDetailView(exhibition: exhibition)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GalleryTheme.accent)
                .scaleEffect(1.2)
            Text(String(localized: "home.loadingExhibitions"))
                .font(.subheadline)
                .foregroundStyle(GalleryTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(GalleryTheme.textTertiary)
            Text(String(localized: "home.unableToLoadExhibitions"))
                .font(.headline)
                .foregroundStyle(GalleryTheme.textPrimary)
            Text(error)
                .font(.caption)
                .foregroundStyle(GalleryTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(40)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 36))
                .foregroundStyle(GalleryTheme.textTertiary)
            Text(String(localized: "home.noExhibitionsAvailable"))
                .font(.headline)
                .foregroundStyle(GalleryTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Immersive Hero Card (full-bleed)

private struct ImmersiveHeroCard: View {
    let exhibition: Exhibition

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 0)
                .fill(GalleryTheme.heroCardGradient)
                .frame(height: 380)
                .overlay {
                    SparkleJewelOverlay()
                        .scaleEffect(1.4)
                        .opacity(0.7)
                }
                .overlay {
                    GalleryTheme.fadeToBlack
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("FEATURED")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(GalleryTheme.accent)

                Text(exhibition.title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(0.5)

                Text(exhibition.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                    Text(exhibition.openingDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                }
                .foregroundStyle(GalleryTheme.textTertiary)
                .padding(.top, 4)
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exhibition.title). \(exhibition.subtitle)")
        .accessibilityIdentifier("home.exhibitionCard.\(exhibition.id.uuidString)")
    }
}

// MARK: - Cinematic Exhibition Card

private struct CinematicExhibitionCard: View {
    let exhibition: Exhibition

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GalleryTheme.heroCardGradient)
                .frame(width: 80, height: 80)
                .overlay {
                    SparkleJewelOverlay().scaleEffect(0.6)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(exhibition.title)
                    .font(.headline)
                    .foregroundStyle(GalleryTheme.textPrimary)
                Text(exhibition.subtitle)
                    .font(.caption)
                    .foregroundStyle(GalleryTheme.textSecondary)
                    .lineLimit(2)
                Text(exhibition.openingDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(GalleryTheme.textTertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GalleryTheme.textTertiary)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - Journal Teaser

private struct JournalTeaser: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GallerySectionHeader(title: "JOURNAL", subtitle: "Critical writing on generative art")

            VStack(alignment: .leading, spacing: 8) {
                Text("Generative Art as Scholarly Surface")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(GalleryTheme.textPrimary)
                Text("Exploring the intersection of algorithmic creation and curatorial practice in digital museum spaces.")
                    .font(.caption)
                    .foregroundStyle(GalleryTheme.textSecondary)
                    .lineLimit(3)
                HStack {
                    Text("ScholarsGallery Editorial Board")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(GalleryTheme.accent)
                    Spacer()
                    Text("READ →")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(GalleryTheme.gold)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
}

// MARK: - Artist Spotlight

private struct ArtistSpotlightSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GallerySectionHeader(title: "ARTIST SPOTLIGHT", subtitle: "Featured creators")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ArtistSpotlightCard(
                        name: "Algorithmic Collective",
                        role: "Generative Media",
                        initial: "A"
                    )
                    ArtistSpotlightCard(
                        name: "Curatorial Systems Lab",
                        role: "Research & Curation",
                        initial: "C"
                    )
                    ArtistSpotlightCard(
                        name: "WCS Studio",
                        role: "Platform Design",
                        initial: "W"
                    )
                }
            }
        }
    }
}

private struct ArtistSpotlightCard: View {
    let name: String
    let role: String
    let initial: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(GalleryTheme.heroCardGradient)
                    .frame(width: 56, height: 56)
                Text(initial)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
            }
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GalleryTheme.textPrimary)
                .lineLimit(1)
            Text(role)
                .font(.caption2)
                .foregroundStyle(GalleryTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 110)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Collector CTA

private struct CollectorCTACard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 28))
                .foregroundStyle(GalleryTheme.gold)
            Text("Begin Your Collection")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(GalleryTheme.textPrimary)
            Text("Acquire limited-edition generative artworks with certificates of authenticity.")
                .font(.caption)
                .foregroundStyle(GalleryTheme.textSecondary)
                .multilineTextAlignment(.center)
            Text("EXPLORE EDITIONS →")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(GalleryTheme.accent)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 20)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. EXHIBITION DETAIL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Cinematic header
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(GalleryTheme.headerGradient)
                        .frame(height: 280)
                        .overlay { SparkleJewelOverlay().scaleEffect(1.2) }
                        .overlay { GalleryTheme.fadeToBlack }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(exhibition.title)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Text(exhibition.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(24)
                }

                // Segment picker
                Picker("", selection: $segment) {
                    Text(String(localized: "detail.segmentExperience")).tag(0)
                    Text(String(localized: "detail.segmentWorks")).tag(1)
                    Text(String(localized: "detail.segmentEssay")).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(20)

                switch segment {
                case 0:
                    ExhibitionExperienceView(manifest: vm.manifest, isLoading: vm.isLoading)
                case 1:
                    ArtworkGridView(artworks: vm.artworks, isLoading: vm.isLoading, errorMessage: vm.errorMessage)
                default:
                    ScholarlyEssayView(essay: vm.essay, isLoading: vm.isLoading)
                }
            }
            .padding(.bottom, 100)
        }
        .background(GalleryAppBackground().ignoresSafeArea())
        .navigationTitle(exhibition.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.load() }
    }
}

// MARK: - Exhibition Experience (Room Carousel)

private struct ExhibitionExperienceView: View {
    let manifest: RoomManifest?
    let isLoading: Bool

    var body: some View {
        if let manifest {
            TabView {
                ForEach(manifest.rooms, id: \.id) { room in
                    ZStack {
                        GalleryTheme.roomCarouselGradient.ignoresSafeArea()
                        SparkleJewelOverlay().opacity(0.6)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(room.kind.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(GalleryTheme.accent)
                            Text(room.title)
                                .font(.system(size: 24, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                            if let audio = room.ambientAudio {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform")
                                        .font(.caption2)
                                    Text(audio)
                                        .font(.caption2)
                                }
                                .foregroundStyle(GalleryTheme.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(28)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 320)
        } else if isLoading {
            ProgressView(String(localized: "detail.loadingExperience"))
                .tint(GalleryTheme.accent)
                .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "view.3d")
                    .font(.title)
                    .foregroundStyle(GalleryTheme.textTertiary)
                Text(String(localized: "detail.noRoomExperience"))
                    .font(.subheadline)
                    .foregroundStyle(GalleryTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. ARTWORK GRID + DETAIL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct ArtworkGridView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let artworks: [ArtworkPackage]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(String(localized: "works.loadingWorks"))
                    .tint(GalleryTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let errorMessage, artworks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(GalleryTheme.textTertiary)
                    Text(String(localized: "works.unableToLoadWorks"))
                        .font(.headline)
                        .foregroundStyle(GalleryTheme.textPrimary)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(GalleryTheme.textTertiary)
                }
                .padding(40)
            } else if artworks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title)
                        .foregroundStyle(GalleryTheme.textTertiary)
                    Text(String(localized: "works.noWorksInExhibition"))
                        .font(.subheadline)
                        .foregroundStyle(GalleryTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(artworks) { artwork in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink {
                                ImmersiveArtworkDetailView(artwork: artwork)
                            } label: {
                                ArtworkThumbnailCard(artwork: artwork)
                            }
                            .buttonStyle(.plain)

                            Button {
                                favoritesStore.toggle(artworkID: artwork.id)
                            } label: {
                                Image(systemName: favoritesStore.isFavorite(artworkID: artwork.id) ? "heart.fill" : "heart")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(favoritesStore.isFavorite(artworkID: artwork.id) ? GalleryTheme.rose : .white.opacity(0.7))
                                    .padding(7)
                                    .background(.ultraThinMaterial.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .accessibilityIdentifier("works.favorite.\(artwork.id.uuidString)")
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct ArtworkThumbnailCard: View {
    let artwork: ArtworkPackage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: artwork.displayManifest.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    CinematicImagePlaceholder(height: 150, cornerRadius: 14)
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 170)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(artwork.title)
                case .failure:
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(GalleryTheme.surface)
                        .frame(height: 150)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(GalleryTheme.textTertiary)
                        }
                @unknown default:
                    EmptyView()
                }
            }

            Text(artwork.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GalleryTheme.textPrimary)
                .lineLimit(2)
            Text(artwork.tags.joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(GalleryTheme.textTertiary)
        }
        .padding(10)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - Immersive Artwork Detail View

private struct ImmersiveArtworkDetailView: View {
    @EnvironmentObject private var collectionStore: CollectionStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let artwork: ArtworkPackage
    @State private var checkoutMessage = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Full-bleed hero
                ZStack(alignment: .bottom) {
                    AsyncImage(url: artwork.displayManifest.heroAssetURL) { phase in
                        switch phase {
                        case .empty:
                            CinematicImagePlaceholder(height: 360, cornerRadius: 0)
                        case .success(let image):
                            image
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 420)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(GalleryTheme.surface)
                                .frame(height: 360)
                                .overlay {
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .font(.title)
                                        .foregroundStyle(GalleryTheme.textTertiary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }

                    GalleryTheme.fadeToBlack
                        .frame(height: 160)
                }

                // Metadata panel
                VStack(alignment: .leading, spacing: 16) {
                    Text(artwork.title)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(GalleryTheme.textPrimary)
                        .tracking(0.3)

                    HStack(spacing: 8) {
                        ForEach(artwork.tags, id: \.self) { tag in
                            Text(tag.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(GalleryTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GalleryTheme.accent.opacity(0.12), in: Capsule())
                        }
                    }

                    // Curatorial note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURATORIAL NOTE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(GalleryTheme.gold)
                        Text(.init(artwork.displayManifest.wallLabelMarkdown))
                            .font(.callout)
                            .foregroundStyle(GalleryTheme.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 14)

                    // Edition info + actions
                    if let edition = artwork.edition {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EDITION")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(2)
                                        .foregroundStyle(GalleryTheme.textTertiary)
                                    Text("\(edition.number) / \(edition.total)")
                                        .font(.system(size: 22, weight: .bold, design: .serif))
                                        .foregroundStyle(GalleryTheme.textPrimary)
                                }
                                Spacer()
                                Image(systemName: "seal.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(GalleryTheme.gold.opacity(0.6))
                            }

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

                            HStack(spacing: 12) {
                                Button {
                                    favoritesStore.toggle(artworkID: artwork.id)
                                } label: {
                                    Label(
                                        favoritesStore.isFavorite(artworkID: artwork.id) ? String(localized: "artwork.removeFavorite") : String(localized: "artwork.saveToFavorites"),
                                        systemImage: favoritesStore.isFavorite(artworkID: artwork.id) ? "heart.fill" : "heart"
                                    )
                                    .frame(maxWidth: .infinity)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(GalleryTheme.textSecondary)
                                    .padding(.vertical, 12)
                                    .glassCard(cornerRadius: 12)
                                }
                                .buttonStyle(.plain)

                                ShareLink(item: artwork.displayManifest.heroAssetURL) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(GalleryTheme.textSecondary)
                                        .padding(.vertical, 12)
                                        .glassCard(cornerRadius: 12)
                                }
                            }

                            if !checkoutMessage.isEmpty {
                                Text(checkoutMessage)
                                    .font(.caption)
                                    .foregroundStyle(GalleryTheme.textTertiary)
                            }
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)
                    }
                }
                .padding(20)
            }
            .padding(.bottom, 100)
        }
        .background(GalleryAppBackground().ignoresSafeArea())
        .navigationTitle(String(localized: "artwork.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Scholarly Essay View

private struct ScholarlyEssayView: View {
    let essay: ScholarlyEssay?
    let isLoading: Bool

    var body: some View {
        if let essay {
            VStack(alignment: .leading, spacing: 14) {
                Text(essay.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(GalleryTheme.textPrimary)
                Text(String(format: String(localized: "essay.byAuthor"), essay.author))
                    .font(.caption)
                    .foregroundStyle(GalleryTheme.accent)
                Text(.init(essay.markdownBody))
                    .font(.callout)
                    .foregroundStyle(GalleryTheme.textPrimary)
                    .lineSpacing(5)
                if !essay.references.isEmpty {
                    Rectangle()
                        .fill(GalleryTheme.glassStroke)
                        .frame(height: 0.5)
                        .padding(.vertical, 8)
                    Text(String(localized: "essay.references"))
                        .font(.headline)
                        .foregroundStyle(GalleryTheme.textPrimary)
                    ForEach(essay.references, id: \.self) { ref in
                        Text("• \(ref)")
                            .font(.caption)
                            .foregroundStyle(GalleryTheme.textSecondary)
                    }
                }
            }
            .padding(20)
        } else if isLoading {
            ProgressView(String(localized: "essay.loading"))
                .tint(GalleryTheme.accent)
                .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "text.book.closed")
                    .font(.title)
                    .foregroundStyle(GalleryTheme.textTertiary)
                Text(String(localized: "essay.noEssayAvailable"))
                    .font(.subheadline)
                    .foregroundStyle(GalleryTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 7. FEATURED ARTWORK HORIZONTAL GRID
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
private struct FeaturedArtworkGridRow: View {
    @StateObject private var vm = FeaturedArtworkRowViewModel()

    var body: some View {
        if !vm.artworks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                GallerySectionHeader(title: "FEATURED WORKS", subtitle: "From the current exhibition")
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(vm.artworks) { artwork in
                            NavigationLink {
                                ImmersiveArtworkDetailView(artwork: artwork)
                            } label: {
                                FeaturedArtworkCell(artwork: artwork)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

private struct FeaturedArtworkCell: View {
    let artwork: ArtworkPackage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: artwork.displayManifest.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 180, height: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                default:
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(GalleryTheme.surface)
                        .frame(width: 180, height: 130)
                        .overlay(ProgressView().tint(GalleryTheme.textTertiary))
                }
            }

            Text(artwork.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GalleryTheme.textPrimary)
                .lineLimit(1)
            Text(artwork.tags.joined(separator: " · "))
                .font(.system(size: 9))
                .foregroundStyle(GalleryTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 180)
        .padding(8)
        .glassCard(cornerRadius: 16)
    }
}

@MainActor
private final class FeaturedArtworkRowViewModel: ObservableObject {
    @Published var artworks: [ArtworkPackage] = []

    init() {
        Task { await load() }
    }

    func load() async {
        artworks = (try? await GalleryAPI.fetchAllArtworks()) ?? []
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 8. SAVED WORKS VIEW (@Query SwiftData)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
private struct SavedWorksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @StateObject private var vm = SavedWorksViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAVED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(GalleryTheme.rose)
                        Text("Your Favourites")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(GalleryTheme.textPrimary)
                        Text("\(vm.savedArtworks.count) works saved to your collection")
                            .font(.caption)
                            .foregroundStyle(GalleryTheme.textTertiary)
                    }
                    .padding(.bottom, 8)

                    if vm.isLoading {
                        ProgressView()
                            .tint(GalleryTheme.accent)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if vm.savedArtworks.isEmpty {
                        savedEmptyState
                    } else {
                        ForEach(vm.savedArtworks) { artwork in
                            NavigationLink {
                                ImmersiveArtworkDetailView(artwork: artwork)
                            } label: {
                                SavedArtworkRow(artwork: artwork)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        favoritesStore.toggle(artworkID: artwork.id)
                                        vm.remove(artwork)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "heart.slash")
                                }
                            }
                        }

                        if vm.savedArtworks.count > 1 {
                            Button {
                                withAnimation {
                                    for artwork in vm.savedArtworks {
                                        favoritesStore.toggle(artworkID: artwork.id)
                                    }
                                    vm.removeAll()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                    Text("REMOVE ALL")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                }
                                .foregroundStyle(GalleryTheme.rose.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .glassCard(cornerRadius: 12)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle("Saved")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await vm.load(favoriteIDs: favoritesStore.favoriteArtworkIDs) }
            .onChange(of: favoritesStore.favoriteArtworkIDs) { _, newIDs in
                Task { await vm.load(favoriteIDs: newIDs) }
            }
        }
    }

    private var savedEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 44))
                .foregroundStyle(GalleryTheme.textTertiary)
            Text("No Saved Works Yet")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(GalleryTheme.textPrimary)
            Text("Tap the heart on any artwork to save it here for quick access.")
                .font(.caption)
                .foregroundStyle(GalleryTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}

private struct SavedArtworkRow: View {
    let artwork: ArtworkPackage

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: artwork.displayManifest.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                default:
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(GalleryTheme.surface)
                        .frame(width: 64, height: 64)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(artwork.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GalleryTheme.textPrimary)
                    .lineLimit(1)
                Text(artwork.tags.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(GalleryTheme.textTertiary)
                if let ed = artwork.edition {
                    Text("Edition \(ed.number)/\(ed.total)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(GalleryTheme.gold)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundStyle(GalleryTheme.rose)
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

@MainActor
private final class SavedWorksViewModel: ObservableObject {
    @Published var savedArtworks: [ArtworkPackage] = []
    @Published var isLoading = false
    private var allArtworks: [ArtworkPackage] = []

    func load(favoriteIDs: Set<String>) async {
        if allArtworks.isEmpty {
            isLoading = true
            allArtworks = (try? await GalleryAPI.fetchAllArtworks()) ?? []
            isLoading = false
        }
        savedArtworks = allArtworks.filter { favoriteIDs.contains($0.id.uuidString) }
    }

    func remove(_ artwork: ArtworkPackage) {
        savedArtworks.removeAll { $0.id == artwork.id }
    }

    func removeAll() {
        savedArtworks.removeAll()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - VIEW MODELS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
private final class ExhibitionListViewModel: ObservableObject {
    @Published var exhibitions: [Exhibition] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    private let api: GalleryAPIClientProtocol

    init(api: GalleryAPIClientProtocol) { self.api = api }
    convenience init() { self.init(api: GalleryAPIClient.live) }

    func load() async {
        if let json = ProcessInfo.processInfo.environment["UITEST_EXHIBITIONS_JSON"],
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Exhibition].self, from: data) {
            exhibitions = decoded; isLoading = false; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            exhibitions = try await api.fetchExhibitions()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
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
        self.exhibition = exhibition; self.api = api
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

@MainActor
private struct ScholarshipHomeView: View {
    @StateObject private var vm = ScholarshipViewModel()
    @ObservedObject private var paymentService = StoreKitPaymentService.shared
    @AppStorage("gallery.admin_granted_access") private var adminGrantedAccess = false
    @State private var selectedSection: ScholarshipSection = .coach
    @State private var showSubscriptionPanel = false

    private enum ScholarshipSection: String, CaseIterable {
        case artworks = "AI Descriptions"
        case essays = "Essays"
        case coach = "Study Coach"
    }

    private var hasCoachAccess: Bool {
        paymentService.hasMonitorAccess || adminGrantedAccess
            || ProcessInfo.processInfo.environment["MOCK_MONITOR_ACCESS"] == "1"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(ScholarshipSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Group {
                    switch selectedSection {
                    case .artworks:
                        ArtworkScholarlyListView()
                    case .essays:
                        essayListContent
                    case .coach:
                        if hasCoachAccess {
                            OnDeviceScholarStudyCoachView()
                        } else {
                            CoachSubscriptionPaywallView(showPanel: $showSubscriptionPanel)
                        }
                    }
                }
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "scholarship.navTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSubscriptionPanel = true
                    } label: {
                        Image(systemName: hasCoachAccess ? "checkmark.seal.fill" : "person.crop.circle.badge.plus")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(hasCoachAccess ? GalleryTheme.accent : GalleryTheme.textSecondary)
                    }
                    .accessibilityLabel(hasCoachAccess ? "Subscription active" : "View subscription plans")
                    .accessibilityIdentifier("subscriptionPanel.toolbarButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        Label(String(localized: "scholarship.refresh"), systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("scholarship.refreshButton")
                }
            }
            .sheet(isPresented: $showSubscriptionPanel) {
                UserSubscriptionPanelView()
            }
            .task {
                await vm.load()
                await refreshAdminGrantStatus()
            }
        }
    }

    private func refreshAdminGrantStatus() async {
        guard let deviceID = await UIDevice.current.identifierForVendor?.uuidString else { return }
        var request = URLRequest(url: GalleryAPIConfiguration.baseURL.appendingPathComponent("api/access/check"))
        request.addValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        guard let (data, response) = try? await AppHTTPSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let payload = try? JSONDecoder().decode(AccessCheckResponse.self, from: data)
        else { return }
        adminGrantedAccess = payload.granted
    }
}

    @ViewBuilder
    private var essayListContent: some View {
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
}

private struct ScholarshipDetailView: View {
    let summary: ScholarlyEssaySummary
    @State private var essay: ScholarlyEssay?
    @State private var isLoading = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let essay {
                VStack(alignment: .leading, spacing: 14) {
                    Text(essay.title)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(GalleryTheme.textPrimary)
                    Text(String(format: String(localized: "essay.byAuthor"), essay.author))
                        .font(.caption)
                        .foregroundStyle(GalleryTheme.accent)
                    Text(.init(essay.markdownBody))
                        .font(.callout)
                        .foregroundStyle(GalleryTheme.textSecondary)
                        .lineSpacing(5)
                    if !essay.references.isEmpty {
                        Rectangle()
                            .fill(GalleryTheme.glassStroke)
                            .frame(height: 0.5)
                            .padding(.vertical, 8)
                        Text(String(localized: "essay.references"))
                            .font(.headline)
                            .foregroundStyle(GalleryTheme.textPrimary)
                        ForEach(essay.references, id: \.self) { ref in
                            Text("• \(ref)")
                                .font(.caption)
                                .foregroundStyle(GalleryTheme.textTertiary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isLoading {
                ProgressView(String(localized: "scholarshipDetail.loadingEssay"))
                    .tint(GalleryTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundStyle(GalleryTheme.textTertiary)
                    Text(String(localized: "scholarshipDetail.essayUnavailable"))
                        .font(.subheadline)
                        .foregroundStyle(GalleryTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            }
        }
        .padding(.bottom, 100)
        .background(GalleryAppBackground().ignoresSafeArea())
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            isLoading = true
            essay = try? await GalleryAPI.fetchEssay(id: summary.id)
            isLoading = false
        }
    }
}

// MARK: - Coach Paywall

private struct CoachSubscriptionPaywallView: View {
    @Binding var showPanel: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(GalleryTheme.accent)
                .accessibilityIdentifier("paywall.lockIcon")

            VStack(spacing: 8) {
                Text("Aged Care Monitor")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(GalleryTheme.textPrimary)
                    .accessibilityIdentifier("paywall.title")
                Text("Access trauma-aware communication training, dignity-first dementia support, co-design frameworks, and AI-powered flashcards and lesson plans.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GalleryTheme.accent)
                    Text("On-device AI flashcard generation")
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GalleryTheme.accent)
                    Text("Lesson plan streaming for workshops")
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GalleryTheme.accent)
                    Text("Curated equity-focused resource catalog")
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Button {
                showPanel = true
            } label: {
                Label("View Plans", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GalleryProminentButtonStyle())
            .padding(.horizontal, 24)
            .accessibilityIdentifier("paywall.viewPlansButton")

            Spacer()
        }
        .padding()
        .background(GalleryAppBackground().ignoresSafeArea())
    }
}

// MARK: - Access check response (decoded from /api/access/check)

private struct AccessCheckResponse: Decodable {
    var granted: Bool
    var expiresAt: Date?
}

// MARK: - Collector Library

@MainActor
private struct CollectorLibraryView: View {
    @EnvironmentObject private var collectionStore: CollectionStore
    @StateObject private var vm = CollectorLibraryViewModel()
    @ObservedObject private var uploadService = ImageUploadService.shared
    @State private var showPhotoPicker = false
    @State private var selectedSection: CollectionSection = .collection

    private enum CollectionSection: String, CaseIterable {
        case collection = "Collection"
        case uploads = "My Uploads"
        case creations = "Your Creations"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(CollectionSection.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Group {
                    switch selectedSection {
                    case .collection:
                        collectionContent
                    case .uploads:
                        uploadsContent
                    case .creations:
                        creationsContent
                    }
                }
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "collection.navTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Upload from Device", systemImage: "photo.badge.plus")
                        }
                        Button {
                            Task { await vm.load() }
                        } label: {
                            Label(String(localized: "collection.refresh"), systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityIdentifier("collection.menuButton")
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $uploadService.selectedItems, maxSelectionCount: 10, matching: .images)
            .onChange(of: uploadService.selectedItems) { _, _ in
                Task { await uploadService.processSelectedItems() }
            }
            .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var collectionContent: some View {
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

    @ViewBuilder
    private var uploadsContent: some View {
        if uploadService.isUploading {
            VStack(spacing: 12) {
                ProgressView("Uploading…")
                Text("Processing your images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if uploadService.uploadedImages.isEmpty {
            ContentUnavailableView(
                "No Uploads Yet",
                systemImage: "photo.badge.plus",
                description: Text("Tap + to upload images from your device to the gallery.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(uploadService.uploadedImages) { record in
                        let url = uploadService.imageURL(for: record)
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(GalleryTheme.card)
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            }
                        }
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if record.syncedToServer {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(4)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(4)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var creationsContent: some View {
        GeneratedCreationsGalleryView()
    }
}

@MainActor
private struct GeneratedCreationsGalleryView: View {
    @State private var creations: [GeneratedArtwork] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading creations…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if creations.isEmpty {
                ContentUnavailableView(
                    "No Creations Yet",
                    systemImage: "wand.and.stars",
                    description: Text("Artworks you generate in the Studio will appear here.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(creations) { artwork in
                            VStack(alignment: .leading, spacing: 6) {
                                AsyncImage(url: URL(string: artwork.imageURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Rectangle().fill(GalleryTheme.card)
                                            .overlay(ProgressView())
                                    }
                                }
                                .frame(height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(artwork.prompt.prefix(40) + (artwork.prompt.count > 40 ? "…" : ""))
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(artwork.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(GalleryTheme.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(GalleryTheme.cardStroke, lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            isLoading = true
            defer { isLoading = false }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                creations = try await GalleryAPI.fetchGeneratedArtworks(limit: 50)
            } catch {
                creations = []
            }
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
    private static let session = AppHTTPSession.shared
    private static let generationToken: String? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GENERATION_API_TOKEN") as? String,
              !raw.isEmpty else { return nil }
        return raw
    }()

    static func fetchExhibitions() async throws -> [Exhibition] {
        do {
            let (data, response) = try await session.data(from: baseURL.appendingPathComponent("api/exhibitions"))
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
            let (data, response) = try await session.data(from: url)
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
            let (data, response) = try await session.data(from: url)
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
            let (data, response) = try await session.data(from: url)
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
            let (data, response) = try await session.data(for: request)
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
        let (data, response) = try await session.data(for: request)
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
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([GeneratedArtwork].self, from: data)
            cache.save(decoded, for: .generatedArtworks(limit))
            return decoded
        } catch {
            if let cached: [GeneratedArtwork] = cache.load(for: .generatedArtworks(limit)) {
                return cached
            }
            throw map(error)
        }
    }

    static func fetchEssaySummaries() async throws -> [ScholarlyEssaySummary] {
        do {
            let (data, response) = try await session.data(from: baseURL.appendingPathComponent("api/essays"))
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

    static func generateScholarlyDescription(
        artworkTitle: String,
        artworkTags: [String],
        wallLabel: String,
        prompt: String? = nil
    ) async throws -> ScholarlyDescriptionResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/scholars/describe"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ScholarlyDescribeRequestPayload(
            artworkTitle: artworkTitle,
            artworkTags: artworkTags,
            wallLabel: wallLabel,
            prompt: prompt
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(ScholarlyDescriptionResult.self, from: data)
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

private struct ScholarlyDescribeRequestPayload: Codable {
    let artworkTitle: String
    let artworkTags: [String]
    let wallLabel: String
    let prompt: String?
}

private struct ScholarlyDescriptionResult: Codable, Hashable {
    let scholarlyDescription: String
    let socialMediaCaption: String
    let hashtags: [String]
    let provider: String
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
    @ObservedObject private var paymentService = StoreKitPaymentService.shared
    @StateObject private var vm = GenerationStudioViewModel()
    @State private var showDolaSheet = false
    @State private var showPaywall = false

    private var isPaywallEnforced: Bool {
        let checkoutEnabled = galleryBackendMeta.meta?.effectiveCheckoutEnabled ?? true
        return checkoutEnabled && !paymentService.hasStudioAccess
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
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

                    if isPaywallEnforced {
                        StudioPaywallBanner(showPaywall: $showPaywall)
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
                        if isPaywallEnforced {
                            showPaywall = true
                        } else {
                            Task { await vm.generate() }
                        }
                    } label: {
                        if vm.isGenerating {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(
                                isPaywallEnforced ? "Subscribe to Generate" : String(localized: "studio.generateArtwork"),
                                systemImage: isPaywallEnforced ? "lock.fill" : "wand.and.stars"
                            )
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
            .sheet(isPresented: $showPaywall) {
                StudioPaywallSheet()
            }
            .task {
                await vm.loadRecent()
            }
        }
    }
}

private struct StudioPaywallBanner: View {
    @Binding var showPaywall: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Studio Pro Required")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Subscribe to unlock unlimited AI art generation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Unlock") { showPaywall = true }
                .buttonStyle(.borderedProminent)
                .tint(GalleryTheme.accent)
                .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GalleryTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct StudioPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var paymentService = StoreKitPaymentService.shared
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(GalleryTheme.accent)
                        .padding(.top, 30)

                    Text("Studio Pro")
                        .font(.largeTitle.bold())

                    Text("Unlock unlimited AI art generation, Dola assistant, and exclusive features.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(paymentService.products, id: \.id) { product in
                            Button {
                                Task {
                                    isPurchasing = true
                                    let success = await paymentService.purchase(product)
                                    isPurchasing = false
                                    if success { dismiss() }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.displayName)
                                            .font(.headline)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline)
                                        .foregroundStyle(GalleryTheme.accent)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(GalleryTheme.card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(GalleryTheme.accent.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isPurchasing)
                        }
                    }
                    .padding(.horizontal)

                    if paymentService.products.isEmpty && !paymentService.isLoading {
                        Text("Products unavailable. Generation access is free while store is being configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    if let error = paymentService.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Restore Purchases") {
                        Task { await paymentService.restorePurchases() }
                    }
                    .font(.footnote)

                    Spacer()
                }
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
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
           let id = UUID(uuidString: raw) { return id }
        return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }()

    private static var uiTestGenerateMode: String? { ProcessInfo.processInfo.environment["UITEST_GENERATE_MODE"] }
    private static var uiTestRecentJSON: String? { ProcessInfo.processInfo.environment["UITEST_RECENT_GENERATIONS_JSON"] }

    func generate() async {
        if let mode = Self.uiTestGenerateMode {
            if mode == "success" {
                let mock = GeneratedArtwork(id: UUID(), status: "completed",
                    imageURL: "https://images.unsplash.com/photo-1518770660439-4636190af475",
                    prompt: prompt, provider: "mock-ui-test", createdAt: Date())
                generated = mock; recentGenerations.insert(mock, at: 0); errorMessage = nil; return
            }
            if mode == "error" {
                generated = nil; errorMessage = String(localized: "studio.uiTestError"); return
            }
        }
        isGenerating = true; defer { isGenerating = false }; errorMessage = nil
        do {
            generated = try await GalleryAPI.generateArtwork(
                prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines), artistID: artistID)
            await loadRecent()
            if let art = generated {
                let artCopy = art
                Task.detached { @Sendable in
                    await CloudKitSyncManager.shared.syncGeneratedArtwork(
                        id: artCopy.id.uuidString,
                        status: artCopy.status,
                        imageURL: artCopy.imageURL,
                        prompt: artCopy.prompt,
                        provider: artCopy.provider,
                        createdAt: artCopy.createdAt
                    )
                }
            }
            if let art = generated {
                Task.detached { @Sendable in
                    _ = try? await GalleryAPI.generateScholarlyDescription(
                        artworkTitle: art.prompt.prefix(60).description,
                        artworkTags: ["Generated", "AI Art"],
                        wallLabel: art.prompt,
                        prompt: art.prompt
                    )
                }
            }
        } catch let apiError as GalleryAPIError {
            errorMessage = apiError.localizedDescription
        } catch { errorMessage = AppAPIErrorMapper.map(error).localizedDescription }
    }

    func loadRecent() async {
        if let raw = Self.uiTestRecentJSON, let decoded = Self.decodeRecentFromUITestJSON(raw) {
            recentGenerations = decoded; return
        }
        do { recentGenerations = try await GalleryAPI.fetchGeneratedArtworks(limit: 20) } catch { }
    }

    private static func decodeRecentFromUITestJSON(_ raw: String) -> [GeneratedArtwork]? {
        guard let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([GeneratedArtwork].self, from: data)
    }
}

@MainActor
private final class ScholarshipViewModel: ObservableObject {
    @Published var essays: [ScholarlyEssaySummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let api: GalleryAPIClientProtocol

    init(api: GalleryAPIClientProtocol) { self.api = api }
    convenience init() { self.init(api: GalleryAPIClient.live) }

    func load() async {
        if let json = ProcessInfo.processInfo.environment["UITEST_ESSAYS_JSON"],
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ScholarlyEssaySummary].self, from: data) {
            essays = decoded; isLoading = false; return
        }
        isLoading = true; defer { isLoading = false }
        do { essays = try await api.fetchEssaySummaries(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}

@MainActor
private final class CollectorLibraryViewModel: ObservableObject {
    @Published var artworks: [ArtworkPackage] = []
    @Published var isLoading = false
    private let api: GalleryAPIClientProtocol

    init(api: GalleryAPIClientProtocol) { self.api = api }
    convenience init() { self.init(api: GalleryAPIClient.live) }

    func load() async {
        isLoading = true; defer { isLoading = false }
        artworks = (try? await api.fetchAllArtworks()) ?? []
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - STORES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
private final class CollectionStore: ObservableObject {
    @AppStorage("collection.records") private var rawRecords = ""
    @Published private(set) var recordsByArtworkID: [String: CollectionRecord] = [:]

    init() { recordsByArtworkID = Self.decode(rawRecords) }

    func add(artworkID: UUID) {
        let key = artworkID.uuidString
        if recordsByArtworkID[key] == nil {
            recordsByArtworkID[key] = CollectionRecord(artworkID: key, acquiredAt: Date(),
                certificateID: "CERT-\(UUID().uuidString.prefix(8))")
        }
        sync()
        NotificationCenter.default.post(name: .galleryCollectionDidChange, object: nil)
    }

    func exportRawRecords() -> String { rawRecords }
    func restore(rawRecords: String) { self.rawRecords = rawRecords; recordsByArtworkID = Self.decode(rawRecords) }
    func restoreSingle(artworkID: String, acquiredAt: Date, certificateID: String) {
        guard recordsByArtworkID[artworkID] == nil else { return }
        recordsByArtworkID[artworkID] = CollectionRecord(artworkID: artworkID, acquiredAt: acquiredAt, certificateID: certificateID)
        sync()
    }

    func allSyncRecords() -> [CollectionSyncRecord] {
        recordsByArtworkID.values.map {
            CollectionSyncRecord(
                id: $0.artworkID,
                artworkID: $0.artworkID,
                acquiredAt: $0.acquiredAt,
                certificateID: $0.certificateID
            )
        }
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

    init() { favoriteArtworkIDs = Set(rawIDs.split(separator: ",").map(String.init)) }

    func isFavorite(artworkID: UUID) -> Bool { favoriteArtworkIDs.contains(artworkID.uuidString) }
    func toggle(artworkID: UUID) {
        if isFavorite(artworkID: artworkID) { favoriteArtworkIDs.remove(artworkID.uuidString) }
        else { favoriteArtworkIDs.insert(artworkID.uuidString) }
        rawIDs = favoriteArtworkIDs.sorted().joined(separator: ",")
        let ids = favoriteArtworkIDs
        Task.detached { @Sendable in
            await CloudKitSyncManager.shared.syncFavorites(ids)
        }
    }
    func exportRawIDs() -> String { rawIDs }
    func restore(rawIDs: String) { self.rawIDs = rawIDs; favoriteArtworkIDs = Set(rawIDs.split(separator: ",").map(String.init)) }
    func isFavoriteByString(artworkID: String) -> Bool { favoriteArtworkIDs.contains(artworkID) }
    func insertFavorite(artworkID: String) {
        guard !favoriteArtworkIDs.contains(artworkID) else { return }
        favoriteArtworkIDs.insert(artworkID)
        rawIDs = favoriteArtworkIDs.sorted().joined(separator: ",")
    }
}

struct CollectionRecord: Codable, Hashable {
    let artworkID: String; let acquiredAt: Date; let certificateID: String
}

extension Notification.Name {
    static let galleryCollectionDidChange = Notification.Name("gallery.collectionDidChange")
}


private enum GalleryAPIError: LocalizedError {
    case networkCached, networkConnect, serverInvalid, decodingFailed, unexpected, invalidGeneratedEndpoint, generationDisabledByPolicy

    var errorDescription: String? {
        switch self {
        case .networkCached: return String(localized: "error.networkCached")
        case .networkConnect: return String(localized: "error.networkConnect")
        case .serverInvalid: return String(localized: "error.serverInvalid")
        case .decodingFailed: return String(localized: "error.decodeFailed")
        case .unexpected: return String(localized: "error.unexpected")
        case .invalidGeneratedEndpoint: return String(localized: "error.invalidGeneratedEndpoint")
        case .generationDisabledByPolicy: return String(localized: "studio.policyGenerationDisabled")
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
        case generatedArtworks(Int)

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
            case .generatedArtworks(let limit):
                return "cache.generatedArtworks.\(limit)"
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
// MARK: - AI-Powered Artwork Scholarly Descriptions

@MainActor
private final class ArtworkScholarlyViewModel: ObservableObject {
    @Published var artworks: [ArtworkPackage] = []
    @Published var descriptions: [UUID: ScholarlyDescriptionResult] = [:]
    @Published var loadingArtworks = false
    @Published var generatingID: UUID?

    func loadArtworks() async {
        loadingArtworks = true
        defer { loadingArtworks = false }
        artworks = (try? await GalleryAPI.fetchAllArtworks()) ?? []
        await autoGenerateDescriptions()
    }

    func autoGenerateDescriptions() async {
        for artwork in artworks where descriptions[artwork.id] == nil {
            generatingID = artwork.id
            do {
                let result = try await GalleryAPI.generateScholarlyDescription(
                    artworkTitle: artwork.title,
                    artworkTags: artwork.tags,
                    wallLabel: artwork.displayManifest.wallLabelMarkdown
                )
                descriptions[artwork.id] = result
            } catch {
                // Continue with other artworks; failed ones can be retried
            }
        }
        generatingID = nil
    }

    func regenerateDescription(for artwork: ArtworkPackage) async {
        generatingID = artwork.id
        defer { generatingID = nil }
        do {
            let result = try await GalleryAPI.generateScholarlyDescription(
                artworkTitle: artwork.title,
                artworkTags: artwork.tags,
                wallLabel: artwork.displayManifest.wallLabelMarkdown
            )
            descriptions[artwork.id] = result
        } catch {
            // Silently fail — user can tap regenerate
        }
    }
}

@MainActor
private struct ArtworkScholarlyListView: View {
    @StateObject private var vm = ArtworkScholarlyViewModel()

    var body: some View {
        Group {
            if vm.loadingArtworks {
                ProgressView("Loading artworks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.artworks.isEmpty {
                ContentUnavailableView(
                    "No Artworks",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Artworks will appear here once generated or uploaded.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(vm.artworks) { artwork in
                            NavigationLink {
                                ArtworkScholarlyDetailView(
                                    artwork: artwork,
                                    description: vm.descriptions[artwork.id],
                                    isGenerating: vm.generatingID == artwork.id,
                                    onRegenerate: {
                                        Task { await vm.regenerateDescription(for: artwork) }
                                    }
                                )
                            } label: {
                                ArtworkScholarlyCard(
                                    artwork: artwork,
                                    description: vm.descriptions[artwork.id],
                                    isGenerating: vm.generatingID == artwork.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .task { await vm.loadArtworks() }
    }
}

private struct ArtworkScholarlyCard: View {
    let artwork: ArtworkPackage
    let description: ScholarlyDescriptionResult?
    let isGenerating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: artwork.displayManifest.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(GalleryTheme.card)
                            .overlay(Image(systemName: "photo.artframe").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(artwork.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(artwork.tags.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating scholarly analysis…")
                                .font(.caption2)
                                .foregroundStyle(GalleryTheme.sapphire)
                        }
                    } else if let desc = description {
                        Text(desc.scholarlyDescription.prefix(100) + "…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GalleryTheme.sapphire.opacity(0.45))
            }
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
}

private struct ArtworkScholarlyDetailView: View {
    let artwork: ArtworkPackage
    let description: ScholarlyDescriptionResult?
    let isGenerating: Bool
    let onRegenerate: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AsyncImage(url: artwork.displayManifest.heroAssetURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    default:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GalleryTheme.card)
                            .frame(height: 220)
                            .overlay(ProgressView())
                    }
                }

                Text(artwork.title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                Text(artwork.tags.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(GalleryTheme.sapphire)

                if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Generating scholarly analysis…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                } else if let desc = description {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Scholarly Analysis", systemImage: "text.book.closed.fill")
                            .font(.headline)
                            .foregroundStyle(GalleryTheme.sapphireDark)
                        Text(desc.scholarlyDescription)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Social Media Caption", systemImage: "megaphone.fill")
                            .font(.headline)
                            .foregroundStyle(GalleryTheme.roseSoft)
                        Text(desc.socialMediaCaption)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .italic()

                        if !desc.hashtags.isEmpty {
                            Text(desc.hashtags.map { "#\($0)" }.joined(separator: " "))
                                .font(.caption)
                                .foregroundStyle(GalleryTheme.accent)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GalleryTheme.accent)

                        Button {
                            onRegenerate()
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                } else {
                    Button {
                        onRegenerate()
                    } label: {
                        Label("Generate Scholarly Description", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GalleryTheme.accent)
                }
            }
            .padding()
        }
        .background(GalleryAppBackground().ignoresSafeArea())
        .navigationTitle("Scholarly View")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let desc = description {
                ShareSheetView(items: [
                    buildShareText(desc)
                ])
            }
        }
    }

    private func buildShareText(_ desc: ScholarlyDescriptionResult) -> String {
        """
        \(artwork.title)

        \(desc.socialMediaCaption)

        \(desc.hashtags.map { "#\($0)" }.joined(separator: " "))

        — Explore at ScholarsGallery
        """
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
