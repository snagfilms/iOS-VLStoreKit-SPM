//
//  VLBeaconEventProtocols.swift
//  VLStoreKit
//
//  Created by NEXGEN on 19/06/23.
//

import Foundation
import VLBeaconLib

internal protocol VLBeaconEventProtocols{
    func triggerUserBeaconEvent(eventName: UserBeaconEventEnum, transactionId: String?, additionalData: [String : String]?)
}

internal extension VLBeaconEventProtocols {
    
    func triggerUserBeaconEvent(eventName: UserBeaconEventEnum, transactionId: String? = nil, additionalData: [String : String]? = nil) {
        let productDetails = VLStoreKitInternal.shared.productDetails
        
        let userEventBody = UserBeaconEventStruct(eventName: eventName, source: "VLStoreKit", eventData: StoreKitPayload(planId: productDetails?.productId, planName: productDetails?.productName, planDesc: productDetails?.productDesc, planType: productDetails?.planType , paymentMethod: productDetails?.paymentMethod, promotionCode: productDetails?.promotionCode, discountAmount: productDetails?.discountAmount, purchaseType: productDetails?.purchaseType, orderSubTotalAmount: productDetails?.orderSubTotalAmount, orderTaxAmount: productDetails?.orderTaxAmount, orderTotalAmount: productDetails?.orderTotalAmount, currencyCode: productDetails?.currencyCode, transactionId: transactionId), additionalData: additionalData, tokenIdentity: VLStoreKitBeaconHelper.getInstance()?.tokenIdentity)
        
        VLStoreKitBeaconHelper.getInstance()?.authorizationToken = VLStoreKitInternal.shared.authorizationToken
        VLStoreKitBeaconHelper.getInstance()?.triggerBeaconEvent(userEventBody)
    }
}
