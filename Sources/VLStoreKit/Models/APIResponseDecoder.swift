//
//  UserIdentity.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 17/02/22.
//

import Foundation

public struct SubscriptionSyncResponse:Decodable {
    public var subscriptionStatus:String?
    public var userId:String?
    public var name:String?
    public var errorCode:String?
    public var errorMessage:String?
    public var authorizationToken:String?
    public var provider:String?
    public var isSubscribed:Bool?
    public var refreshToken:String?
    public var emailId:String?
    
    enum CodingKeys:String, CodingKey {
        case subscriptionStatus, userId, name, authorizationToken, provider, isSubscribed, refreshToken
        case errorCode = "code"
        case errorMessage = "message"
        case emailId = "email"
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        subscriptionStatus = try? values.decode(String.self, forKey: .subscriptionStatus)
        userId = try? values.decode(String.self, forKey: .userId)
        name = try? values.decode(String.self, forKey: .name)
        errorCode = try? values.decode(String.self, forKey: .errorCode)
        errorMessage = try? values.decode(String.self, forKey: .errorMessage)
        authorizationToken = try? values.decode(String.self, forKey: .authorizationToken)
        provider = try? values.decode(String.self, forKey: .provider)
        isSubscribed = try? values.decode(Bool.self, forKey: .isSubscribed)
        refreshToken = try? values.decode(String.self, forKey: .refreshToken)
        emailId = try? values.decode(String.self, forKey: .emailId)
    }
}
