//
//  VLProductDetails.swift
//  VLStoreKit
//
//  Created by Japneet Singh on 21/06/23.
//

import Foundation

public struct VLProductDetails {
    
    var productId : String
    var productName: String
    var productDesc: String
    var planType: String?
    var promotionCode: String?
    var purchaseType: String?
    var userUniqueIdentifier:String
    var paymentMethod : String?
    var currencyCode : String?
    var transactionId : String?
    var discountAmount: Int?
    var orderTotalAmount : Int?
    var orderSubTotalAmount: Int?
    var orderValue : Int?
    var orderTaxAmount: Int?
    var cartContents : [[String : String]]?
    var productDetails : [ [String : String] ]?
    var additionalData: [String: String]?
    
    public init(productId: String, productName: String, productDesc: String, planType: String? = nil, promotionCode: String? = nil, purchaseType: String? = nil, discountAmount: Int? = nil, userUniqueIdentifier: String, paymentMethod: String? = nil, currencyCode: String? = nil, transactionId: String? = nil, orderTotalAmount: Int? = nil, orderSubTotalAmount: Int? = nil, orderValue: Int? = nil, orderTaxAmount: Int? = nil, cartContents: [[String : String]]? = nil, productDetails: [[String : String]]? = nil, additionalData: [String : String]? = nil) {
        self.productId = productId
        self.productName = productName
        self.productDesc = productDesc
        self.planType = planType
        self.promotionCode = promotionCode
        self.purchaseType = purchaseType
        self.discountAmount = discountAmount
        self.userUniqueIdentifier = userUniqueIdentifier
        self.paymentMethod = paymentMethod
        self.currencyCode = currencyCode
        self.transactionId = transactionId
        self.orderTotalAmount = orderTotalAmount
        self.orderSubTotalAmount = orderSubTotalAmount
        self.orderValue = orderValue
        self.orderTaxAmount = orderTaxAmount
        self.cartContents = cartContents
        self.productDetails = productDetails
        self.additionalData = additionalData
    }
}
