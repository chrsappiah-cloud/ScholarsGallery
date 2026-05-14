import StoreKit
import SwiftUI
import UIKit

// MARK: - User Subscription Panel

struct UserSubscriptionPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var paymentService = StoreKitPaymentService.shared

    @AppStorage("gallery.admin_granted_access") private var adminGrantedAccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    accessHeader
                    if adminGrantedAccess {
                        adminGrantBanner
                    }
                    plansSection
                    deviceCodeSection
                    restoreSection
                    if let error = paymentService.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(GalleryAppBackground().ignoresSafeArea())
            .navigationTitle("Aged Care Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var accessHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: paymentService.hasMonitorAccess || adminGrantedAccess
                      ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(paymentService.hasMonitorAccess || adminGrantedAccess
                                     ? GalleryTheme.accent : GalleryTheme.textTertiary)
                    .font(.title3)
                Text(paymentService.hasMonitorAccess || adminGrantedAccess
                     ? "Access Active" : "Subscribe for Access")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(GalleryTheme.sapphireDark)
            }
            Text("Trauma-aware communication, dignity-first dementia care, and co-design training — on-device with AI flashcards and lesson plans.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GalleryTheme.studioBannerGradient)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GalleryTheme.cardStroke.opacity(0.45), lineWidth: 1))
        )
        .overlay(alignment: .topTrailing) {
            SparkleJewelOverlay().padding(10)
        }
    }

    private var adminGrantBanner: some View {
        Label("Admin access granted to this device", systemImage: "person.badge.key.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(GalleryTheme.accent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plans")
                .font(.headline)
                .foregroundStyle(GalleryTheme.sapphireDark)

            if paymentService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if paymentService.products.isEmpty {
                Text("Products unavailable — check your App Store connection or configure sandbox products in App Store Connect.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(paymentService.products.filter {
                    $0.id == StoreKitPaymentService.ProductID.monitorMonthly.rawValue ||
                    $0.id == StoreKitPaymentService.ProductID.monitorYearly.rawValue
                }) { product in
                    PlanCard(product: product, paymentService: paymentService)
                }
            }
        }
    }

    private var deviceCodeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Device Access Code")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GalleryTheme.sapphireDark)
            Text("Share this code with your administrator to receive manual access.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(deviceAccessCode)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(GalleryTheme.accent)
                .textSelection(.enabled)
                .padding(10)
                .background(GalleryTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GalleryTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GalleryTheme.cardStroke, lineWidth: 1))
        )
        .galleryCardShadow()
    }

    private var restoreSection: some View {
        Button {
            Task { await paymentService.restorePurchases() }
        } label: {
            Label("Restore Purchases", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GalleryProminentButtonStyle())
    }

    private var deviceAccessCode: String {
        let full = UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN"
        return String(full.suffix(8)).uppercased()
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let product: Product
    @ObservedObject var paymentService: StoreKitPaymentService

    private var isOwned: Bool { paymentService.purchasedProductIDs.contains(product.id) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GalleryTheme.textPrimary)
                Text(product.displayPrice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isOwned {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(GalleryTheme.accent)
            } else {
                Button("Subscribe") {
                    Task { _ = await paymentService.purchase(product) }
                }
                .buttonStyle(.bordered)
                .tint(GalleryTheme.accent)
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GalleryTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isOwned ? GalleryTheme.accent.opacity(0.4) : GalleryTheme.cardStroke, lineWidth: 1))
        )
        .galleryCardShadow()
    }
}
