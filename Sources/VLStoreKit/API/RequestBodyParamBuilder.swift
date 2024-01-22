//
//  RequestParamBuilder.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 17/02/22.
//

import Foundation

struct RequestBodyParamBuilder {
    func createRequestBodyParams(storeKitModel:VLStoreKitModel, userIdentity:UserIdentity, planDetails:PlanDetails?, transactionalObject:VLTransactionalObject? = nil) -> [String:Any]{
        var requestParams:[String: Any] = ["subscription":"ios", "planIdentifier": storeKitModel.productId, "addEntitlement":true]
        #if os(iOS)
        requestParams["platform"] = "ios_phone"
        #else
        requestParams["platform"] = "ios_apple_tv"
        #endif
        if userIdentity.siteName != nil {
            requestParams["siteInternalName"] = userIdentity.siteName!
        }
        if let userId = VLStoreKitInternal.shared.productDetails?.userUniqueIdentifier ?? userIdentity.userId {
            requestParams["userId"] = userId
        }
        if userIdentity.siteId != nil {
            requestParams["siteId"] = userIdentity.siteId!
        }
        if planDetails?.planId != nil {
            requestParams["planId"] = planDetails?.planId!
        }
        if userIdentity.emailId != nil {
            requestParams["email"] = userIdentity.emailId!
        }
        if let transactionId = storeKitModel.originalTransactionId ?? storeKitModel.transactionId {
            requestParams["paymentUniqueId"] = transactionId
        }
        if let receiptData = storeKitModel.transactionReceipt {
            requestParams["receipt"] = receiptData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        }
        if let transactionalObject = transactionalObject {
            requestParams["transaction"] = "ios"
            requestParams["contentRequest"] = createTransactionPurchaseDict(transactionalObject:transactionalObject)
        }
        if #available(iOS 15.0, tvOS 15.0, *) {
            if VLStoreKitInternal.shared.supportedAPIVersion == .V2 {
                requestParams["receiptVersion"] = "v2"
            }
        }
        return requestParams
    }
    
    private func createTransactionPurchaseDict(transactionalObject:VLTransactionalObject) -> [String:Any]{
        var contentRequestDictionary = ["videoQuality": "HD"]
        if transactionalObject.contentId != nil
        {
            contentRequestDictionary["contentId"] = transactionalObject.contentId!
        }
        if transactionalObject.contentType != nil
        {
            contentRequestDictionary["contentType"] = transactionalObject.contentType!
        }
        if transactionalObject.seasonId != nil
        {
            contentRequestDictionary["seasonId"] = transactionalObject.seasonId!
        }
        if transactionalObject.seriesId != nil
        {
            contentRequestDictionary["seriesId"] = transactionalObject.seriesId!
        }
        return contentRequestDictionary
    }
}

