//
//  VLTransactionalPurchase.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 25/02/22.
//

extension VLStoreKitInternal {
    internal func getRegionAndCurrencyCode(productIds: Set<String>, callback: @escaping ((_ regionCode:String?, _ currencyCode:String?) ->  Void)) {
        storeKitManager.fetchProductsFromAppStore(productIds: productIds) { listOfAvailableProducts in
            guard !listOfAvailableProducts.isEmpty else {
                callback(nil, nil)
                return
            }
            for product in listOfAvailableProducts {
                if let currencyCode = product.priceLocale.currencyCode, let regionCode = product.priceLocale.regionCode {
                    self.storeCountryCode = regionCode
                    callback(regionCode, currencyCode)
                    break
                }
            }
        }
    }
}
