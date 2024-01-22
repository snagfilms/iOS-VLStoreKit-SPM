//
//  HelperFunctions.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 17/02/22.
//

import Foundation
import UIKit

class HelperFunctions:NSObject {
    static func getUserAgent() -> String {
        let bundleDict = Bundle.main.infoDictionary!
        let appName = bundleDict["CFBundleName"] as! String
        let appVersion = bundleDict["CFBundleShortVersionString"] as! String
        let appDescriptor = appName + "/" + appVersion
        let currentDevice = UIDevice.current
        var osDescriptor = "iOS/" + currentDevice.systemVersion
        #if os(tvOS)
        osDescriptor = "tvOS/" + currentDevice.systemVersion
        #endif
        return appDescriptor + " " + osDescriptor + " (" + UIDevice.current.model + ")"
    }
    
    static func convertDateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        // initially set the format based on your datepicker date / server String
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let myString = formatter.string(from: date) // string purpose I add here
        // convert your string to date
        let yourDate = formatter.date(from: myString)
        //then again set the date format whhich type of output you need
        formatter.dateFormat = "dd-MMM-yyyy"
        // again convert your date to string
        let myStringDate = formatter.string(from: yourDate!)

        return myStringDate
    }

}
