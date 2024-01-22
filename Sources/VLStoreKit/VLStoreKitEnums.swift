//
//  VLStoreKitEnums.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 22/02/22.
//

public enum TransactionType {
    case restore
    case purchase
    case rent
    case buy
    case productFetch
}

public enum TransactionError: String, Error {
    case transactionFailed = "transaction-failed"
    case transactionCancelled = "transaction-cancelled"
    case transactionPending = "transaction-pending"
    case unknown = "unknown"
    case productIdNotFound = "product-id-not-found"
    case productNotAvailable = "product-not-available"
    case noRestorePurchaseFound = "no-restore-purchase-found"
    case restoreTransactionFailed = "restore-transaction-failed"
    case deviceNotSupported = "device-not-supported"
    case noProductAvailableForRent = "no-product-available-for-rent"
    case noProductAvailableForPurchase = "no-product-available-for-purchase"
    case noTransactionDetailsFound = "no-transaction-details-found"
}

public enum SubscriptionSyncStatus:String, Error {
    case completed = "Completed"
    case paymentFailed = "PaymentServiceException"
    case duplicateUser = "DuplicateKeyException"
    case subscriptionServiceFailed = "SubscriptionServiceException"
    case userSubscriptionNotFound = "NotFoundException"
    case illegalArugment = "IllegalArgumentException"
    case illegalState = "IllegalStateException"
    case receiptExpired = "ReceiptExpiredException"
    case allRestoreSubscriptionError = "AllRestoreSubscriptionErrorCode"
    case subscriptionAPICallFailed = "SubscriptionAPICallFailed"
}
