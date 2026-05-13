import SwiftUI

/// Operator surface: access (generation) and payment (checkout), styled with ``GalleryTheme`` (emerald / sapphire / rose).
struct AdministratorControlPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var galleryBackendMeta: GalleryBackendMetaModel

    @AppStorage("gallery.admin_api_token") private var storedAdminToken = ""

    @State private var policyDraft = AdminPolicyForm(
        checkoutEnabled: true,
        generationEnabled: true,
        dolaAssistantEnabled: true,
        announcement: ""
    )
    @State private var overview: AdminOverviewPayload?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    SecureField(String(localized: "admin.tokenPlaceholder"), text: $storedAdminToken)
                        .textContentType(.password)
                        .padding(14)
                        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(GalleryTheme.sapphire.opacity(0.22), lineWidth: 1)
                        )

                    Button {
                        Task { await loadOverview() }
                    } label: {
                        Label(String(localized: "admin.loadOverview"), systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GalleryProminentButtonStyle())
                    .disabled(isLoading || storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let overview {
                        overviewCard(overview)
                    }

                    Text(String(localized: "admin.policySectionTitle"))
                        .font(.headline)
                        .foregroundStyle(GalleryTheme.sapphireDark)

                    Toggle(String(localized: "admin.allowCheckout"), isOn: $policyDraft.checkoutEnabled)
                        .tint(GalleryTheme.accent)
                    Toggle(String(localized: "admin.allowGeneration"), isOn: $policyDraft.generationEnabled)
                        .tint(GalleryTheme.accent)
                    Toggle(String(localized: "admin.allowDolaAssistant"), isOn: $policyDraft.dolaAssistantEnabled)
                        .tint(GalleryTheme.accent)
                        .accessibilityIdentifier("admin.dolaToggle")

                    TextField(String(localized: "admin.announcementPlaceholder"), text: $policyDraft.announcement, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        Task { await savePolicy() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(String(localized: "admin.savePolicy"), systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(GalleryProminentButtonStyle())
                    .disabled(isSaving || storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    subscriberManagementSection
                    revenueSection

                    Text(String(localized: "admin.securityFootnote"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle(String(localized: "admin.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "admin.dismiss")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var subscriberManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriber Management")
                .font(.headline)
                .foregroundStyle(GalleryTheme.sapphireDark)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Active Subscribers") {
                    Text("—")
                        .font(.subheadline.monospaced())
                }
                LabeledContent("Studio Pro Monthly") {
                    Text("—")
                        .font(.subheadline.monospaced())
                }
                LabeledContent("Studio Pro Yearly") {
                    Text("—")
                        .font(.subheadline.monospaced())
                }
                Text("Connect App Store Connect for real-time subscriber data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue Dashboard")
                .font(.headline)
                .foregroundStyle(GalleryTheme.sapphireDark)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Total Transactions") {
                    Text("—")
                        .font(.subheadline.monospaced())
                }
                LabeledContent("Monthly Revenue") {
                    Text("—")
                        .font(.subheadline.monospaced())
                }
                LabeledContent("Payment Status") {
                    Text(policyDraft.checkoutEnabled ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundStyle(policyDraft.checkoutEnabled ? GalleryTheme.accent : .red)
                }
                Text("Revenue data syncs from App Store Connect Server Notifications")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(GalleryTheme.accent)
                Text(String(localized: "admin.headerTitle"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(GalleryTheme.sapphireDark)
            }
            Text(String(localized: "admin.headerSubtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GalleryTheme.studioBannerGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(GalleryTheme.cardStroke.opacity(0.45), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            SparkleJewelOverlay().padding(10)
        }
    }

    private func overviewCard(_ payload: AdminOverviewPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "admin.overviewTitle"))
                .font(.headline)
                .foregroundStyle(GalleryTheme.sapphireDark)
            LabeledContent(String(localized: "admin.fieldCatalog")) {
                Text(payload.catalogPersistence).font(.subheadline.monospaced())
            }
            LabeledContent(String(localized: "admin.fieldGenerations")) {
                Text(payload.generationPersistence).font(.subheadline.monospaced())
            }
            LabeledContent(String(localized: "admin.fieldOpenAI")) {
                Text(payload.openAIConfigured ? String(localized: "admin.yes") : String(localized: "admin.no"))
            }
            LabeledContent(String(localized: "admin.fieldGenToken")) {
                Text(payload.generationTokenConfigured ? String(localized: "admin.yes") : String(localized: "admin.no"))
            }
            LabeledContent(String(localized: "admin.fieldDolaProvider")) {
                Text(payload.dolaAssistantProvider ?? "mock").font(.subheadline.monospaced())
            }
            LabeledContent(String(localized: "admin.fieldDolaConfigured")) {
                Text((payload.dolaAssistantConfigured ?? false)
                     ? String(localized: "admin.yes")
                     : String(localized: "admin.no"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func loadOverview() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let payload = try await GalleryAdminAPI.fetchOverview(
                adminToken: storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            overview = payload
            policyDraft = AdminPolicyForm(
                checkoutEnabled: payload.policy.checkoutEnabled,
                generationEnabled: payload.policy.generationEnabled,
                dolaAssistantEnabled: payload.policy.dolaAssistantEnabled ?? true,
                announcement: payload.policy.announcement ?? ""
            )
        } catch {
            overview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func savePolicy() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let snapshot = AdminPolicySnapshot(
                checkoutEnabled: policyDraft.checkoutEnabled,
                generationEnabled: policyDraft.generationEnabled,
                announcement: policyDraft.announcement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : policyDraft.announcement,
                dolaAssistantEnabled: policyDraft.dolaAssistantEnabled
            )
            try await GalleryAdminAPI.putPolicy(
                adminToken: storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines),
                policy: snapshot
            )
            await galleryBackendMeta.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminPolicyForm {
    var checkoutEnabled: Bool
    var generationEnabled: Bool
    var dolaAssistantEnabled: Bool
    var announcement: String
}

private struct AdminPolicySnapshot: Codable, Equatable {
    var checkoutEnabled: Bool
    var generationEnabled: Bool
    var announcement: String?
    var dolaAssistantEnabled: Bool?
}

private struct AdminOverviewPayload: Decodable {
    struct PolicyPart: Decodable {
        var checkoutEnabled: Bool
        var generationEnabled: Bool
        var announcement: String?
        var dolaAssistantEnabled: Bool?
    }

    var policy: PolicyPart
    var generationTokenConfigured: Bool
    var openAIConfigured: Bool
    var catalogPersistence: String
    var generationPersistence: String
    var dolaAssistantConfigured: Bool?
    var dolaAssistantProvider: String?
}

private enum GalleryAdminAPI {
    static func fetchOverview(adminToken: String) async throws -> AdminOverviewPayload {
        var request = URLRequest(url: GalleryAPIConfiguration.baseURL.appendingPathComponent("api/admin/overview"))
        request.httpMethod = "GET"
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        return try JSONDecoder().decode(AdminOverviewPayload.self, from: data)
    }

    static func putPolicy(adminToken: String, policy: AdminPolicySnapshot) async throws {
        var request = URLRequest(url: GalleryAPIConfiguration.baseURL.appendingPathComponent("api/admin/policy"))
        request.httpMethod = "PUT"
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(policy)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.cannotWriteToFile)
        }
    }
}
