//
//  VLDBManager.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 28/02/22.
//

import Foundation
import CoreData

final class VLDBManager {
    lazy private var persistentContainer: NSPersistentContainer = NSPersistentContainer(name: "VLStoreKitModel")
    private var managedObjectContext: NSManagedObjectContext!
    private let bundleIdentifier = "com.viewlift.vlstorekit"
    static let sharedInstance:VLDBManager = {
        let instance = VLDBManager()
        instance.engageSupport()
        return instance
    }()
    
    private func engageSupport() {
        persistentContainer.loadPersistentStores() { (description, error) in
        }
        
        var modelURL:URL?
        let classBundle = Bundle(for: type(of: self))
        if let classBundlePath = classBundle.path(forResource: "VLStoreKitLib", ofType: "bundle"), let bundle = Bundle(path: classBundlePath) {
            modelURL = bundle.url(forResource: "VLStoreKitModel", withExtension:"momd")
        }
        if modelURL == nil {
            guard let bundle = Bundle(identifier: bundleIdentifier) else {
                return
            }
            modelURL = bundle.url(forResource: "VLStoreKitModel", withExtension:"momd")
        }
        guard let _modelURL = modelURL, let mom = NSManagedObjectModel(contentsOf: _modelURL) else {
            return
        }
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        
        managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        
        #if os(iOS)
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            fatalError("Unable to resolve document directory")
        }
        #else
        guard let docURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last else {
            fatalError("Unable to resolve document directory")
        }
        #endif
        
        let storeURL = docURL.appendingPathComponent("VLStoreKitModel.sqlite")
        
        do {
            try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        } catch {
        }
    }
    
    //MARK: Method to add transaction data for user in database
    func addTransactionToDatabase(contentId: String, transactionData: Data)
    {
        if transactionData.isEmpty == false, let userId = VLStoreKitInternal.shared.userIdentity?.userId {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TransactionData")
            fetchRequest.predicate = NSPredicate(format: "userId == %@ && contentId == %@", userId, contentId)
            do
            {
                let object = try managedObjectContext.fetch(fetchRequest)
                if object.count == 1 {
                    if let responseData = object.first as? TransactionData {
                        responseData.userId = userId
                        responseData.contentId = contentId
                        responseData.transactionBody = transactionData
                        saveContext()
                    }
                }
                else {
                    if let responseData = NSEntityDescription.insertNewObject(forEntityName: "TransactionData", into: managedObjectContext) as? TransactionData {
                        responseData.userId = userId
                        responseData.contentId = contentId
                        responseData.transactionBody = transactionData
                        saveContext()
                    }
                }
            }
            catch {
            }
        }
    }
    
    //MARK: Fetch all transaction from database for a user
    func fetchAllTransactionsFromDatabase() -> [TransactionData]? {
        if let userId = VLStoreKitInternal.shared.userIdentity?.userId {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TransactionData")
            do {
                fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                let results = try managedObjectContext.fetch(fetchRequest)
                if let resultsFiltered = results as? [TransactionData] {
                    if resultsFiltered.count > 0 {
                        return resultsFiltered
                    }
                }
                return nil
            }
            catch {
            }
        }
        return nil
    }

    //MARK: Remove transaction object from Database after resync
    func removeTransactionObjectFromDatabase(contentId: String) {
        if let userId = VLStoreKitInternal.shared.userIdentity?.userId {
            let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "TransactionData")
            deleteFetch.predicate = NSPredicate(format: "userId == %@ && contentId == %@", userId, contentId)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
            do {
                if let count = self.managedObjectContext.persistentStoreCoordinator?.persistentStores.count, count > 0 {
                    try managedObjectContext.execute(deleteRequest)
                    try managedObjectContext.save()
                }
            }
            catch {
            }
        }
    }
    
    private func deleteDataFromDB(entityName:String, predicate:NSPredicate? = nil) {
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        deleteFetch.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
        do
        {
            if let count = self.managedObjectContext.persistentStoreCoordinator?.persistentStores.count, count > 0 {
                let deleteResult = try managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [managedObjectContext])
                }
            }
        }
        catch {
        }
    }
    
    private func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
        }
    }
}
