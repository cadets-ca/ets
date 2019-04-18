//
//  CoreDataController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-30.
//
//

import Foundation
import CoreData
import UIKit

final class CoreDataController
{
    var persistentStoreCoordinator: NSPersistentStoreCoordinator
    var managedObjectContext: NSManagedObjectContext
    let loadRealStoreNotification = Notification.Name("loadRealStoreNotification")

    let oldURL: URL =
    {
        let applicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
        let storePath = applicationDocumentsDirectory.stringByAppendingPathComponent("Timesheets.sqlite")

        return URL(fileURLWithPath: storePath)
    }()
    
    let remoteURL: URL =
    {
        let applicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(. documentDirectory, .userDomainMask, true).last ?? ""
        let storePath = applicationDocumentsDirectory.stringByAppendingPathComponent("RemoteDatabase.sqlite")
        
        return URL(fileURLWithPath: storePath)
    }()
    
    let localURL: URL =
    {
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ca.cadets.Timesheets")!
        let path = groupURL.appendingPathComponent("Timesheets.sqlite")

        return path
    }()
    
    let emptyDatabseURL: URL =
    {
        let applicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
        let storePath = applicationDocumentsDirectory.stringByAppendingPathComponent("Empty.sqlite")
        
        return URL(fileURLWithPath: storePath)
    }()
    
    let sampleDatabaseURL: URL =
    {
        return Bundle.main.url(forResource: "Sample", withExtension: "sqlite")!
    }()
    
    init()
    {
        observerMode = UserDefaults().viewSharedDatabase
        let model = NSManagedObjectModel.mergedModel(from: nil)!
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        do
        {
            _ = try self.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at: emptyDatabseURL, options: iCloudPersistentStoreOptions)
            NotificationQueue.default.enqueue(Notification(name: loadRealStoreNotification), postingStyle: .whenIdle, coalesceMask: [.onName], forModes: nil)
        }
            
        catch let error as NSError
        {
            print("\(error.localizedDescription)")
        }
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.transitionToRealStore), name: loadRealStoreNotification, object: nil)
    }
    
    @objc func transitionToRealStore()
    {
        if FileManager.default.fileExists(atPath: localURL.path) == false
        {
            if FileManager.default.fileExists(atPath: oldURL.path) == true
            {
                do
                {
                    let oldStore = try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at: oldURL, options: iCloudPersistentStoreOptions)
                    try persistentStoreCoordinator.migratePersistentStore(oldStore, to: localURL, options: iCloudPersistentStoreOptions, withType: NSSQLiteStoreType)
                    try persistentStoreCoordinator.remove(oldStore)
                }
                    
                catch let error as NSError
                {
                    print("Could not move the database from the old to the new location.")
                    print("\(error.localizedDescription)")
                }
            }
                
            else
            {
                do
                {
                    try FileManager.default.copyItem(at: sampleDatabaseURL, to: localURL)
                }
                    
                catch let error as NSError
                {
                    print("Could not move the sample database to the new location and open it.")
                    print("\(error.localizedDescription)")
                }
            }
        }
        
        do
        {
            let targetURL = UserDefaults().viewSharedDatabase ? self.remoteURL : self.localURL
            
            for store in persistentStoreCoordinator.persistentStores
            {
                do
                {
                    try persistentStoreCoordinator.remove(store)
                }
                
                catch let error as NSError
                {
                    print("Could not remove the empty database store.")
                    print("\(error.localizedDescription)")
                }

            }
            
            try self.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at: targetURL, options: iCloudPersistentStoreOptions)
            managedObjectContext.reset()
            NotificationCenter.default.post(name: refreshEverythingNotification, object:self)
            dataModel.reloadFetchedResults(nil)
            dataModel.performSetup()
            dataModel.closeOpenAttendanceRecordsFromPreviousDays()
        }
            
        catch let error as NSError
        {
            print("\(error.localizedDescription)")
        }
        
        checkForCloudKitChanges()
        observerMode = UserDefaults.standard.viewSharedDatabase
        dataModel.becomeActive()
    }
    
    func toggleRemoteStore()
    {
        transitionToRealStore()

        if UserDefaults().viewSharedDatabase == false
        {
            do
            {
                try self.persistentStoreCoordinator.destroyPersistentStore(at: remoteURL, ofType: NSSQLiteStoreType, options: nil)
            }
                
            catch let error as NSError
            {
                print("\(error.localizedDescription)")
            }
        }
    }
    
    func checkForCloudKitChanges()
    {
        let defaults = UserDefaults.standard
        let cloudKitEnabled = !defaults.bool(forKey: "Disable Sync")
        let cloudKitAvailable = FileManager.default.ubiquityIdentityToken == nil ? false : true
        let delegate = UIApplication.shared.delegate as? TimesheetsAppDelegate

        switch (cloudKitEnabled, cloudKitAvailable, cloudKitController == nil)
        {
        case (true, true, true):
            delegate?.cloudKitController = CloudKitController()
        case (true, true, false):
            break
        default:
            delegate?.cloudKitController = nil
        }
    }
    
    var iCloudPersistentStoreOptions: [String: Any]
    {
        var localStoreOptions = [String: Any]()
        localStoreOptions[NSMigratePersistentStoresAutomaticallyOption] = true
        localStoreOptions[NSInferMappingModelAutomaticallyOption] = true
        localStoreOptions[NSSQLiteManualVacuumOption] = true
        localStoreOptions[NSSQLitePragmasOption] = ["journal_mode": "DELETE"]
        return localStoreOptions
    }
}
