import StoreKit
import Foundation
import Combine
import NavCore
import NavNetworking

// MARK: - Purchase State

public enum PurchaseState: Equatable {
    case idle
    case purchasing
    case purchased
    case failed(String)
    case pending
    case restored
}

// MARK: - StoreKit Manager

@MainActor
public class StoreKitManager: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var subscriptionProducts: [Product] = []
    @Published public var consumableProducts: [Product] = []
    @Published public var purchaseState: PurchaseState = .idle
    @Published public var isPremium: Bool = false
    @Published public var activeProductID: String?
    @Published public var isLoadingProducts: Bool = false

    private var transactionListenerTask: Task<Void, Error>?

    public init() {
        transactionListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    if let transaction {
                        await self?.handleVerifiedTransaction(transaction)
                        await transaction.finish()
                    }
                } catch {
                    // Transaction failed verification — skip
                }
            }
        }
    }

    // MARK: - Load Products

    public func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let productIDs = Set(StoreProductID.allCases.map(\.rawValue))
            print("[StoreKit] Requesting products: \(productIDs)")
            let storeProducts = try await Product.products(for: productIDs)
            print("[StoreKit] Loaded \(storeProducts.count) products: \(storeProducts.map(\.id))")

            products = storeProducts.sorted { $0.price < $1.price }
            subscriptionProducts = storeProducts
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }
            consumableProducts = storeProducts
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }
            print("[StoreKit] Subscriptions: \(subscriptionProducts.count), Consumables: \(consumableProducts.count)")
        } catch {
            print("[StoreKit] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    public func purchase(_ product: Product) async {
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleVerifiedTransaction(transaction)
                await transaction.finish()
                purchaseState = .purchased

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                purchaseState = .pending

            @unknown default:
                purchaseState = .failed("Unknown purchase result.")
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore Purchases

    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isPremium ? .restored : .idle
        } catch {
            purchaseState = .failed("Could not restore purchases: \(error.localizedDescription)")
        }
    }

    // MARK: - Refresh Entitlements

    public func refreshEntitlements() async {
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productType == .autoRenewable {
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        foundActive = true
                        activeProductID = transaction.productID
                    }
                }
            } catch {
                // Skip unverified
            }
        }

        isPremium = foundActive
        if !foundActive {
            activeProductID = nil
        }
    }

    // MARK: - Server-Side Validation

    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        // Notify backend for server-side record keeping
        do {
            struct VerifyResponse: Codable {
                let success: Bool?
            }

            let backendID = StoreProductID(rawValue: transaction.productID)?.backendProductID ?? transaction.productID

            let _: VerifyResponse = try await APIService.shared.post(
                path: "/api/payments/verify-apple",
                body: [
                    "transaction_id": "\(transaction.id)",
                    "product_id": backendID,
                    "original_transaction_id": "\(transaction.originalID)",
                    "environment": "\(transaction.environment.rawValue)",
                    "bundle_id": Bundle.main.bundleIdentifier ?? "",
                ]
            )
        } catch {
            // Server validation failed — StoreKit local verification is still valid.
            // Backend can reconcile later via App Store Server Notifications.
        }

        await refreshEntitlements()
    }

    // MARK: - Verification Helper

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
}
