//
//  VLStoreKitManger+v1.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 21/02/22.
//

import Foundation
import StoreKit

extension VLStoreKitManager {
    
    func fetchProductFromAppStore(productId:String, transactionType:TransactionType) {
        self.transactionType = transactionType
        if (canMakePurchases())
        {
            triggerUserBeaconEvent(eventName: .paymentInitiate)
            isOnlyFetchingProductDetails = false
            isProductPurchased = false
            isMakingPurchase = true
            checkingRestorePurchaseOnFirstLaunch = false
            isFromSubscriptionFlow = true
            if productsRequest != nil {
                productsRequest?.cancel()
                productsRequest = nil
            }
            productsRequest = SKProductsRequest(productIdentifiers: Set([productId]))
            productsRequest?.delegate = self
            productsRequest?.start()
        }
        else
        {
            if storeKitDelegate != nil {
                storeKitDelegate?.transactionFailed(error: .productNotAvailable)
            }
        }
    }
    
    /**
     *  Method to restore all completed transactions for user
     */
    func restorePreviousPurchase(transactionType:TransactionType, checkForPreviousPurchases:Bool) {
        self.transactionType = transactionType
        if (canMakePurchases()) {
            isMakingPurchase = false
            isFromSubscriptionFlow = true
            isPerformingRestorePurchase = true
            isOnlyFetchingProductDetails = false
            isProductPurchased = false
            checkingRestorePurchaseOnFirstLaunch = checkForPreviousPurchases
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
        else {
            checkingRestorePurchaseOnFirstLaunch = false
            if storeKitDelegate != nil {
                isFromSubscriptionFlow = false
                storeKitDelegate?.restorePurchaseFailed(error: .restoreTransactionFailed)
            }
        }
    }

    //MARK: StoreKit Delegate methods
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
    {
        print("TRANSACTION PROCESSING paymentQueue")
        if !isOnlyFetchingProductDetails {
            var isAllRestoreTransaction = true
            for transaction in transactions {
                if transaction.transactionState == SKPaymentTransactionState.failed || transaction.transactionState == SKPaymentTransactionState.purchasing {
                    isAllRestoreTransaction = false
                    
                    print("TRANSACTION PROCESSING paymentQueue failed")
                    
                    break
                }
            }
            var transactionArray = transactions
            if isAllRestoreTransaction && !isMakingPurchase {
                finishTransactions(tranasctions: queue.transactions)
                let transactionTuple = getTheLatestTransaction(transactions: transactions)
                var updatedTransactionList = transactions
                updatedTransactionList.remove(at: transactionTuple.1)
                finishTransactions(tranasctions: updatedTransactionList)
                transactionArray.removeAll()
                transactionArray.append(transactionTuple.0)
            }
            for transaction in transactionArray
            {
                switch transaction.transactionState
                {
                case .purchasing:
                    print("TRANSACTION PROCESSING paymentQueue purchasing")
                    if storeKitDelegate != nil {
                        storeKitDelegate?.transactionInProcess()
                    }
                    break
                case .purchased:
                    print("TRANSACTION PROCESSING paymentQueue purchased")
                    var receiptData:NSData?
                    if let receiptURL = Bundle.main.appStoreReceiptURL {
                        receiptData = NSData(contentsOf:receiptURL)
                    }
                    if transaction.transactionIdentifier == nil && receiptData == nil {
                        SKPaymentQueue.default().finishTransaction(transaction)
                        if storeKitDelegate != nil {
                            storeKitDelegate?.transactionFailed(error: .transactionFailed)
                        }
                    }
                    else {
                        if !checkingRestorePurchaseOnFirstLaunch && isFromSubscriptionFlow {
                            print("TRANSACTION PURCHASED FINISHED CALLING")
                            SKPaymentQueue.default().finishTransaction(transaction)
                            self.isProductPurchased = true
                            
                            DispatchQueue.main.async {
                                print("TRANSACTION PURCHASED CALLING DELEGATE")
                                self.getTransaction(transaction: transaction, andReceiptData: receiptData)
                            }
                        }
                        else {
                            SKPaymentQueue.default().finishTransaction(transaction)
                            if !isFromSubscriptionFlow && !isPerformingRestorePurchase && isSubscriptionInitiatedFromAppStore {
                                if storeKitDelegate != nil {
                                    storeKitDelegate?.transactionDoneFromAppStoreCompleted(storeKitModel: VLStoreKitModel(withTransactionId: transaction.transactionIdentifier, originalTransactionId: transaction.original?.transactionIdentifier, productId: transaction.payment.productIdentifier, transactionDate: transaction.transactionDate, transactionEndDate: nil, transactionReceipt: nil))
                                }
                                isSubscriptionInitiatedFromAppStore = false
                            }
                            else if isPerformingRestorePurchase {
                                var userInfo:Dictionary<String, Any>  = ["success": true, "productIdentifier":transaction.payment.productIdentifier]
                                if let transactionId = transaction.original?.transactionIdentifier ?? transaction.transactionIdentifier {
                                    userInfo["transactionId"] = transactionId
                                }
                                if receiptData != nil {
                                    userInfo["receiptData"] = receiptData!
                                }
                                checkingRestorePurchaseOnFirstLaunch = false
                                isRestoreTransactionComplete = true
                                restoreTransactionDict = userInfo
                            }
                        }
                    }
                    break
                case .failed:
                    print("TRANSACTION PROCESSING paymentQueue failed1")
                    SKPaymentQueue.default().finishTransaction(transaction)
                    self.isProductPurchased = false
                    if !self.isFromSubscriptionFlow {
                        if storeKitDelegate != nil {
                            storeKitDelegate?.transactionFromAppStoreFound(showOverlay: false)
                            return
                        }
                    }
                    isFromSubscriptionFlow = false
                    if storeKitDelegate != nil {
                        storeKitDelegate?.transactionFailed(error: .transactionFailed)
                    }
                   
                    break
                case .restored :
                    print("TRANSACTION PROCESSING paymentQueue restored")
                    if !isMakingPurchase {
                        let receiptURL:URL? = Bundle.main.appStoreReceiptURL
                        if receiptURL != nil && !self.isProductPurchased {
                            SKPaymentQueue.default().finishTransaction(transaction)
                            
                            self.isProductPurchased = true
                            checkingRestorePurchaseOnFirstLaunch = false
                            if !isFromSubscriptionFlow {
                                if storeKitDelegate != nil {
                                    storeKitDelegate?.transactionDoneFromAppStoreCompleted(storeKitModel: VLStoreKitModel(withTransactionId: transaction.transactionIdentifier, originalTransactionId: transaction.original?.transactionIdentifier, productId: transaction.payment.productIdentifier, transactionDate: transaction.transactionDate, transactionEndDate: nil, transactionReceipt: nil))
                                }
                            }
                            else {
                                let receiptData:NSData? = NSData(contentsOf: receiptURL!)
                                getTransaction(transaction: transaction, andReceiptData: receiptData)
                            }
                        }
                        else {
                            checkingRestorePurchaseOnFirstLaunch = false
                            SKPaymentQueue.default().finishTransaction(transaction)
                            if storeKitDelegate != nil {
                                isFromSubscriptionFlow = false
                                storeKitDelegate?.restorePurchaseFailed(error: .transactionFailed)
                            }
                        }
                    }
                    else {
                        SKPaymentQueue.default().finishTransaction(transaction)
                        if storeKitDelegate != nil {
                            isFromSubscriptionFlow = false
                            storeKitDelegate?.restorePurchaseFailed(error: .transactionFailed)
                        }
                    }
                    break
                case .deferred:
                    break
                @unknown default:
                    break
                }
                if self.isProductPurchased {
                    return
                }
            }
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue)
    {
        isPerformingRestorePurchase = false
        if !isOnlyFetchingProductDetails {
            if (queue.transactions.count == 0) {
                checkingRestorePurchaseOnFirstLaunch = false
                if let receiptURL = Bundle.main.appStoreReceiptURL, let _ = NSData(contentsOf: receiptURL) {
                    if storeKitDelegate != nil {
                        isFromSubscriptionFlow = false
                        storeKitDelegate?.restorePurchaseFinished(storeKitModel: VLStoreKitModel(withTransactionId: nil, originalTransactionId: nil, productId: "", transactionDate: nil, transactionEndDate: nil, transactionReceipt: nil))
                    }
                }
                else {
                    if storeKitDelegate != nil {
                        isFromSubscriptionFlow = false
                        storeKitDelegate?.restorePurchaseFailed(error: .noRestorePurchaseFound)
                    }
                }
            }
            else {
                if isRestoreTransactionComplete {
                    finishTransactions(tranasctions: queue.transactions)
                    if storeKitDelegate != nil {
                        isFromSubscriptionFlow = false
                        if restoreTransactionDict.isEmpty {
                            storeKitDelegate?.restorePurchaseFailed(error: .noRestorePurchaseFound)
                        }
                        else {
                            storeKitDelegate?.restorePurchaseFinished(storeKitModel: VLStoreKitModel(withTransactionId: nil, originalTransactionId: restoreTransactionDict["transactionId"] as? String, productId: restoreTransactionDict["productIdentifier"] as? String ?? "", transactionDate: nil, transactionEndDate: nil, transactionReceipt: nil))
                        }
                    }
                    isRestoreTransactionComplete = false
                    restoreTransactionDict.removeAll()
                }
                else if checkingRestorePurchaseOnFirstLaunch {
                    let transactionTuple = getTheLatestTransaction(transactions: queue.transactions)
                    var updatedTransactionList = queue.transactions
                    updatedTransactionList.remove(at: transactionTuple.1)
                    finishTransactions(tranasctions: updatedTransactionList)
                    if let receiptURL = Bundle.main.appStoreReceiptURL, transactionTuple.0.transactionState != .failed {
                        SKPaymentQueue.default().finishTransaction(transactionTuple.0)
                        getTransaction(transaction: transactionTuple.0, andReceiptData: NSData(contentsOf: receiptURL))
                    }
                    else {
                        checkingRestorePurchaseOnFirstLaunch = false
                        if storeKitDelegate != nil {
                            isFromSubscriptionFlow = false
                            storeKitDelegate?.restorePurchaseFailed(error: .noRestorePurchaseFound)
                        }
                    }
                }
            }
        }
        else {
//            if checkingRestorePurchaseOnFirstLaunch {
                if storeKitDelegate != nil {
                    isFromSubscriptionFlow = false
                    storeKitDelegate?.restorePurchaseFailed(error: .noRestorePurchaseFound)
                }
//            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error)
    {
        isPerformingRestorePurchase = false
        checkingRestorePurchaseOnFirstLaunch = false
        isFromSubscriptionFlow = false
        if storeKitDelegate != nil {
            storeKitDelegate?.restorePurchaseFailed(error: .restoreTransactionFailed)
        }
    }
    
    /**
     Method to manage the transaction and receipt
     
     @param transaction SKPaymentTransaction
     @param receiptData transaction receipt
     */
    private func getTransaction(transaction: SKPaymentTransaction, andReceiptData receiptData: NSData?) {
        switch transaction.transactionState
        {
        case .purchased:
            if transaction.transactionIdentifier != nil {
                if storeKitDelegate != nil {
                    isFromSubscriptionFlow = false
                    print("TRANSACTION PURCHASED CALLED DELEGATE")
                    storeKitDelegate?.transactionFinished(storeKitModel: VLStoreKitModel(withTransactionId:transaction.transactionIdentifier, originalTransactionId: transaction.original?.transactionIdentifier, productId: transaction.payment.productIdentifier, transactionDate: transaction.transactionDate, transactionEndDate: nil, transactionReceipt: nil))
                }
            }
            break
        case .restored :
            var userInfo:Dictionary<String, Any> = [:]
            isRestoreTransactionComplete = true
            checkingRestorePurchaseOnFirstLaunch = false
            if transaction.original != nil {
                if ((transaction.original!.transactionIdentifier != nil) && receiptData != nil) {
                    userInfo.merge(["success": true, "transactionId":transaction.original!.transactionIdentifier!,"receiptData":receiptData!, "productIdentifier":transaction.payment.productIdentifier], uniquingKeysWith: {(current, _ ) in current})
                    restoreTransactionDict = userInfo
                }
                else if (receiptData != nil) {
                    userInfo.merge(["success": true,"receiptData":receiptData!, "productIdentifier":transaction.payment.productIdentifier], uniquingKeysWith: {(current, _ ) in current})
                    restoreTransactionDict = userInfo
                }
                else if (transaction.original!.transactionIdentifier != nil) {
                    userInfo.merge(["success": true, "transactionId":transaction.original!.transactionIdentifier!,"productIdentifier":transaction.payment.productIdentifier], uniquingKeysWith: {(current, _ ) in current})
                    restoreTransactionDict = userInfo
                }
                else {
                    restoreTransactionDict = userInfo
                }
            }
            else if (receiptData != nil) {
                userInfo.merge(["success": true,"receiptData":receiptData!, "productIdentifier":transaction.payment.productIdentifier], uniquingKeysWith: {(current, _ ) in current})
                restoreTransactionDict = userInfo
            }
            else {
                restoreTransactionDict = userInfo
            }
            break
        case .deferred:
            break
        default:
            break
        }
    }
    
    /**
     *  Method to initiate purchase for valid product
     */
    internal func initiatePurchase(purchaseProducts:[SKProduct]) {
        self.isProductPurchased = false
        for transaction:SKPaymentTransaction in SKPaymentQueue.default().transactions
        {
            if transaction.transactionState == SKPaymentTransactionState.purchased
            {
                SKPaymentQueue.default().finishTransaction(transaction)
            }
            else if (transaction.transactionState == SKPaymentTransactionState.failed) {
                SKPaymentQueue.default().finishTransaction(transaction)
            }
            else if (transaction.transactionState == SKPaymentTransactionState.restored) {
                SKPaymentQueue.default().finishTransaction(transaction)
            }
        }
        if let product = purchaseProducts.first {
            purchaseProduct(product: product)
        }
        else {
            if storeKitDelegate != nil {
                isFromSubscriptionFlow = false
            storeKitDelegate?.transactionFailed(error: .productIdNotFound)
            }
        }
    }
    
    
    /**
     *  Method to initiate purchase product
     *
     *  @param product valid SKProduct to be purchased
     */
    private func purchaseProduct(product:SKProduct){
        if (canMakePurchases()) {
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        }
        else{
            if storeKitDelegate != nil {
                storeKitDelegate?.transactionFailed(error: .deviceNotSupported)
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        productsRequest = nil
        if !isOnlyFetchingProductDetails {
            if storeKitDelegate != nil {
                storeKitDelegate?.connectionToAppStoreFailed(errorMessage: error.localizedDescription)
            }
        }
        else {
            if completedFetchingProducts != nil {
                completedFetchingProducts?([])
            }
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        isSubscriptionInitiatedFromAppStore = true
        isFromSubscriptionFlow = false
        isPerformingRestorePurchase = false
        isOnlyFetchingProductDetails = false
        if storeKitDelegate != nil {
            storeKitDelegate?.transactionFromAppStoreFound(showOverlay: true)
        }
        return true
    }
    
    func initatePaymentProcess(payment:SKPayment) {
        SKPaymentQueue.default().add(payment)
        isSubscriptionInitiatedFromAppStore = true
        if storeKitDelegate != nil {
            storeKitDelegate?.transactionFromAppStoreFound(showOverlay: true)
        }
    }
    
    @discardableResult
    private func getTheLatestTransaction(transactions:[SKPaymentTransaction]) -> (SKPaymentTransaction, Int) {
        var latestTransaction = transactions[0]
        var latestTransactionIndex = 0
        for (index, transaction) in transactions.enumerated() {
            if let transactionDate = transaction.transactionDate, let lastestTransactionDate = latestTransaction.transactionDate, transactionDate.timeIntervalSince1970 > lastestTransactionDate.timeIntervalSince1970 {
                latestTransaction = transaction
                latestTransactionIndex = index
            }
        }
        return (latestTransaction, latestTransactionIndex)
    }
    
    internal func finishInCompleteTransactions() {
        print("Pending transactions count ----> \(SKPaymentQueue.default().transactions)")
        finishTransactions(tranasctions: SKPaymentQueue.default().transactions)
    }
    
    private func finishTransactions(tranasctions:[SKPaymentTransaction]) {
        tranasctions.filter{ $0.finishable }.forEach { transaction in
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
}

extension SKPaymentTransaction {
    var finishable: Bool {
        switch transactionState {
        case .purchasing:
            return false
        case .deferred, .failed, .purchased, .restored:
            return true
        @unknown default:
            return false
        }
    }
}
