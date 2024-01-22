//
//  VLStoreKitBeaconHelper.swift
//
//
//  Created by NexG on 08/01/24.
//

import Foundation
import VLBeaconLib

class VLStoreKitBeaconHelper: NSObject {
    private static var _sharedInstance: VLBeacon?
    
    class func getInstance() -> VLBeacon {
        return _sharedInstance ?? VLBeacon.getInstance()
    }
    
    class func setUpBecaonInstance(sharedBeaconInstance: VLBeacon?) {
        VLStoreKitBeaconHelper._sharedInstance = sharedBeaconInstance
    }
}
