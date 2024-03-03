//
//  VLStoreKitInternal+SubscriptionSync.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 28/02/22.
//

import Foundation

extension VLStoreKitInternal {
    
    internal func syncSubscriptionStatusToVLServer(storeKitModel:VLStoreKitModel, transactionType:TransactionType) {
        self.makeInternalSubscriptionCall = true
        self.retryCountForSubscriptionUpdate = 0
        switch transactionType {
        case .purchase, .restore:
            self.updateServerWithSubscriptionStatus(storeKitModel: storeKitModel)
            break
        case .buy, .rent:
            self.updateServerWithTransactionalPurchaseStatus(storeKitModel: storeKitModel)
        default:
            break
        }
    }
    
    internal func reSyncFailedTransactionalPurchase(userIdentifier:String, syncComplete:(() -> Void)? = nil) {
//        guard let reSyncTransactions = VLDBManager.sharedInstance.fetchAllTransactionsFromDatabase() else { return }
//        let filteredTransactions = reSyncTransactions.filter({$0.contentId != nil})
//        guard filteredTransactions.count > 0 else { return }
//        self.reSyncTransactionalPurchase(transactionalData: filteredTransactions, syncComplete: syncComplete)
    }

    private func updateServerWithSubscriptionStatus(storeKitModel:VLStoreKitModel) {
        guard let userIdentity = self.userIdentity else { return }
        let requestParam = RequestBodyParamBuilder().createRequestBodyParams(storeKitModel: storeKitModel, userIdentity: userIdentity, planDetails: planDetails)
        self.makeSubscriptionAPICall(requestParams: requestParam) { [weak self] (response:SubscriptionSyncResponse?, isSuccess, responseCode) in
            guard let checkedSelf = self else {return}
            if response == nil || !isSuccess {
                checkedSelf.retryCountForSubscriptionUpdate += 1
                if let statusCode = responseCode, statusCode == 400, checkedSelf.retryCountForSubscriptionUpdate < 3 {
                    checkedSelf.updateServerWithSubscriptionStatus(storeKitModel: storeKitModel)
                }
                else {
                    checkedSelf.retryCountForSubscriptionUpdate = 0
                    checkedSelf.callSubscriptionSyncDelegate(errorCode: response?.errorCode ?? "SubscriptionAPICallFailed", subscriptionSyncResponse: nil)
                }
            }
            else {
                checkedSelf.retryCountForSubscriptionUpdate = 0
                if response?.errorCode != nil {
                    checkedSelf.callSubscriptionSyncDelegate(errorCode: response?.errorCode ?? "SubscriptionAPICallFailed", subscriptionSyncResponse: response)
                }
                else {
                    checkedSelf.callSubscriptionSyncDelegate(errorCode: "Completed", subscriptionSyncResponse: response)
                }
            }
        }
    }
        
    private func updateServerWithTransactionalPurchaseStatus(storeKitModel:VLStoreKitModel) {
        guard let userIdentity = self.userIdentity else { return }
        guard let authToken = self.authorizationToken else { return }
        
        self.proceedForTransactionalPurchaseSync(storeKitModel: storeKitModel, userIdentity: userIdentity, transactionalObject: self.transactionalPurchaseObject, authToken: authToken)
    }
    
    private func proceedForTransactionalPurchaseSync(storeKitModel:VLStoreKitModel, userIdentity:UserIdentity, transactionalObject:VLTransactionalObject, authToken:String) {
        var requestParam = RequestBodyParamBuilder().createRequestBodyParams(storeKitModel: storeKitModel, userIdentity: userIdentity, planDetails: planDetails, transactionalObject: transactionalObject)
        if self.transactionType == .buy {
            requestParam["purchaseType"] = "PURCHASE"
        }
        else if self.transactionType == .rent {
            requestParam["purchaseType"] = "RENT"
        }
        self.makeTransactionalSubscriptionAPICall(requestParams: requestParam) { [weak self] (response, isSuccess, responseCode) in
            guard let checkedSelf = self else {return}
            if response == nil || !isSuccess {
                if let statusCode = responseCode, statusCode == 400, checkedSelf.retryCountForSubscriptionUpdate < 3 {
                    checkedSelf.proceedForTransactionalPurchaseSync(storeKitModel: storeKitModel, userIdentity: userIdentity, transactionalObject: transactionalObject, authToken: authToken)
                }
                else {
                    let errorCode = response?["code"] as? String ?? ""
                    checkedSelf.callTransactionalPurchaseSyncDelegate(errorCode: errorCode, isSuccess: false)
                }
            }
            else {
                self?.callTransactionalPurchaseSyncDelegate(errorCode: "Completed", isSuccess: true)
            }
        }
    }
    
    private func reSyncTransactionalPurchase(transactionalData:[TransactionData], syncComplete:(() -> Void)? = nil) {
        var transactionalPurchases = transactionalData
        let transactionalPurchase = transactionalPurchases.removeFirst()
        if let _transactionData = transactionalPurchase.transactionBody, let jsonData = try? JSONSerialization.jsonObject(with: _transactionData), let requestParam = jsonData as? Dictionary<String, Any> {
            self.updateSubscriptionStatusToVLSystem(contentId: transactionalPurchase.contentId ?? "", requestParam: requestParam) {
                if transactionalPurchases.count > 0 {
                    self.reSyncTransactionalPurchase(transactionalData: transactionalPurchases, syncComplete: syncComplete)
                }
                else {
                    syncComplete?()
                }
            }
        }
        else {
            if transactionalPurchases.count > 0 {
                reSyncTransactionalPurchase(transactionalData: transactionalPurchases)
            }
            else {
                syncComplete?()
            }
        }
    }
    
    private func updateSubscriptionStatusToVLSystem(contentId:String, requestParam:[String:Any], syncComplete:(()->Void)? = nil) {
        guard let authToken = self.authorizationToken else { return }
        if webSocketClient == nil {
            webSocketClient = Socket()
        }
        webSocketClient?.createWebSocket(with: authToken, socketConnectionCompletionHandler: { (_) in
            self.webSocketClient?.resetCompletionHandler()
            self.makeTransactionalSubscriptionAPICall(requestParams: requestParam) { [weak self] (response, isSuccess, responseCode) in
                guard let checkedSelf = self else {return}
                if response != nil && isSuccess {
                    checkedSelf.webSocketClient?.sendMessageToSocket(authToken: authToken)
                    VLDBManager.sharedInstance.removeTransactionObjectFromDatabase(contentId: contentId)
                }
                checkedSelf.webSocketClient = nil
                syncComplete?()
            }
        }, syncSocketAPIConnectionCompletionHandler: { _ in
            self.webSocketClient = nil
            syncComplete?()
        })
    }
    
    private func callSubscriptionSyncDelegate(errorCode:String, subscriptionSyncResponse:SubscriptionSyncResponse?) {
        let subscriptionSyncStatus = SubscriptionSyncStatus(rawValue: errorCode) ?? .subscriptionAPICallFailed
        if self.subscriptionSyncCallback != nil {
            self.subscriptionSyncCallback?(subscriptionSyncResponse, errorCode)
        }
        else if storeKitSubscriptionSyncDelegate != nil {
            switch subscriptionSyncStatus {
            case .completed:
                storeKitSubscriptionSyncDelegate?.subscriptionSyncCompleted(subscriptionSyncResponse: subscriptionSyncResponse!)
            default:
                storeKitSubscriptionSyncDelegate?.subscriptionSyncFailed(errorCode: subscriptionSyncStatus)
            }
        }
    }
    
    private func callTransactionalPurchaseSyncDelegate(errorCode:String, isSuccess:Bool) {
        let subscriptionSyncStatus = SubscriptionSyncStatus(rawValue: errorCode) ?? .subscriptionAPICallFailed
        if storeKitSubscriptionSyncDelegate != nil {
            storeKitSubscriptionSyncDelegate?.transactionPurchaseSync(isSyncCompleted: isSuccess, errorCode: subscriptionSyncStatus)
        }
    }
}
