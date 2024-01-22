//
//  VL.swift
//  AppCMS
//
//  Created by Gaurav Vig on 26/07/22.
//  Copyright © 2022 Viewlift. All rights reserved.
//

struct VLSubscriptionReceiptDetails:Decodable {
    let paymentUniqueId:String?
    let planIdentifier:String?
    let gatewayChargeId:String?
}
