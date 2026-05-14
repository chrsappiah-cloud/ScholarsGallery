import Combine
import Foundation
import StoreKit

@MainActor
final class StoreKitPaymentService: ObservableObject {
    static let shared = StoreKitPaymentService()

    enum ProductID: String, CaseIterable {
        case studioMonthly = "gallery.studio.monthly"
        case studioYearly = "gallery.studio.yearly"
        case generationPack = "gallery.studio.generation.pack"
        case monitorMonthly = "gallery.monitor.monthly"
        case monitorYearly = "gallery.monitor.yearly"
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: String?

    var hasStudioAccess: Bool {
        purchasedProductIDs.contains(ProductID.studioMonthly.rawValue) ||
        purchasedProductIDs.contains(ProductID.studioYearly.rawValue)
    }

    var hasMonitorAccess: Bool {
        purchasedProductIDs.contains(ProductID.monitorMonthly.rawValue) ||
        purchasedProductIDs.contains(ProductID.monitorYearly.rawValue) ||
        hasStudioAccess
    }

    var hasGenerationCredits: Bool {
        purchasedProductIDs.contains(ProductID.generationPack.rawValue) || hasStudioAccess
    }

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Unable to load products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }
        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await self?.updatePurchasedProducts()
                }
            }
        }
    }
}
