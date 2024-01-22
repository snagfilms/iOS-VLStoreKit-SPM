//
//  VLStoreKitNewChanges.swift
//  AppCMS
//
//  Created by Gaurav Vig on 01/02/22.
//  Copyright © 2022 Viewlift. All rights reserved.
//

import Foundation
import StoreKit

enum StoreError: Error {
    case failedVerification
}

@available(iOS 15.0, tvOS 15.0,  *)
extension VLStoreKitManager: VLBeaconEventProtocols {
    func initaliseBasicSettings() {
        self.subscriptionProduct = []
        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()
    }
    
    @MainActor
    func requestForProduct(productIds:[String]) async -> Result<Bool, TransactionError> {
        //Initialize the store by starting a product request.
        return await requestProducts(productIds: productIds)
    }
    
    @MainActor
    private func requestProducts(productIds:[String]) async -> Result<Bool, TransactionError> {
        do {
            subscriptionProduct = try await Product.products(for: productIds)
            return .success(true)
        } catch {
            return .failure(.productNotAvailable)
        }
    }
    
    @discardableResult
    func purchase(_ productId: String, userUniqueIdentifier:String?) async throws -> Result<VLStoreKitModel, TransactionError> {
        guard let product = subscriptionProduct.first(where: {$0.id == productId}) else { return .failure(.productIdNotFound) }
        var options:Set<Product.PurchaseOption> = []
        if let userId = userUniqueIdentifier, let uuid = UUID(uuidString: userId) {
            options = [.appAccountToken(uuid)]
        }
        //Begin a purchase.
        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            //Deliver content to the user.
            let isValidTransaction = await isValidTransaction(transaction)
            //Always finish a transaction.
            await transaction.finish()
            if isValidTransaction && !isFromSubscriptionFlow && self.appStoreSubscriptionCallback != nil {
                self.appStoreSubscriptionCallback?(VLStoreKitModel(withTransactionId: String(transaction.id), originalTransactionId: String(transaction.originalID), productId: transaction.productID, transactionDate: transaction.purchaseDate, transactionEndDate: transaction.expirationDate, transactionReceipt: transaction.jsonRepresentation))
            }
            return .success(VLStoreKitModel(withTransactionId: String(transaction.id), originalTransactionId: String(transaction.originalID), productId: transaction.productID, transactionDate: transaction.purchaseDate, transactionEndDate: transaction.expirationDate, transactionReceipt: transaction.jsonRepresentation))
        case .userCancelled:
            return .failure(.transactionCancelled)
        case .pending:
            return .failure(.transactionPending)
        default:
            return .failure(.transactionFailed)
        }
    }

    func isPurchased(_ productIdentifier: String) async throws -> Bool {
        //Get the most recent transaction receipt for this `productIdentifier`.
        guard let result = await Transaction.latest(for: productIdentifier) else {
            //If there is no latest transaction, the product has not been purchased.
            return false
        }

        let transaction = try checkVerified(result)

        //Ignore revoked transactions, they're no longer purchased.

        //For subscriptions, a user can upgrade in the middle of their subscription period. The lower service
        //tier will then have the `isUpgraded` flag set and there will be a new transaction for the higher service
        //tier. Ignore the lower service tier transactions which have been upgraded.
        return transaction.revocationDate == nil && !transaction.isUpgraded
    }
    
    @MainActor
    func restorePurchase() async -> Result<VLStoreKitModel, TransactionError> {
        ///TODO: Need to check
//        try? await AppStore.sync()
        await getProductPurchases()
        return storeKitModel != nil ? .success(storeKitModel!) : .failure(.noRestorePurchaseFound)
    }
    
    private func getProductPurchases() async {
        //Iterate through all of the user's purchased products.
        var purchasedSubscriptions: [Transaction] = []
        for await result in Transaction.all {
            //Don't operate on this transaction if it's not verified.
            if case .verified(let transaction) = result {
                //Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .autoRenewable:
                    purchasedSubscriptions.append(transaction)
                default:
                    //This type of product isn't displayed in this view.
                    break
                }
            }
        }
        if purchasedSubscriptions.count > 0 {
            let latestTransaction = getTheLatestTransaction(transactions: purchasedSubscriptions)
            storeKitModel = VLStoreKitModel(withTransactionId: String(latestTransaction.id), originalTransactionId: String(latestTransaction.originalID), productId: latestTransaction.productID, transactionDate: latestTransaction.purchaseDate, transactionEndDate: latestTransaction.expirationDate, transactionReceipt: latestTransaction.jsonRepresentation)
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    //Deliver content to the user.
                    let isValidTransaction = await self.isValidTransaction(transaction)
                    //Always finish a transaction.
                    await transaction.finish()
                    if isValidTransaction && self.appStoreSubscriptionCallback != nil && !self.isFromSubscriptionFlow {
                        self.appStoreSubscriptionCallback?(VLStoreKitModel(withTransactionId: String(transaction.id), originalTransactionId: String(transaction.originalID), productId: transaction.productID, transactionDate: transaction.purchaseDate, transactionEndDate: transaction.expirationDate, transactionReceipt: transaction.jsonRepresentation))
                    }
                } catch {
                    //StoreKit has a receipt it can read but it failed verification. Don't deliver content to the user.
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check if the transaction passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit has parsed the JWS but failed verification. Don't deliver content to the user.
            throw StoreError.failedVerification
        case .verified(let safe):
            //If the transaction is verified, unwrap and return it.
            return safe
        }
    }
    
    @MainActor
    @discardableResult
    func isValidTransaction(_ transaction: Transaction) async -> Bool {
        if transaction.revocationDate == nil {
            //If the App Store has not revoked the transaction, add it to the list of `purchasedIdentifiers`.
            return true
        } else {
            //If the App Store has revoked this transaction, remove it from the list of `purchasedIdentifiers`.
            return false
        }
    }
    
    @discardableResult
    private func getTheLatestTransaction(transactions:[Transaction]) -> Transaction {
        let latestTransaction = transactions.first!
        let sortedTransaction = transactions.sorted { trans1, trans2 in
            if trans1.expirationDate != nil && trans2.expirationDate != nil && trans1.expirationDate! > trans2.expirationDate! {
                return true
            }
            return false
        }
        return sortedTransaction.count > 0 ? sortedTransaction.first! : latestTransaction
    }
    
    internal func cancelListenerTask() {
        updateListenerTask?.cancel()
    }
}
