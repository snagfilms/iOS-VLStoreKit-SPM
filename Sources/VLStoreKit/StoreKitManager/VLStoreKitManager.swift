//
//  VLStoreKitManager.swift
//  AppCMS
//
//  Created by Gaurav Vig on 01/02/22.
//  Copyright © 2022 Viewlift. All rights reserved.
//

import Foundation
import StoreKit

internal protocol VLStoreKitFlowDelegate {
    func transactionFinished(storeKitModel:VLStoreKitModel)
    func transactionInProcess()
    func transactionFailed(error:TransactionError)
    func restorePurchaseFinished(storeKitModel:VLStoreKitModel)
    func restorePurchaseFailed(error:TransactionError)
    func connectionToAppStoreFailed(errorMessage:String)
    func transactionFromAppStoreFound(showOverlay:Bool)
    func transactionDoneFromAppStoreCompleted(storeKitModel:VLStoreKitModel)
}

class VLStoreKitManager:NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, VLBeaconEventProtocols {
    static let sharedStoreKitManager:VLStoreKitManager = {
        let instance = VLStoreKitManager()
        return instance
    }()
    
    lazy internal var storeKitModel:VLStoreKitModel? = nil
    var appStoreSubscriptionCallback:((_ storeKitModel:VLStoreKitModel) -> Void)?
    
    private var _subscriptionProduct:Any?
    @available(iOS 15.0, tvOS 15.0, *)
    internal var subscriptionProduct: [Product] {
        get {
            if let product = _subscriptionProduct as? [Product] {
                return product
            }
            return []
        }
        set { _subscriptionProduct = newValue }
    }
    
    private var _updateListenerTask:Any?
    @available(iOS 15.0, tvOS 15.0, *)
    internal var updateListenerTask: Task<Void, Error>? {
        get {
            if let listenerTask = _updateListenerTask as? Task<Void, Error> {
                return listenerTask
            }
            return nil
        }
        set { _updateListenerTask = newValue }
    }
    
    internal var isProductPurchased:Bool = false
    internal var checkingRestorePurchaseOnFirstLaunch:Bool = false
    internal var isMakingPurchase:Bool = false
    internal var productsRequest:SKProductsRequest?
    internal var isOnlyFetchingProductDetails = false
    internal var isFromSubscriptionFlow = false
    internal var isPerformingRestorePurchase = false
    internal var isSubscriptionInitiatedFromAppStore = false
    var storeKitDelegate:VLStoreKitFlowDelegate?
    internal var completedFetchingProducts:((Array<SKProduct>) ->Void)? = nil
    internal var isRestoreTransactionComplete = false
    internal var restoreTransactionDict:Dictionary<String, Any> = [:]
    internal var transactionType:TransactionType = .productFetch
    
    private override init() {
        super.init()
        
        self.setupDelegate()
    }
    
    private func setupDelegate() {
        if #available(iOS 15.0, tvOS 15.0, *) {
            if VLStoreKitInternal.shared.supportedAPIVersion == .V2 {
                self.initaliseBasicSettings()
            }
            else {
                SKPaymentQueue.default().add(self)
            }
        }
        else {
            SKPaymentQueue.default().add(self)
        }
    }
    
    /**
     *  Method to fetch product from iTunes for product identifier
     *
     *  @param pId product identifier
     */
    func fetchProductsFromAppStore(productIds:Set<String>, _ fetchingProducts:((Array<SKProduct>) -> Void)?) {
        if canMakePurchases() {
            isOnlyFetchingProductDetails = true
            checkingRestorePurchaseOnFirstLaunch = false
            isMakingPurchase = false
            if productsRequest != nil {
                productsRequest?.cancel()
                productsRequest = nil
            }
            productsRequest = SKProductsRequest(productIdentifiers: productIds)
            productsRequest?.delegate = self
            productsRequest?.start()
            completedFetchingProducts = fetchingProducts
        }
        else {
            fetchingProducts?([])
        }
    }
    
    func productsRequest (_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.setupDelegate()
        
        if !isOnlyFetchingProductDetails {
            let count : Int = response.products.count
            if (count > 0)
            {
                productsRequest?.cancel()
                productsRequest = nil
                self.initiatePurchase(purchaseProducts: response.products)
            }
            else
            {
                productsRequest?.cancel()
                productsRequest = nil
                var errorType = TransactionError.productNotAvailable
                if !checkingRestorePurchaseOnFirstLaunch {
                    if self.transactionType == .purchase
                    {
                        errorType = .noProductAvailableForPurchase
                    }
                    else if self.transactionType == .rent
                    {
                        errorType = .noProductAvailableForRent
                    }
                }
                if storeKitDelegate != nil {
                    storeKitDelegate?.transactionFailed(error: errorType)
                }
            }
        }
        else
        {
            productsRequest?.cancel()
            productsRequest = nil
            if completedFetchingProducts != nil {
                completedFetchingProducts?(response.products)
            }
        }
    }
    
    /**
     *  Method to determine whether user can make purchase
     *
     *  @return BOOL value with determination
     */
    internal func canMakePurchases() -> Bool{
        #if targetEnvironment(simulator)
        return false
        #else
        if #available(iOS 15.0, tvOS 15.0, *) {
            return VLStoreKitInternal.shared.supportedAPIVersion == .V2 ? AppStore.canMakePayments : SKPaymentQueue.canMakePayments()
        }
        else {
            return SKPaymentQueue.canMakePayments()
        }
        #endif
    }
    
    deinit {
        if #available(iOS 15.0, tvOS 15.0, *) {
            if VLStoreKitInternal.shared.supportedAPIVersion == .V2 {
                cancelListenerTask()
            }
        }
    }
}
