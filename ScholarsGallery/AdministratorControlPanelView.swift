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

    // Access grants
    @State private var accessGrants: [AdminAccessGrant] = []
    @State private var isLoadingGrants = false
    @State private var newGrantDeviceID = ""
    @State private var newGrantReason = ""
    @State private var newGrantExpiry: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var newGrantHasExpiry = false
    @State private var grantError: String?

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

                    accessGrantsSection
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

    private var accessGrantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Access Grants")
                .font(.headline)
                .foregroundStyle(GalleryTheme.sapphireDark)

            // Load button
            Button {
                Task { await loadGrants() }
            } label: {
                if isLoadingGrants {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Load Access Grants", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(GalleryProminentButtonStyle())
            .disabled(isLoadingGrants || storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("adminPanel.loadGrantsButton")

            if let grantError {
                Text(grantError).font(.footnote).foregroundStyle(.red)
            }

            // Existing grants list
            if !accessGrants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(accessGrants) { grant in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grant.deviceID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(GalleryTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if let expiry = grant.expiresAt {
                                    Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No expiry")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await revokeGrant(deviceID: grant.deviceID) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.footnote)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .accessibilityIdentifier("adminPanel.revokeButton.\(grant.deviceID)")
                        }
                        .padding(10)
                        .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GalleryTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GalleryTheme.cardStroke, lineWidth: 1))
                )
                .galleryCardShadow()
            }

            // Grant new access form
            VStack(alignment: .leading, spacing: 10) {
                Text("Grant New Access")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GalleryTheme.sapphireDark)

                TextField("Device access code (8-char suffix or full UUID)", text: $newGrantDeviceID)
                    .textInputAutocapitalization(.characters)
                    .padding(10)
                    .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("adminPanel.deviceIDField")

                TextField("Reason (optional)", text: $newGrantReason)
                    .padding(10)
                    .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("adminPanel.reasonField")

                Toggle("Set expiry date", isOn: $newGrantHasExpiry)
                    .tint(GalleryTheme.accent)

                if newGrantHasExpiry {
                    DatePicker("Expires", selection: $newGrantExpiry, displayedComponents: .date)
                }

                Button {
                    Task { await grantAccess() }
                } label: {
                    Label("Grant Access", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GalleryProminentButtonStyle())
                .disabled(newGrantDeviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("adminPanel.grantAccessButton")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GalleryTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GalleryTheme.cardStroke, lineWidth: 1))
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

    private func loadGrants() async {
        isLoadingGrants = true
        grantError = nil
        defer { isLoadingGrants = false }
        do {
            accessGrants = try await GalleryAccessAPI.fetchGrants(
                adminToken: storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            grantError = error.localizedDescription
        }
    }

    private func grantAccess() async {
        grantError = nil
        let token = storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let deviceID = newGrantDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = newGrantReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let expiry: Date? = newGrantHasExpiry ? newGrantExpiry : nil
        do {
            let grant = try await GalleryAccessAPI.grantAccess(
                adminToken: token, deviceID: deviceID,
                expiresAt: expiry, reason: reason.isEmpty ? nil : reason
            )
            accessGrants.removeAll { $0.deviceID == grant.deviceID }
            accessGrants.insert(grant, at: 0)
            newGrantDeviceID = ""
            newGrantReason = ""
            ICloudKeyValueSync.shared.synchronize()
        } catch {
            grantError = error.localizedDescription
        }
    }

    private func revokeGrant(deviceID: String) async {
        grantError = nil
        let token = storedAdminToken.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await GalleryAccessAPI.revokeAccess(adminToken: token, deviceID: deviceID)
            accessGrants.removeAll { $0.deviceID == deviceID }
            ICloudKeyValueSync.shared.synchronize()
        } catch {
            grantError = error.localizedDescription
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

private struct AdminAccessGrant: Codable, Identifiable {
    var id: String { deviceID }
    var deviceID: String
    var grantedAt: Date
    var expiresAt: Date?
    var reason: String?
}

private enum GalleryAccessAPI {
    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func fetchGrants(adminToken: String) async throws -> [AdminAccessGrant] {
        var request = URLRequest(url: GalleryAPIConfiguration.baseURL.appendingPathComponent("api/admin/access/grants"))
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        return try decoder.decode([AdminAccessGrant].self, from: data)
    }

    static func grantAccess(adminToken: String, deviceID: String, expiresAt: Date?, reason: String?) async throws -> AdminAccessGrant {
        struct Body: Encodable {
            var deviceID: String
            var expiresAt: Date?
            var reason: String?
        }
        var request = URLRequest(url: GalleryAPIConfiguration.baseURL.appendingPathComponent("api/admin/access/grant"))
        request.httpMethod = "POST"
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        request.httpBody = try enc.encode(Body(deviceID: deviceID, expiresAt: expiresAt, reason: reason))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.cannotWriteToFile)
        }
        return try decoder.decode(AdminAccessGrant.self, from: data)
    }

    static func revokeAccess(adminToken: String, deviceID: String) async throws {
        let url = GalleryAPIConfiguration.baseURL.appendingPathComponent("api/admin/access/\(deviceID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.cannotRemoveFile)
        }
    }
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
