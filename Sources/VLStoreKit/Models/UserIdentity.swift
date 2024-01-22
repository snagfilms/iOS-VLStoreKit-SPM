//
//  UserIdentity.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 17/02/22.
//

import Foundation

struct UserIdentity:Decodable {
    var userId:String?
    var emailId:String?
    var phoneNumber:String?
    var siteName:String?
    var siteId:String?
    var countryCode:String?

    enum CodingKeys:String, CodingKey {
        case userId, siteId, phoneNumber
        case emailId = "email"
        case siteName = "site"
    }
}

struct PlanDetails {
    var planId:String?
}

struct SubscriptionDetails {
    
}
