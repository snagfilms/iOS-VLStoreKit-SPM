//
//  VLStoreKitInternal.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 17/02/22.
//

import Foundation
import StoreKit

final class VLStoreKitInternal:APIService , VLBeaconEventProtocols{

    enum Result<Success, Failure> where Failure : Error {
        /// A success, storing a `Success` value.
        case success(Success)
        /// A failure, storing a `Failure` value.
        case failure(Failure)
    }
    
    static public let shared:VLStoreKitInternal = {
        let instance = VLStoreKitInternal()
        instance.setupConfiguration()
        return instance
    }()
    
    internal var authorizationToken:String? {
        didSet {
            if authorizationToken != nil {
                userIdentity = JWTTokenParser().jwtTokenParser(jwtToken: authorizationToken!)
            }
        }
    }
    
    internal var storeKitManager:VLStoreKitManager {
        get {
            return VLStoreKitManager.sharedStoreKitManager
        }
    }
    
    private let bundleIdentifier = "com.viewlift.vlstorekit"
    internal var supportedAPIVersion:VLStoreKit.APIVersion = .V1
    internal var apiUrl:String?
    internal var apiKey:String?
    internal var productDetails:VLProductDetails?
    internal var userIdentity:UserIdentity?
    lazy internal var planDetails:PlanDetails = PlanDetails()
    internal var storeKitModel:VLStoreKitModel?
    internal var transactionType:TransactionType?
    internal weak var storeKitDelegate:VLStoreKitDelegate?
    internal weak var storeKitAppStoreSubscriptionDelegate:VLStoreKitAppStoreSubscriptionDelegate?
    internal weak var storeKitSubscriptionSyncDelegate:VLStoreKitSubscriptionSyncDelegate?
    internal weak var socketSyncDelegate:VLStoreKitSocketMessageDelegate?
    internal var restorePurchaseCallback:((_ storeKitModel:VLStoreKitModel?, _ error:TransactionError?) -> Void)?
    lazy internal var retryCountForSubscriptionUpdate:Int = 0
    private(set) var deviceId:String?
    internal var makeInternalSubscriptionCall:Bool = false
    typealias subscriptionSyncCallbackHandler = ((_ subscriptionResponse: SubscriptionSyncResponse?, _ errorCode:String?) -> Void)
    internal var subscriptionSyncCallback: subscriptionSyncCallbackHandler?
    lazy private(set) internal var transactionalPurchaseObject:VLTransactionalObject? = nil
    lazy internal var webSocketClient:Socket? = nil
    internal var storeCountryCode:String? = nil
    internal var isFromSubscriptionFlow = false
    lazy internal var transactionDetailsCallback:((_ storeKitModel:VLStoreKitModel?, _ error:TransactionError?) -> Void)? = nil
    
    internal func initateTransaction(productDetails: VLProductDetails, transactionType:TransactionType = .purchase, deviceId:String? = nil, makeInternalSubscriptionCall:Bool = false, planId:String? = nil) {
        self.productDetails = productDetails
        self.deviceId = deviceId
        self.transactionType = transactionType
        self.makeInternalSubscriptionCall = makeInternalSubscriptionCall
        self.isFromSubscriptionFlow = true
        if planId != nil {
            planDetails.planId = planId
        }
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                self.initateTransaction(productId: productDetails.productId, userUniqueIdentifier: productDetails.userUniqueIdentifier)
            }
            else {
                self.checkIfProductAvailableAndInitateTransaction(withProductId: productDetails.productId)
            }
        }
        else {
            self.checkIfProductAvailableAndInitateTransaction(withProductId: productDetails.productId)
        }
    }
    
    internal func initateTransaction(productDetails: VLProductDetails, transactionType:TransactionType = .purchase, deviceId:String? = nil, makeInternalSubscriptionCall:Bool = false, transactionalPurchaseObject:VLTransactionalObject?) {
        self.productDetails = productDetails
        self.deviceId = deviceId
        self.transactionType = transactionType
        self.makeInternalSubscriptionCall = makeInternalSubscriptionCall
        self.transactionalPurchaseObject = transactionalPurchaseObject
        self.planDetails.planId = transactionalPurchaseObject?.planId
        self.isFromSubscriptionFlow = true
        
        triggerUserBeaconEvent(eventName: .cardAdded)
        
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                self.initateTransaction(productId: productDetails.productId, userUniqueIdentifier: productDetails.userUniqueIdentifier)
            }
            else {
                self.checkIfProductAvailableAndInitateTransaction(withProductId: productDetails.productId)
            }
        }
        else {
            self.checkIfProductAvailableAndInitateTransaction(withProductId: productDetails.productId)
        }
    }
    
    internal func initateRestorePurchase(restorePurchaseCallback: @escaping((_ storeKitModel:VLStoreKitModel?, _ error:TransactionError?) -> Void)) {
        self.transactionType = .restore
        self.isFromSubscriptionFlow = true
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                self.restorePurchase()
            }
            else {
                self.restorePurchase(checkForPreviousPurchases: false)
            }
        }
        else {
            self.restorePurchase()
        }
        self.restorePurchaseCallback = restorePurchaseCallback
    }
    
    internal func checkPreviousTransaction(restorePurchaseCallback: @escaping((_ storeKitModel:VLStoreKitModel?, _ error:TransactionError?) -> Void)) {
        self.transactionType = .restore
        self.isFromSubscriptionFlow = true
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                self.restorePurchase()
            }
            else {
                self.restorePurchase(checkForPreviousPurchases: false)
            }
        }
        else {
            self.restorePurchase(checkForPreviousPurchases: true)
        }
        self.restorePurchaseCallback = restorePurchaseCallback
    }
    
    internal func getTransactionDetailsFromApple(transactionDetailsCallback:@escaping((_ storeKitModel:VLStoreKitModel?, _ error:TransactionError?) -> Void)) {
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                self.getTransactionDetailsForV2()
            }
            else {
                self.getTransactionDetails()
            }
        }
        else {
            self.getTransactionDetails()
        }
        self.transactionDetailsCallback = transactionDetailsCallback
    }
    
    internal func fetchRegionAndCurrencyCode(productIds: Set<String>, callback: @escaping ((_ regionCode:String?, _ currencyCode:String?) ->  Void)) {
        self.getRegionAndCurrencyCode(productIds: productIds, callback: callback)
    }
    
    internal func listenForStoreKitCallbacks() {
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                if !self.isFromSubscriptionFlow {
                    storeKitManager.appStoreSubscriptionCallback = { (storeKitModel) in
                        if self.storeKitAppStoreSubscriptionDelegate != nil {
                            VLStoreKitInternal.shared.storeKitAppStoreSubscriptionDelegate?.transactionDoneFromAppStoreCompleted(storeKitModel: storeKitModel)
                        }
                    }
                }
            }
            else {
                self.listenForCallback()
            }
        }
        else {
            self.listenForCallback()
        }
    }
    
    internal func deRegisterStoreKitCallbacks() {
        if #available(iOS 15.0, tvOS 15.0, *) {
            if supportedAPIVersion == .V2 {
                storeKitManager.appStoreSubscriptionCallback = nil
            }
            else {
                SKPaymentQueue.default().remove(VLStoreKitManager.sharedStoreKitManager)
            }
        }
        else {
            SKPaymentQueue.default().remove(VLStoreKitManager.sharedStoreKitManager)
        }
    }
    
    internal func finishInCompleteTransactions() {
        self.finishTransactions()
    }
    
    internal func syncSubscriptionStatusToVLServer(planId:String?, transactionId:String?, originalTransactionId:String?, productId:String, transactionReceipt:Data?, transactionType: TransactionType, subscriptionSyncCallback: subscriptionSyncCallbackHandler? = nil) {
        let storeKitModel = VLStoreKitModel(withTransactionId: transactionId, originalTransactionId: originalTransactionId, productId: productId, transactionDate: nil, transactionEndDate: nil, transactionReceipt: transactionReceipt)
        self.planDetails.planId = planId
        self.subscriptionSyncCallback = subscriptionSyncCallback
        self.transactionType = transactionType
        self.isFromSubscriptionFlow = true
        self.syncSubscriptionStatusToVLServer(storeKitModel: storeKitModel, transactionType: transactionType)
    }
    
    internal func syncTransactionPurchaseStatusToVLSystem(planId:String?, transactionId:String?, originalTransactionId:String?, productId:String, transactionReceipt:Data?, transactionType: TransactionType, transactionPurchaseObject:VLTransactionalObject) {
        let storeKitModel = VLStoreKitModel(withTransactionId: transactionId, originalTransactionId: originalTransactionId, productId: productId, transactionDate: nil, transactionEndDate: nil, transactionReceipt: transactionReceipt)
        self.planDetails.planId = planId
        self.transactionType = transactionType
        self.transactionalPurchaseObject = transactionalPurchaseObject
        self.isFromSubscriptionFlow = true
        self.syncSubscriptionStatusToVLServer(storeKitModel: storeKitModel, transactionType: transactionType)
    }
}

extension VLStoreKitInternal {
    private func setupConfiguration() {
		if let apiUrl = self.getBaseUrl() {
			self.apiUrl = apiUrl
		}
		else {
			var filePath:String?
			let classBundle = Bundle(for: type(of: self))
			if let classBundlePath = classBundle.path(forResource: "VLStoreKitLib", ofType: "bundle"), let bundle = Bundle(path: classBundlePath) {
				filePath = bundle.path(forResource: "Configuration", ofType: "plist")
			}
			if filePath == nil {
				guard let bundle = Bundle(identifier: bundleIdentifier) else {
					return
				}
				filePath = bundle.path(forResource: "Configuration", ofType: "plist")
			}
			
			guard let filePath else { return }
			if let configData = try? Data(contentsOf: URL(fileURLWithPath: filePath)), let configuration = try? PropertyListDecoder().decode(VLConfiguration.self, from: configData),
			   let apiUrl = configuration.apiUrl {
				self.apiUrl = apiUrl
			}
		}
    }
	
	private func getBaseUrl() -> String? {
		guard let bundlePath = Bundle.main.path(forResource: "SiteConfig", ofType: "plist"),
			  let dict = NSDictionary.init(contentsOfFile: bundlePath),
			  let apiEndpoint = dict["APIEndPoint"] as? String else {return nil}
		return apiEndpoint
	}
}
