//
//  VLDBModel.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 04/08/22.
//

import Foundation
import CoreData

@objc(TransactionData)

final class TransactionData: NSManagedObject {
    @NSManaged var userId: String?
    @NSManaged var contentId: String?
    @NSManaged var transactionBody: Data?
}

extension TransactionData {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TransactionData> {
        return NSFetchRequest<TransactionData>(entityName: "TransactionData")
    }
}
