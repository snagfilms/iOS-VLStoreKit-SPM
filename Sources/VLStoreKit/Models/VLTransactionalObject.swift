//
//  VLTransactionalObject.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 25/02/22.
//

public struct VLTransactionalObject {
    let contentId:String?
    let seasonId:String?
    let seriesId:String?
    let planId:String?
    let contentType:String?
    
    public init(withContentId contentId:String, seasonId:String?, seriesId:String?, planId:String?, contentType:String?) {
        self.contentId = contentId
        self.seasonId = seasonId
        self.seriesId = seriesId
        self.planId = planId
        self.contentType = contentType
    }
}
