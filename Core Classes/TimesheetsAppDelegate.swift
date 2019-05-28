//
//  TimesheetsAppDelegate.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-30.
//
//

import UIKit
import Foundation
import CoreData
import UserNotifications
import CloudKit

@UIApplicationMain
final class TimesheetsAppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    var importURL: URL?
    var timesheetsDataModel: TimesheetsDataModel!
    var coreDataController: CoreDataController!
    var cloudKitController: CloudKitController?
    var imageTransformer: ValueTransformer
    var tickerViews = [TickerViewController]()
    var applicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
    
    override init()
    {
        imageTransformer = ImageToDataTransformer()
        ValueTransformer.setValueTransformer(imageTransformer, forName: NSValueTransformerName("ImageToDataTransformer"))
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool
    {
        importURL = url
    
        let aircraftRequest = AircraftEntity.request
        let registrationSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftEntity.registration), ascending:true)
        aircraftRequest.sortDescriptors = [registrationSortDescriptor]
        guard let aircraftList = try? timesheetsDataModel.managedObjectContext.fetch(aircraftRequest) else {return false}
        
        func presentAlertOnTopmostViewController(_ alert: UIAlertController)
        {
            guard let rootController = window?.rootViewController else {return}
            
            if rootController.presentedViewController == nil
            {
                rootController.present(alert, animated:true, completion:nil)
            }
                
            else
            {
                rootController.presentedViewController?.present(alert, animated:true, completion:nil)
            }
        }
        
        for aircraft in aircraftList
        {
            if aircraft.status == .flying
            {
                let alert = UIAlertController(title: "Cannot Import", message: "You cannot import a database while you have aircraft flying. Retry when all aircraft are on the ground.", preferredStyle: .alert)
                let cancel = UIAlertAction(title: "Cancel", style: .default, handler:nil)
                alert.addAction(cancel)
                presentAlertOnTopmostViewController(alert)
                
                return true
            }
        }
    
        if trainingMode || observerMode
        {
            let alert = UIAlertController(title: "Cannot Import", message: "You cannot import a database while you are in training mode or observing shared records.", preferredStyle: .alert)
            let cancel = UIAlertAction(title: "Cancel", style: .default, handler:nil)
            alert.addAction(cancel)
            presentAlertOnTopmostViewController(alert)
            
            return true
        }
    
        let alert = UIAlertController(title: "Import Database", message: "Are you sure you want to import records? This will replace your existing pilots and flight records.", preferredStyle: .alert)
    
        let cancel = UIAlertAction(title: "Cancel", style: .default){_ in
            let manager = FileManager.default
            shouldUpdateChangeTimes = false

            try! manager.removeItem(at: url)
            self.importURL = nil
            shouldUpdateChangeTimes = true
        }
    
//        let importAction = UIAlertAction(title: "Merge with Database", style: .destructive){_ in
//            shouldUpdateChangeTimes = false
//            globalQueue.async{self.mergeRecords()}}
        
        let replaceAction = UIAlertAction(title: "Replace Database", style: .destructive){_ in
            shouldUpdateChangeTimes = false
            self.replaceDatabase()}
        
//        alert.addAction(importAction)
        alert.addAction(replaceAction)
        alert.addAction(cancel)
        presentAlertOnTopmostViewController(alert)
        
        return true
    }
    
    func replaceDatabase()
    {
        let manager = FileManager.default
        guard let psc = timesheetsDataModel.managedObjectContext.persistentStoreCoordinator else {return}
        if let mainStore = psc.persistentStores.first
        {
            try! psc.remove(mainStore)
        }
        
        let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
        let uniqueStorageString = "\(Date()).sqlite"
        let uniqueStoragePath = pathArray.first!.stringByAppendingPathComponent(uniqueStorageString)
        let backupPathURL = URL(fileURLWithPath: uniqueStoragePath)

        
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ca.cadets.Timesheets")!
        let storeURL = groupURL.appendingPathComponent("Timesheets.sqlite")
        
        try! manager.moveItem(at: storeURL, to: backupPathURL)
        try! manager.moveItem(at: importURL!, to: storeURL)
        
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSSQLiteManualVacuumOption: true,  NSInferMappingModelAutomaticallyOption: true, NSSQLitePragmasOption : ["journal_mode" : "DELETE"]] as [String : Any]
        let _ = try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options as [NSObject : AnyObject])
//
        self.timesheetsDataModel.managedObjectContext.reset()
        self.timesheetsDataModel.performSetup()
        NotificationCenter.default.post(name: refreshEverythingNotification, object:self)
    }
    
    func mergeRecords()
    {
        let manager = FileManager.default
        guard let rootViewController =  window?.rootViewController else {return}
        let presentedViewController = rootViewController.presentedViewController
        guard let progressViewer = rootViewController.storyboard?.instantiateViewController(withIdentifier: "Progress View") as? DeduplicateProgressViewController else {return}
        
        mainQueue.async
        {
            if presentedViewController == nil
            {
                rootViewController.present(progressViewer, animated:true, completion:nil)
            }
                
            else
            {
                presentedViewController?.present(progressViewer, animated:true, completion:nil)
            }
            
            self.timesheetsDataModel.stopTimer()
        }
        
        NotificationCenter.default.removeObserver(self.timesheetsDataModel!)
        
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSSQLiteManualVacuumOption: true,  NSInferMappingModelAutomaticallyOption: true, NSSQLitePragmasOption : ["journal_mode" : "DELETE"]] as [String : Any]

        let request = GlidingDayComment.request
        var numberOfFlightsInOldDB = 0
        mainQueue.sync{numberOfFlightsInOldDB = try! self.timesheetsDataModel.managedObjectContext.count(for: request)}
        
        let tempPath = (applicationDocumentsDirectory as NSString).appendingPathComponent("Temp.sqlite")
        let tempPathURL = URL(fileURLWithPath: tempPath)
        
        if manager.fileExists(atPath: tempPath)
        {
            try! manager.removeItem(at: tempPathURL)
        }
        
        try! manager.moveItem(at: importURL!, to:tempPathURL)
        guard let psc = timesheetsDataModel.managedObjectContext.persistentStoreCoordinator else {return}
        let mainStore = psc.persistentStores.first!
        let tempStore = try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: tempPathURL, options: options as [NSObject : AnyObject])

        var numberOfFlightsInMergedDB = 0
        mainQueue.sync{numberOfFlightsInMergedDB = try! self.timesheetsDataModel.managedObjectContext.count(for: request)}
        
        print("Prior to import there are \(numberOfFlightsInOldDB) gliding day comments. After import there are \(numberOfFlightsInMergedDB)")
        
        timesheetsDataModel.glidingCentre = nil
        
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = dataModel.managedObjectContext.persistentStoreCoordinator
        
        context.performAndWait(){self.timesheetsDataModel.deduplicateDatabase(withProgressViewer: progressViewer, onContext: context, withTempStore: tempStore, andMainStore: mainStore)}
        
        try! psc.remove(tempStore)
        try! psc.destroyPersistentStore(at: tempPathURL, ofType: NSSQLiteStoreType, options: options as [NSObject : AnyObject])
        importURL = nil
        shouldUpdateChangeTimes = true
        
        mainQueue.async
        {
            progressViewer.presentingViewController?.dismiss(animated: true, completion:nil)
            self.timesheetsDataModel.managedObjectContext.reset()
            self.timesheetsDataModel.performSetup()
            NotificationCenter.default.post(name: refreshEverythingNotification, object:self)
        }
    }
    
    func applicationSignificantTimeChange(_ application: UIApplication)
    {
        Date.updateFormatters()
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool
    {
        return true
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool
    {
        return true
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        timesheetsDataModel?.statsManager.performBackgroundUpdate()
        completionHandler(.newData)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication)
    {
        timesheetsDataModel.checkForRegionChanges()
        coreDataController?.checkForCloudKitChanges()
        timesheetsDataModel.checkForMajorPreferencesChanges()
        timesheetsDataModel.becomeActive()
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {
        let defaults = ["Region": "Northwest", "Training Mode": false, "Transmit Beacon": false, "iBeacon Assistance": false, "Disable Sync": false] as [String : Any]
        UserDefaults.standard.register(defaults: defaults)

        application.registerForRemoteNotifications()
        coreDataController = CoreDataController()
        
        let undoLandionAction = UNNotificationAction(identifier: "Undo", title: "Undo Landing", options: [UNNotificationActionOptions.foreground])
        let category = UNNotificationCategory(identifier: "Undo", actions: [undoLandionAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories(Set([category]))
        
        self.timesheetsDataModel = TimesheetsDataModel(fromContext: self.coreDataController.managedObjectContext)
        UNUserNotificationCenter.current().delegate = self.timesheetsDataModel
        self.timesheetsDataModel.save()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]){_,_ in }
        self.timesheetsDataModel.performSetup()        
        application.setMinimumBackgroundFetchInterval(1)
        
        return true
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        print("Not registered")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        print("registered")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        let dict = userInfo as! [String: NSObject]
        let note = CKNotification(fromRemoteNotificationDictionary:dict)!
        
        switch note.notificationType
        {
        case .database:
            print("Received database notification!")
            guard let notification = note as? CKDatabaseNotification else {completionHandler(.newData); return}
            guard let cloudKitController = cloudKitController else {completionHandler(.newData); return}

            if cloudKitController.backgroundDownloadTask == nil
            {
                cloudKitController.backgroundDownloadTask = UIApplication.shared.beginBackgroundTask(withName: "Download from iCloud", expirationHandler: {UIApplication.shared.endBackgroundTask(cloudKitController.backgroundDownloadTask!)
                    cloudKitController.backgroundDownloadTask = nil
                })
            }
                
            cloudKitController.fetchChanges(in: notification.databaseScope) {completionHandler(.newData)}
            
        case .query:
            print("Received query notification!")
            completionHandler(.newData)
            
        default:
            print("Received strange notification!")
            completionHandler(.newData)
        }
    }
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata)
    {
        print("Share Accepted")
        
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        
        acceptSharesOperation.perShareCompletionBlock =
            {
                metadata, share, error in
                if let error = error
                {
                    print(error.localizedDescription)
                }
            
                ~>{self.cloudKitController?.toggleSharingTo(state: true)}
            }
        
        CKContainer(identifier: cloudKitShareMetadata.containerIdentifier).add(acceptSharesOperation)
    }
}
