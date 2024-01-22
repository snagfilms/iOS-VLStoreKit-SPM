//
//  VLSubscritionPurchase.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 28/02/22.
//

import Foundation

extension VLStoreKitInternal:VLStoreKitFlowDelegate {
    
    internal func listenForCallback() {
        storeKitManager.storeKitDelegate = self
    }
    
    internal func checkIfProductAvailableAndInitateTransaction(withProductId productId:String) {
        storeKitManager.storeKitDelegate = self
        storeKitManager.fetchProductFromAppStore(productId: productId, transactionType: self.transactionType ?? .purchase)
    }
    
    internal func restorePurchase(checkForPreviousPurchases:Bool = false) {
        storeKitManager.storeKitDelegate = self
        triggerUserBeaconEvent(eventName: .custom(eventName: "paymentRestored"))
        storeKitManager.restorePreviousPurchase(transactionType: .restore, checkForPreviousPurchases: checkForPreviousPurchases)
    }
    
    internal func finishTransactions() {
        storeKitManager.finishInCompleteTransactions()
    }
    
    internal func getTransactionDetails() {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, let receiptData = NSData(contentsOf: appStoreReceiptURL) else {
            transactionDetailsCallback?(nil, .noTransactionDetailsFound)
            return
        }
        let receiptString = receiptData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        self.getTransactionDetailsAPICall(requestParams: ["receipt":receiptString]) { [weak self] (receiptDetails:VLSubscriptionReceiptDetails?, success) in
            guard let weakSelf = self else { return }
            guard let receiptDetails = receiptDetails, success == true else {
                weakSelf.transactionDetailsCallback?(nil,.noTransactionDetailsFound)
                return
            }
            let storeKitModel = VLStoreKitModel(withTransactionId: receiptDetails.gatewayChargeId, originalTransactionId: receiptDetails.paymentUniqueId, productId:receiptDetails.planIdentifier ?? "", transactionDate: nil, transactionEndDate: nil, transactionReceipt: receiptData as Data)
            weakSelf.transactionDetailsCallback?(storeKitModel,.noTransactionDetailsFound)
        }
    }
    
    //MARK: StoreKit Delegates
    func transactionFinished(storeKitModel: VLStoreKitModel) {
        if storeKitDelegate != nil {
            triggerUserBeaconEvent(eventName: .custom(eventName: "paymentRestored"), transactionId: storeKitModel.originalTransactionId)
            storeKitDelegate?.transactionFinished(storeKitModel: storeKitModel, isSubscriptionSyncInProcess:makeInternalSubscriptionCall)
        }
        if makeInternalSubscriptionCall {
            if planDetails.planId == nil { return }
            self.syncSubscriptionStatusToVLServer(storeKitModel: storeKitModel, transactionType: self.transactionType ?? .purchase)
        }
        else {
            self.isFromSubscriptionFlow = false
        }
    }
    
    func transactionInProcess() {
        if storeKitDelegate != nil {
            storeKitDelegate?.transactionInProcess()
        }
    }
    
    func transactionFailed(error: TransactionError) {
        if storeKitDelegate != nil {
            triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : error.rawValue])
            storeKitDelegate?.transactionFailed(error: error)
        }
    }
    
    func restorePurchaseFinished(storeKitModel: VLStoreKitModel) {
        restorePurchaseCallback?(storeKitModel, nil)
    }
    
    func restorePurchaseFailed(error: TransactionError) {
        triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : error.rawValue])
        restorePurchaseCallback?(nil, error)
    }

    func connectionToAppStoreFailed(errorMessage: String) {
        if storeKitDelegate != nil {
            triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : "connection-to-app-store-failed"])
            storeKitDelegate?.connectionToAppStoreFailed(errorMessage: errorMessage)
        }
    }
    
    func transactionFromAppStoreFound(showOverlay: Bool) {
        if storeKitAppStoreSubscriptionDelegate != nil {
            triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : "transaction-from-app-store-found"])
            storeKitAppStoreSubscriptionDelegate?.transactionFromAppStoreFound(showOverlay: showOverlay)
        }
    }
    
    func transactionDoneFromAppStoreCompleted(storeKitModel: VLStoreKitModel) {
        if storeKitAppStoreSubscriptionDelegate != nil {
            storeKitAppStoreSubscriptionDelegate?.transactionDoneFromAppStoreCompleted(storeKitModel: storeKitModel)
        }
    }
}

///This is for OS 15 changes
@available(iOS 15.0, tvOS 15.0, *)
extension VLStoreKitInternal {

    internal func initateTransaction(productId:String, userUniqueIdentifier:String?) {
        Task {
            await self.initateNewPayment(productId:productId, userUniqueIdentifier:userUniqueIdentifier)
        }
    }
    
    private func initateNewPayment(productId:String, userUniqueIdentifier:String?) async {
        let result = await storeKitManager.requestForProduct(productIds: [productId])
        switch result {
        case .success(let shouldInitatePayment):
            if shouldInitatePayment {
                triggerUserBeaconEvent(eventName: .paymentInitiate)
                await proceedFurtherForPurchase(productId: productId, userUniqueIdentifier: userUniqueIdentifier)
            }
            break
        case .failure(let error):
            if storeKitDelegate != nil {
                
                triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : error.rawValue])
                storeKitDelegate?.transactionFailed(error: error)
            }
            break
        }
    }
    
    @MainActor
    private func proceedFurtherForPurchase(productId:String, userUniqueIdentifier:String?) async {
        do {
            switch try await storeKitManager.purchase(productId, userUniqueIdentifier: userUniqueIdentifier) {
            case .success(let storeKitModel):
                if storeKitDelegate != nil {
                    triggerUserBeaconEvent(eventName: .paymentSuccess, transactionId: storeKitModel.originalTransactionId)
                    storeKitDelegate?.transactionFinished(storeKitModel: storeKitModel, isSubscriptionSyncInProcess: makeInternalSubscriptionCall)
                }
                if makeInternalSubscriptionCall {
                    if planDetails.planId == nil { return }
                    self.syncSubscriptionStatusToVLServer(storeKitModel: storeKitModel, transactionType: self.transactionType ?? .purchase)
                }
                break
            case .failure(let error):
                if storeKitDelegate != nil {
                    triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : error.rawValue])
                    storeKitDelegate?.transactionFailed(error: error)
                }
                break
            }
        } catch {
            if storeKitDelegate != nil {
                triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : "transaction-failed"])
                storeKitDelegate?.transactionFailed(error: .transactionFailed)
            }
        }
    }
    
    internal func restorePurchase() {
        Task {
            switch await storeKitManager.restorePurchase() {
            case .success(let storeKitModel):
                triggerUserBeaconEvent(eventName: .custom(eventName: "paymentRestored"), transactionId: storeKitModel.originalTransactionId)
                restorePurchaseCallback?(storeKitModel, nil)
                break
            case .failure(let error):
                triggerUserBeaconEvent(eventName: .paymentFailed, additionalData: ["reason" : error.rawValue])
                restorePurchaseCallback?(nil, error)
                break
            }
        }
    }
    
    internal func getTransactionDetailsForV2() {
        Task {
            switch await storeKitManager.restorePurchase() {
            case .success(let storeKitModel):
                transactionDetailsCallback?(storeKitModel, nil)
                break
            case .failure(let error):
                transactionDetailsCallback?(nil, error)
                break
            }
        }
    }
}
