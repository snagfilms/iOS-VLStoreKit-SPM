//
//  VLStoreKitModel.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 22/02/22.
//

import Foundation

public struct VLStoreKitModel {
    public let transactionId: String?
    public let originalTransactionId: String?
    public let productId: String
    public let transactionDate: Date?
    public let transactionEndDate: Date?
    public let transactionReceipt: NSData?

    internal init(withTransactionId transactionId:String?, originalTransactionId:String?, productId:String, transactionDate:Date?, transactionEndDate:Date?, transactionReceipt:Data?) {
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.transactionDate = transactionDate
        self.transactionEndDate = transactionEndDate
        if transactionReceipt != nil {
            self.transactionReceipt = NSData(data: transactionReceipt!)
        }
        else {
            if let receiptURL = Bundle.main.appStoreReceiptURL {
                self.transactionReceipt = NSData(contentsOf:receiptURL)
            }
            else {
                self.transactionReceipt = nil
            }
        }
    }
}
