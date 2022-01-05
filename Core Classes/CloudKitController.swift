//
//  CloudKitController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2017-06-18.
//
//

import Foundation
import CloudKit
import CoreData
import UIKit

prefix operator %>

prefix func %> (closure: @escaping () -> ())
{
    backgroundContext.perform
    {
        closure()
    }
}

let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)

final class CloudKitController
{
    var changedPilots = UserDefaults().pilotsToBeUploaded ?? Set<NSManagedObjectID>()
    var changedAttendanceRecords = UserDefaults().attendanceRecordsToBeUploaded ?? Set<NSManagedObjectID>()
    var changedAircraftEntities = UserDefaults().aircraftEntitiesToBeUploaded ?? Set<NSManagedObjectID>()
    var changedFlightRecords = UserDefaults().flightRecordsToBeUploaded ?? Set<NSManagedObjectID>()
    var changedTimesheets = UserDefaults().timesheetsToBeUploaded ?? Set<NSManagedObjectID>()
    var changedMaintenanceIssues = UserDefaults().maintenanceIssuesToBeUploaded ?? Set<NSManagedObjectID>()
    var changedGlidingDayComments = UserDefaults().commentsToBeUploaded ?? Set<NSManagedObjectID>()

    var deletedAttendanceRecords = UserDefaults().attendanceRecordsToBeDeleted ?? Set<String>()
    var deletedFlightRecords = UserDefaults().attendanceRecordsToBeDeleted ?? Set<String>()
    var deletedTimesheets = UserDefaults().attendanceRecordsToBeDeleted ?? Set<String>()
    var deletedComments = UserDefaults().commentsToBeDeleted ?? Set<String>()
    var deletedMaintenanceIssues = UserDefaults().maintenanceIssuesToBeDeleted ?? Set<String>()
    var deletedPilots = UserDefaults().pilotsToBeDeleted ?? Set<String>()

    var recordsPendingUpload = [CKRecord]()
    var recordsInProcessing = 0

    var flightRecordsRemotelyUpdated = Set<CKRecord>()
    var timesheetsRecordsRemotelyUpdated = Set<CKRecord>()
    var pilotsRecordsRemotelyUpdated = Set<CKRecord>()
    var attendanceRecordsRemotelyUpdated = Set<CKRecord>()
    var vehicleRecordsRemotelyUpdated = Set<CKRecord>()
    var glidingDayCommentsRemotelyUpdated = Set<CKRecord>()
    var MaintenanceIssuesRemotelyUpdated = Set<CKRecord>()

    let privateDB = CKContainer.default().privateCloudDatabase
    let sharedDB = CKContainer.default().sharedCloudDatabase
    let zoneID = CKRecordZone.ID(zoneName: "ACGP Timesheets", ownerName: CKCurrentUserDefaultName)
    let privateSubscriptionId = "private-changes"
    let sharedSubscriptionId = "shared-changes"

    var regionName = UserDefaults.standard.string(forKey: "Region") ?? "Northwest"
    var rootObject: CKRecord?
    var rootShare: CKShare?
    var remoteShare: CKShare?

    var reachability: Reachability? = Reachability.networkReachabilityForInternetConnection()
    var networkReachable = true
    var backgroundUploadTask: UIBackgroundTaskIdentifier?
    var backgroundDownloadTask: UIBackgroundTaskIdentifier?

    // the backup start date is the begining of the year OR the year before (up to March)
    lazy var backupStartDate : Date =
    {
        () -> Date in
        printDebug("Called the backupStartDate initializer...")
        var components = gregorian.dateComponents([.year,.month], from: Date())
        components.year = (components.month! < 4 ? components.year! - 1 : components.year)
        components.month = 1
        components.day = 1
        return gregorian.date(from: components) ?? Date()
    }()

    let localURL: URL =
    {
        let applicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
        let storePath = applicationDocumentsDirectory.stringByAppendingPathComponent("Timesheets.sqlite")
        
        return URL(fileURLWithPath: storePath)
    }()

    class func partitionArray<T>(_ newRecords : [T], by size: Int = 100) -> [[T]]
    {
        var portionedArray = [[T]]()

        for startIndex in stride(from: 0, to: newRecords.count, by: size)
        {
            portionedArray.append(Array(newRecords[startIndex..<min(startIndex + size, newRecords.count)]))
        }

        return portionedArray
    }

    func showUploadProgress()
    {
        ~>{UIView.animate(withDuration: 0.2, animations: {dataModel.uploadsInProgress?.alpha = 1})}
    }

    func hideUploadProgress()
    {
        ~>{UIView.animate(withDuration: 0.2, animations: {dataModel.uploadsInProgress?.alpha = 0})}
    }

    func showDownloadProgress()
    {
        ~>{UIView.animate(withDuration: 0.2, animations: {dataModel.downloadsInProgress?.alpha = 1})}
    }

    func hideDownloadProgress()
    {
        ~>{UIView.animate(withDuration: 0.2, animations: {dataModel.downloadsInProgress?.alpha = 0})}
    }

    func createDatabaseSubscriptionOperation(subscriptionId: String) -> CKModifySubscriptionsOperation
    {
        let subscription = CKDatabaseSubscription.init(subscriptionID: subscriptionId)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        // send a silent notification
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        operation.qualityOfService = .utility
        
        return operation
    }
    
    func purgeSavedEntityLists()
    {
        UserDefaults().attendanceRecordsToBeUploaded = nil
        UserDefaults().attendanceRecordsToBeDeleted = nil
        UserDefaults().aircraftEntitiesToBeUploaded = nil
        UserDefaults().pilotsToBeUploaded = nil
        UserDefaults().flightRecordsToBeUploaded = nil
        UserDefaults().timesheetsToBeUploaded = nil
        changedPilots = UserDefaults().pilotsToBeUploaded ?? Set<NSManagedObjectID>()
        changedAttendanceRecords = UserDefaults().attendanceRecordsToBeUploaded ?? Set<NSManagedObjectID>()
        changedAircraftEntities = UserDefaults().aircraftEntitiesToBeUploaded ?? Set<NSManagedObjectID>()
        changedFlightRecords = UserDefaults().flightRecordsToBeUploaded ?? Set<NSManagedObjectID>()
        changedTimesheets = UserDefaults().timesheetsToBeUploaded ?? Set<NSManagedObjectID>()
    }
    
    deinit
    {
        reachability?.stopNotifier()
    }
    
    @objc func reachabilityDidChange()
    {
        guard let r = reachability else { return }
        
        switch (networkReachable, r.isReachable)
        {
        case (false, true):
            networkReachable = true
            uploadPendingChanges()

        case (_, false):
            networkReachable = false
            
        default:
            break
        }
    }
    
    func uploadPendingChanges()
    {
        if rootShare == nil
        {
            setRootObject()
            return
        }
        printLog("Starting uploadPendingChanges...")
        uploadPilotChanges(nil)
        uploadAttendanceRecordChanges(nil)
        uploadVehicleChanges(nil)
        uploadTimesheetChanges(nil)
        uploadFlightRecordChanges(nil)
        uploadCommentChanges(nil)
        uploadMaintenanceChanges(nil)
        
        deleteAttendanceRecord(nil)
        deleteComment(nil)
        deleteTimesheet(nil)
        deleteMaintenanceIssue(nil)
        deleteFlightRecord(nil)
        printLog("Done uploadPendingChanges.")
    }
    
    init()
    {
        if let reachability = reachability
        {
            networkReachable = reachability.isReachable
        }
        
        backgroundContext.parent = dataModel.managedObjectContext
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityDidChange), name: NSNotification.Name(rawValue: ReachabilityDidChangeNotificationName), object: nil)
        _ = reachability?.startNotifier()
        
        setRootObject()
        setRemoteShare()
//        purgeSavedEntityLists()
        
        let createZoneGroup = DispatchGroup()
        printLog("createdCustomZone? \(UserDefaults().createdCustomZone)")
        if UserDefaults().createdCustomZone == false || !zoneExists()
        {
            createPilotZone(group: createZoneGroup)
        }
        
        if UserDefaults().subscribedToPrivateChanges == false
        {
            let createSubscriptionOperation = createDatabaseSubscriptionOperation(subscriptionId: privateSubscriptionId)
            createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
                if error == nil {UserDefaults().subscribedToPrivateChanges = true}
                // else custom error handling
            }
            self.privateDB.add(createSubscriptionOperation)
        }
        
        else
        {
            privateDB.fetchAllSubscriptions(completionHandler: {subscriptions, error in
                if let subscriptions = subscriptions
                {
                    var DBsubscriptionFound = false
                    
                    for subscriptionObject in subscriptions
                    {
                        if let _ = subscriptionObject as? CKDatabaseSubscription
                        {
                            printLog("Private DB Subscription found")
                            DBsubscriptionFound = true
                            break
                        }
                    }
                    
                    if DBsubscriptionFound == false
                    {
                        printLog("DB Subscription not found, will attempt to create")
                        let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: self.privateSubscriptionId)
                        createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
                            if error == nil {UserDefaults().subscribedToPrivateChanges = true}
                            // else custom error handling
                        }
                        self.privateDB.add(createSubscriptionOperation)
                    }
                }
            })
        }

        // Fetch any changes from the server that happened while the app wasn't running
        createZoneGroup.notify(queue: DispatchQueue.global())
        {
            if UserDefaults().createdCustomZone && UserDefaults().viewSharedDatabase == false
            {
                self.fetchChanges(in: .private) {}
            }
            
            if UserDefaults().viewSharedDatabase == true
            {
                self.fetchChanges(in: .shared) {}
            }
        }
    }
    
    func zoneExists() -> Bool {
        printLog("Checking if zone \(zoneID) exists.")
        var zoneExists = false
        let group = DispatchGroup()
        let fetchZoneOp = CKFetchRecordZonesOperation(recordZoneIDs: [zoneID])
        group.enter()
        fetchZoneOp.fetchRecordZonesCompletionBlock = { (ids, error) in
            if let error = error
            {
                printError("Trying to find zoneId \(self.zoneID)", error)
            }
            if let ids = ids
            {
                printLog("Found zoneId \(ids)!")
                zoneExists = true
            }
            printLog("Leaving ... ")
            group.leave()
        }
        self.privateDB.add(fetchZoneOp)
        _ = group.wait(timeout: DispatchTime(uptimeNanoseconds: 12000))
        printLog("Returning from...")
        return zoneExists
    }
    
    func deleteZone()
    {
        printLog("Deleting the zone \(zoneID)")
        let group = DispatchGroup()
        group.enter()
        self.privateDB.delete(withRecordZoneID: zoneID, completionHandler: {(id, error) in
            if let error = error
            {
                printError("While deleting zone \(self.zoneID)", error)
            }
            else
            {
                printLog("Zone \(self.zoneID) deleted successfully")
            }
            printLog("Leaving ... ")
            group.leave()
        })
        _ = group.wait(timeout: DispatchTime(uptimeNanoseconds: 2000))
        printLog("Returning from...")
    }
    
    func saveBackgroundContext(_ file : String = #file, _ function : String = #function, _ line : Int = #line)
    {
        printLog("saveBackgroundContext from", file, function, line)

        shouldUpdateChangeTimes = false
        
        do
        {
            try backgroundContext.save()
        }
            
        catch let error as NSError
        {
            printError("Unresolved error \(error.userInfo)", error)
            abort()
        }
            
        catch
        {
            printError("Unknown Error;", error)
            abort()
        }
        
        ~>{ shouldUpdateChangeTimes = false
            dataModel.saveContext()
            shouldUpdateChangeTimes = true
        }
    }
    
    func createPilotZone(group: DispatchGroup?)
    {
        printLog("Creating Zone \(zoneID)")
        let dispatchGroup = group ??  DispatchGroup()
    
        dispatchGroup.enter()
        let customZone = CKRecordZone(zoneID: zoneID)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [] )
        createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
            if (error == nil) {UserDefaults().createdCustomZone = true; printLog("Zone \(self.zoneID) created")}
            dispatchGroup.leave()
        }
        createZoneOperation.qualityOfService = .userInitiated
        self.privateDB.add(createZoneOperation)
    }
    
    //MARK: - Fetching changes

    func fetchChanges(in databaseScope: CKDatabase.Scope, completion: @escaping () -> Void)
    {
        switch databaseScope
        {
        case .private:
            showDownloadProgress()
            fetchDatabaseChanges(database: privateDB, databaseTokenKey: "private", completion: completion)
        case .shared:
            showDownloadProgress()
            fetchDatabaseChanges(database: sharedDB, databaseTokenKey: "shared", completion: completion)
        case .public:
            fatalError()
        @unknown default:
            fatalError()
        }
    }
    
    func fetchDatabaseChanges(database: CKDatabase, databaseTokenKey: String, completion: @escaping () -> Void)
    {
        var changedZoneIDs: [CKRecordZone.ID] = []
        let operation = database == privateDB ? CKFetchDatabaseChangesOperation(previousServerChangeToken: UserDefaults().databaseChangeToken) : CKFetchDatabaseChangesOperation(previousServerChangeToken: UserDefaults().sharedDatabaseChangeToken)
        
        operation.recordZoneWithIDChangedBlock = {(zoneID) in
            changedZoneIDs.append(zoneID)
        }
        
        operation.recordZoneWithIDWasDeletedBlock = {(zoneID) in
            self.purgeSavedEntityLists()

            if database == self.privateDB
            {
                printLog("There goes the private zone")
                UserDefaults().zoneChangeToken = nil
                UserDefaults().createdCustomZone = false
                self.createPilotZone(group: nil)
            }
                
            else
            {
                printLog("There goes shared zone")
                ~>{self.toggleSharingTo(state: false)}
                UserDefaults().sharedZoneChangeToken = nil

            }
        }
        
        operation.changeTokenUpdatedBlock = { (token) in
            if database == self.privateDB
            {
                UserDefaults().databaseChangeToken = token
            }
            
            else
            {
                UserDefaults().sharedDatabaseChangeToken = token
            }
        }
        
        operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
            if let error = error
            {
                printLog("Error during fetch shared database changes operation \(error)")
                return
            }
            
            if database == self.privateDB
            {
                UserDefaults().databaseChangeToken = token
            }
                
            else
            {
                UserDefaults().sharedDatabaseChangeToken = token
            }
            
            if changedZoneIDs.count > 0
            {
                self.fetchZoneChanges(database: database, databaseTokenKey: databaseTokenKey, zoneIDs: changedZoneIDs)
                {
                    if database == self.privateDB
                    {
                        UserDefaults().databaseChangeToken = token
                    }
                        
                    else
                    {
                        UserDefaults().sharedDatabaseChangeToken = token
                    }
                }
            }
            
            self.hideDownloadProgress()
        }
        operation.qualityOfService = .userInitiated
        
        database.add(operation)
        completion()
    }
    
    func fetchZoneChanges(database: CKDatabase, databaseTokenKey: String, zoneIDs: [CKRecordZone.ID], completion: @escaping () -> Void)
    {
        // Look up the previous change token for each zone
        var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()
        for zoneID in zoneIDs
        {
            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = database == privateDB ? UserDefaults().zoneChangeToken : UserDefaults().sharedZoneChangeToken
            optionsByRecordZoneID[zoneID] = options
        }
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: optionsByRecordZoneID)
        
        operation.recordChangedBlock = {(record) in
            %>{
                if record.recordType == CloudKitRecordType.Pilot.rawValue
                {
                    ~>{self.pilotsRecordsRemotelyUpdated.insert(record)}
                }
                
                if record.recordType == CloudKitRecordType.Attendance.rawValue
                {
                    ~>{self.attendanceRecordsRemotelyUpdated.insert(record)}
                }
                
                if record.recordType == CloudKitRecordType.Vehicle.rawValue
                {
                    ~>{self.vehicleRecordsRemotelyUpdated.insert(record)}
                }

                if record.recordType == CloudKitRecordType.FlightRecord.rawValue
                {
                    ~>{self.flightRecordsRemotelyUpdated.insert(record)}
                }

                if record.recordType == CloudKitRecordType.Timesheet.rawValue
                {
                    ~>{self.timesheetsRecordsRemotelyUpdated.insert(record)}
                }
                
                if record.recordType == CloudKitRecordType.Comment.rawValue
                {
                    ~>{self.glidingDayCommentsRemotelyUpdated.insert(record)}
                }
                
                if record.recordType == CloudKitRecordType.Maintenance.rawValue
                {
                    ~>{self.MaintenanceIssuesRemotelyUpdated.insert(record)}
                }
            }
        }
        
        operation.recordWithIDWasDeletedBlock = {(recordId, type) in
            %>{
                if type == CloudKitRecordType.Attendance.rawValue
                {
                    self.deleteAttendanceRecordWithID(recordId)
                }
                
                if type == CloudKitRecordType.FlightRecord.rawValue
                {
                    self.deleteFlightRecordWithID(recordId)
                }
                
                if type == CloudKitRecordType.Comment.rawValue
                {
                    self.deleteCommentWithID(recordId)
                }
                
                if type == CloudKitRecordType.Maintenance.rawValue
                {
                    self.deleteMaintenanceIssueWithID(recordId)
                }
                
                if type == CloudKitRecordType.Timesheet.rawValue
                {
                    self.deleteTimesheetWithID(recordId)
                }
                
                if type == CloudKitRecordType.Pilot.rawValue
                {
                    self.deletePilotWithID(recordId)
                }
            }
        }
        
        operation.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
            // Flush record changes and deletions for this zone to disk
            if database == self.privateDB
            {
                UserDefaults().zoneChangeToken = token
            }
            
            else
            {
                UserDefaults().sharedZoneChangeToken = token
            }
        }
        
        operation.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
        
            self.processRemoteChanges()
            self.hideDownloadProgress()

            if let error = error
            {
                printLog("Error fetching zone changes for \(databaseTokenKey) database: \(error).")
                UserDefaults().createdCustomZone = false
                self.purgeSavedEntityLists()

                self.createPilotZone(group: nil)
                if database == self.privateDB
                {
                    UserDefaults().zoneChangeToken = nil
                }
                    
                else
                {
                    UserDefaults().sharedZoneChangeToken = nil
                }
            }
            
            if database == self.privateDB
            {
                UserDefaults().zoneChangeToken = changeToken
            }
                
            else
            {
                UserDefaults().sharedZoneChangeToken = changeToken
            }
        }
        
        operation.fetchRecordZoneChangesCompletionBlock = { (error) in
            if let error = error
            {
                printError("Error fetching zone changes for \(databaseTokenKey) database.", error)
            }
            completion()
        }
        
        database.add(operation)
    }
    
    func processRemoteChanges()
    {
        printLog("Start of processRemoteChanges")
        for record in pilotsRecordsRemotelyUpdated
        {
            %>{_ = self.updatePilotToMatchRecord(record)}
        }
        pilotsRecordsRemotelyUpdated.removeAll()
        
        for record in attendanceRecordsRemotelyUpdated
        {
            %>{_ = self.updateAttendanceRecordToMatchRecord(record)}
        }
        attendanceRecordsRemotelyUpdated.removeAll()
        
        for record in vehicleRecordsRemotelyUpdated
        {
            %>{_ = self.updateVehicleToMatchRecord(record)}
        }
        vehicleRecordsRemotelyUpdated.removeAll()

        for record in timesheetsRecordsRemotelyUpdated
        {
            %>{_ = self.updateTimesheetToMatchRecord(record)}
        }
        timesheetsRecordsRemotelyUpdated.removeAll()

        for record in flightRecordsRemotelyUpdated
        {
            %>{_ = self.updateFlightRecordToMatchRecord(record)}
        }
        flightRecordsRemotelyUpdated.removeAll()
        
        for record in glidingDayCommentsRemotelyUpdated
        {
            %>{_ = self.updateGlidingDayCommentToMatchRecord(record)}
        }
        glidingDayCommentsRemotelyUpdated.removeAll()
        
        for record in MaintenanceIssuesRemotelyUpdated
        {
            %>{_ = self.updateMaintenanceIssueToMatchRecord(record)}
        }
        MaintenanceIssuesRemotelyUpdated.removeAll()

        printDebug("End of processRemoteChanges before endBackgroundTask(backgroundDownloadTask: \(String(describing: backgroundDownloadTask))")
        if let backgroundDownloadTask = backgroundDownloadTask
        {
            UIApplication.shared.endBackgroundTask(backgroundDownloadTask)
            self.backgroundDownloadTask = nil
        }

    }
    
    //MARK: - Configuring Sharing
    
    func setRootObject()
    {
        let rootRecordID = CKRecord.ID(recordName: regionName, zoneID: self.zoneID)
        
        privateDB.fetch(withRecordID: rootRecordID)
        {
            (record, error) in
            if let error = error as? CKError
            {
                if error.errorCode == 11
                {
                    printLog("Region record isn't on the server yet. Will try to make one.")
                    
                    let regionCK = CKRecord(recordType: CloudKitRecordType.Region.rawValue, recordID: rootRecordID)
                    self.privateDB.save(regionCK, completionHandler:
                        {(record, error) in
                            if let error2 = error as? CKError
                            {
                                printLog(error2.localizedDescription)
                            }
                                
                            else
                            {
                                self.rootObject = record
                                self.setRootShare()
                            }
                    })
                }
            }
            
            if let record = record
            {
                self.rootObject = record
                self.setRootShare()
            }
        }
    }
    
    func setRootShare()
    {
        let rootShareID = CKRecord.ID(recordName: "SharedData", zoneID: self.zoneID)
        
        privateDB.fetch(withRecordID: rootShareID)
        {
            (record, error) in
            if let error = error as? CKError
            {
                if error.errorCode == 11
                {
                    printLog("Share isn't on the server yet. Will try to make one.")
                    
                    let share = CKShare(rootRecord: self.rootObject!, shareID: rootShareID)
                    share.publicPermission = .readOnly
                    
                    let mro = CKModifyRecordsOperation(
                        recordsToSave: [self.rootObject!, share],
                        recordIDsToDelete: nil)
                    
                    mro.modifyRecordsCompletionBlock = {
                        records, recordIDs, error in
                        if let error = error
                        {
                            printLog(error.localizedDescription)
                        }
    
                        if let record = records?.first as? CKShare
                        {
                            self.rootShare = record
                            self.uploadPendingChanges()
                        }
                    }
                    
                    self.privateDB.add(mro)
                    
                }
            }
            
            if let record = record as? CKShare
            {
                self.rootShare = record
                self.uploadPendingChanges()
            }
        }
    }
    
    func setRemoteShare()
    {
        sharedDB.fetchAllRecordZones()
            {
                (zones, error) in
                if let zone = zones?.first
                {
                    let remoteShareID = CKRecord.ID(recordName: "SharedData", zoneID: zone.zoneID)
                    
                    self.sharedDB.fetch(withRecordID: remoteShareID)
                    {
                        (record, error) in
                        if let error = error as? CKError
                        {
                            if error.errorCode == 11
                            {
                                printLog("Share not found.")
                            }
                        }
                        
                        if let record = record as? CKShare
                        {
                            printLog("Share found.")
                            self.remoteShare = record
                        }
                    }
                }
            }
    }

    
    /// If the app is currently monitoring a remote share, this will present options to extend the share to others or disable it. Otherwise this will prompt the user to invite others to share their database.
    ///
    /// - Returns: A sharing controller
    func configureSharing() -> UICloudSharingController?
    {
        var sharingController: UICloudSharingController?
        
        if observerMode
        {
            guard let share = remoteShare else {return sharingController}
            sharingController = UICloudSharingController(share: share, container: CKContainer.default())
        }
        
        else
        {
            sharingController = UICloudSharingController(share: rootShare!, container: CKContainer.default())
        }
        
        return sharingController
    }
    
    func toggleSharingTo(state: Bool)
    {
        UserDefaults().viewSharedDatabase = state
        observerMode = state
        (UIApplication.shared.delegate as! TimesheetsAppDelegate).coreDataController.toggleRemoteStore()
        backgroundContext.parent = dataModel.managedObjectContext
        
        if observerMode == true
        {
            if UserDefaults().subscribedToSharedChanges == false
            {
                let createSubscriptionOperation = createDatabaseSubscriptionOperation(subscriptionId: sharedSubscriptionId)
                createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
                    if error == nil {UserDefaults().subscribedToSharedChanges = true}
                    // else custom error handling
                }
                self.sharedDB.add(createSubscriptionOperation)
            }
                
            else
            {
                sharedDB.fetchAllSubscriptions(completionHandler: {subscriptions, error in
                    if let subscriptions = subscriptions
                    {
                        var DBsubscriptionFound = false
                        
                        for subscriptionObject in subscriptions
                        {
                            if let _ = subscriptionObject as? CKDatabaseSubscription
                            {
                                printLog("Shared DB Subscription found")
                                DBsubscriptionFound = true
                                break
                            }
                        }
                        
                        if DBsubscriptionFound == false
                        {
                            printLog("DB Subscription not found, will attempt to create")
                            let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionId: self.sharedSubscriptionId)
                            createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
                                if error == nil {UserDefaults().subscribedToPrivateChanges = true}
                                // else custom error handling
                            }
                            self.sharedDB.add(createSubscriptionOperation)
                        }
                    }
                })
            }
            
            backupDatabase()
        }
        
        else
        {
            UserDefaults().subscribedToSharedChanges = false
        }
    }

    //MARK: - Methods that are called when a NSManagedObject instance is changed
    
    func uploadPilotChanges(_ recentlyChangedPilot: Pilot?)
    {
        if let objectID = recentlyChangedPilot?.objectID
        {
            changedPilots.insert(objectID)
            showUploadProgress()
        }
        
        if networkReachable == false
        {
            return
        }

        let task = createBackgroundTask("PilotChanges")

        let changedPilotsCopy = changedPilots
        changedPilots.removeAll()
        UserDefaults().pilotsToBeUploaded = changedPilots
        recordsInProcessing += changedPilotsCopy.count
        printLog("There are \(recordsInProcessing) records in processing")
        
        %>{
            for objectID in changedPilotsCopy
            {
                guard let changedPilot = backgroundContext.object(with: objectID) as? Pilot else {continue}
                backgroundContext.refresh(changedPilot, mergeChanges: false)
                guard let imageURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TempImage.png") else
                {
                    return
                }
                
                let pilotRecordID = CKRecord.ID(recordName: String(changedPilot.recordID.timeIntervalSince1970), zoneID: self.zoneID)
                
                if let image = changedPilot.photoThumbnailImage as? UIImage
                {
                    // save image to URL
                    do
                    {
                        try image.pngData()?.write(to: imageURL)
                    }
                        
                    catch { }
                }
                
                self.privateDB.fetch(withRecordID: pilotRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printError("Pilot record isn't on the server yet. Will try to make one.", error)
                            
                            %>{
                                let pilotRecordToSave = self.createPilotRecordFrom(changedPilot)
                                self.uploadRecord(record: pilotRecordToSave, withID: objectID)
                            }
                        }
                        
                        else
                        {
                            printError("CloudKit error \(error.errorCode), saving the objectId to process later?", error)

                            ~>{
                                self.changedPilots.insert(objectID)
                                UserDefaults().pilotsToBeUploaded = self.changedPilots
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                    else if let error = error
                    {
                        printError("Unprocessed error during privateDB.fetch", error)
                    }
                    else
                    {
                        %>{
                            let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedPilot.recordChangeTime
                            {
                                // update the cloud copy
                                _ = self.createPilotRecordFrom(changedPilot, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                            else
                            {
                                // ignore the local copy because the cloud copy is newer.
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }

            self.endBackgroundTask(task)
        }
    }
    
    func uploadAttendanceRecordChanges(_ recentlyChangedRecord: AttendanceRecord?)
    {
        if let objectID = recentlyChangedRecord?.objectID
        {
            changedAttendanceRecords.insert(objectID)
            showUploadProgress()
        }
        
        if networkReachable == false
        {
            return
        }
        
        let task = createBackgroundTask("Attendance")

        let changedAttendanceRecordsCopy = changedAttendanceRecords
        changedAttendanceRecords.removeAll()
        UserDefaults().attendanceRecordsToBeUploaded = changedAttendanceRecords
        recordsInProcessing += changedAttendanceRecordsCopy.count
        printLog("There are \(recordsInProcessing) records in processing")

        for objectID in changedAttendanceRecordsCopy
        {
            %>{
                guard let changedRecord = backgroundContext.object(with: objectID) as? AttendanceRecord else {return}
                backgroundContext.refresh(changedRecord, mergeChanges: false)
                let changedRecordID = CKRecord.ID(recordName: String(changedRecord.recordID.timeIntervalSince1970), zoneID: self.zoneID)
                
                self.privateDB.fetch(withRecordID: changedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printLog("Attendance record isn't on the server yet. Will try to make one.")
                            
                            %>{let attendanceRecordToSave = self.createAttendanceRecordRecordFrom(changedRecord)
                                self.uploadRecord(record: attendanceRecordToSave, withID: objectID)
                            }
                        }
                            
                        else
                        {
                            printLog(error.localizedDescription)
                            ~>{self.changedAttendanceRecords.insert(objectID)
                                UserDefaults().attendanceRecordsToBeUploaded = self.changedAttendanceRecords
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                        
                    else
                    {
                        %>{let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedRecord.recordChangeTime
                            {
                                _ = self.createAttendanceRecordRecordFrom(changedRecord, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                            
                            else
                            {
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }
        }

        endBackgroundTask(task)
    }
    
    func uploadFlightRecordChanges(_ recentlyChangedRecord: FlightRecord?)
    {
        if let objectID = recentlyChangedRecord?.objectID
        {
            changedFlightRecords.insert(objectID)
            showUploadProgress()
        }
        
        if networkReachable == false
        {
            return
        }
        
        let task = createBackgroundTask("Flight")

        let changedFlightRecordsCopy = changedFlightRecords
        changedFlightRecords.removeAll()
        UserDefaults().flightRecordsToBeUploaded = changedFlightRecords
        recordsInProcessing += changedFlightRecordsCopy.count
        printLog("There are \(recordsInProcessing) records in processing")

        for objectID in changedFlightRecordsCopy
        {
            %>{
                guard let changedRecord = backgroundContext.object(with: objectID) as? FlightRecord else {return}
                backgroundContext.refresh(changedRecord, mergeChanges: false)
                let changedRecordID = CKRecord.ID(recordName: String(changedRecord.recordID.timeIntervalSince1970), zoneID: self.zoneID)
            
                self.privateDB.fetch(withRecordID: changedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printLog("Flight record isn't on the server yet. Will try to make one.")
                            
                            %>{let flightRecordToSave = self.createFlightRecordRecordFrom(changedRecord)
                                self.uploadRecord(record: flightRecordToSave, withID: objectID)
                            }
                        }
                            
                        else
                        {
                            printLog(error.localizedDescription)
                            ~>{self.changedFlightRecords.insert(objectID)
                                UserDefaults().flightRecordsToBeUploaded = self.changedFlightRecords
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                        
                    else
                    {
                        %>{let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedRecord.recordChangeTime
                            {
                                _ = self.createFlightRecordRecordFrom(changedRecord, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                            
                            else
                            {
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }
        }

        endBackgroundTask(task)
    }

    func uploadTimesheetChanges(_ recentlyChangedRecord: AircraftTimesheet?)
    {
        if let objectID = recentlyChangedRecord?.objectID
        {
            changedTimesheets.insert(objectID)
            showUploadProgress()
        }
        
        if networkReachable == false
        {
            return
        }
        
        let task = createBackgroundTask("Timesheet")

        let changedTimesheetsCopy = changedTimesheets
        changedTimesheets.removeAll()
        UserDefaults().timesheetsToBeUploaded = changedTimesheets
        recordsInProcessing += changedTimesheetsCopy.count
        printLog("There are \(recordsInProcessing) records in processing")

        for objectID in changedTimesheetsCopy
        {
            %>{
                guard let changedTimesheet = backgroundContext.object(with: objectID) as? AircraftTimesheet else {return}
                backgroundContext.refresh(changedTimesheet, mergeChanges: false)
                let changedRecordID = CKRecord.ID(recordName: String(changedTimesheet.recordID.timeIntervalSince1970), zoneID: self.zoneID)
            
                self.privateDB.fetch(withRecordID: changedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printLog("Timesheet isn't on the server yet. Will try to make one.")
                            
                            %>{let timesheetToSave = self.createTimesheetRecordFrom(changedTimesheet)
                                self.uploadRecord(record: timesheetToSave, withID: objectID)
                            }
                        }
                            
                        else
                        {
                            printLog(error.localizedDescription)
                            ~>{self.changedTimesheets.insert(objectID)
                                UserDefaults().timesheetsToBeUploaded = self.changedTimesheets
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                        
                    else
                    {
                        %>{
                            let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedTimesheet.recordChangeTime
                            {
                                _ = self.createTimesheetRecordFrom(changedTimesheet, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                                
                            else
                            {
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }
        }

        endBackgroundTask(task)
    }

    func uploadMaintenanceChanges(_ recentlyChangedRecord: MaintenanceEvent?)
    {
        if let objectID = recentlyChangedRecord?.objectID
        {
            changedMaintenanceIssues.insert(objectID)
            showUploadProgress()
        }
        
        if networkReachable == false
        {
            return
        }

        let task = createBackgroundTask("Maintenance")

        let changedMaintenanceIssuesCopy = changedMaintenanceIssues
        changedMaintenanceIssues.removeAll()
        UserDefaults().maintenanceIssuesToBeUploaded = changedMaintenanceIssues
        recordsInProcessing += changedMaintenanceIssuesCopy.count
        printLog("There are \(recordsInProcessing) records in processing")
        
        for objectID in changedMaintenanceIssuesCopy
        {
            %>{
                guard let changedIssue = backgroundContext.object(with: objectID) as? MaintenanceEvent else {return}
                backgroundContext.refresh(changedIssue, mergeChanges: false)
                let changedRecordID = CKRecord.ID(recordName: String(changedIssue.recordID.timeIntervalSince1970), zoneID: self.zoneID)
            
                self.privateDB.fetch(withRecordID: changedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printLog("Maintenance issue isn't on the server yet. Will try to make one.")
                            
                            %>{let issueToSave = self.createMaintenanceIssueRecordFrom(changedIssue)
                                self.uploadRecord(record: issueToSave, withID: objectID)
                            }
                        }
                            
                        else
                        {
                            printLog(error.localizedDescription)
                            ~>{self.changedMaintenanceIssues.insert(objectID)
                                UserDefaults().maintenanceIssuesToBeUploaded = self.changedMaintenanceIssues
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                        
                    else
                    {
                        %>{
                            let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedIssue.recordChangeTime
                            {
                                _ = self.createMaintenanceIssueRecordFrom(changedIssue, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                                
                            else
                            {
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }
        }

        endBackgroundTask(task)
    }

    
    func uploadCommentChanges(_ recentlyChangedRecord: GlidingDayComment?)
    {
        if let objectID = recentlyChangedRecord?.objectID
        {
            changedGlidingDayComments.insert(objectID)
            showUploadProgress()
        }
        
        if networkReachable == false
        {
            return
        }

        let task = createBackgroundTask("Comment")

        let changedCommentsCopy = changedGlidingDayComments
        changedGlidingDayComments.removeAll()
        UserDefaults().commentsToBeUploaded = changedGlidingDayComments
        recordsInProcessing += changedCommentsCopy.count
        printLog("There are \(recordsInProcessing) records in processing")
        
        for objectID in changedCommentsCopy
        {
            %>{
                guard let changedComment = backgroundContext.object(with: objectID) as? GlidingDayComment else {return}
                backgroundContext.refresh(changedComment, mergeChanges: false)
                let changedRecordID = CKRecord.ID(recordName: String(changedComment.recordID.timeIntervalSince1970), zoneID: self.zoneID)
            
                self.privateDB.fetch(withRecordID: changedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printLog("Comment isn't on the server yet. Will try to make one.")
                            
                            %>{let commentToSave = self.createGlidingDayCommentRecordFrom(changedComment)
                                self.uploadRecord(record: commentToSave, withID: objectID)
                            }
                        }
                            
                        else
                        {
                            printLog(error.localizedDescription)
                            ~>{self.changedGlidingDayComments.insert(objectID)
                                UserDefaults().commentsToBeUploaded = self.changedGlidingDayComments
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                        
                    else
                    {
                        %>{
                            let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedComment.recordChangeTime
                            {
                                _ = self.createGlidingDayCommentRecordFrom(changedComment, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                                
                            else
                            {
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }
        }

        endBackgroundTask(task)
    }
    
    func uploadVehicleChanges(_ recentlyChangedAircraft: AircraftEntity?)
    {
        if let objectID = recentlyChangedAircraft?.objectID
        {
            changedAircraftEntities.insert(objectID)
            showUploadProgress()
        }

        if networkReachable == false
        {
            return
        }

        let task = createBackgroundTask("Vehicle")

        let changedVehiclesCopy = changedAircraftEntities
        changedAircraftEntities.removeAll()
        UserDefaults().aircraftEntitiesToBeUploaded = changedAircraftEntities
        recordsInProcessing += changedVehiclesCopy.count
        printLog("There are \(recordsInProcessing) records in processing")

        for objectID in changedVehiclesCopy
        {
            %>{
                guard let changedAircraftEntity = backgroundContext.object(with: objectID) as? AircraftEntity else {return}
                backgroundContext.refresh(changedAircraftEntity, mergeChanges: false)
                let changedVehicleID = CKRecord.ID(recordName: String(self.regionName + changedAircraftEntity.registration), zoneID: self.zoneID)
            
                self.privateDB.fetch(withRecordID: changedVehicleID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        if error.errorCode == 11
                        {
                            printLog("Vehicle isn't on the server yet. Will try to make one.")
                            
                            %>{
                                if Date() - changedAircraftEntity.remoteChangeTime > 300
                                {
                                    let vehicleToSave = self.createVehicleRecordFrom(changedAircraftEntity)
                                    self.uploadRecord(record: vehicleToSave, withID: objectID)
                                }
                            }
                        }
                            
                        else
                        {
                            printLog(error.localizedDescription)
                            ~>{self.changedAircraftEntities.insert(objectID)
                                UserDefaults().aircraftEntitiesToBeUploaded = self.changedAircraftEntities
                                self.uploadRecord(record: nil, withID: nil)
                            }
                        }
                    }
                        
                    else
                    {
                        %>{
                            let changeTime = record?["recordChangeTime"] as? Date ?? Date.distantPast
                            if changeTime < changedAircraftEntity.recordChangeTime, Date() - changedAircraftEntity.remoteChangeTime > 300
                            {
                                _ = self.createVehicleRecordFrom(changedAircraftEntity, withExistingRecord: record)
                                self.uploadRecord(record: record!, withID: objectID)
                            }
                            
                            else
                            {
                                self.recordsInProcessing -= 1
                                printLog("There are \(self.recordsInProcessing) records in processing")
                            }
                        }
                    }
                }
            }
        }

        endBackgroundTask(task)
    }
    
    func uploadRecord(record: CKRecord?, withID: NSManagedObjectID?)
    {
        recordsInProcessing -= 1
        printLog("There are \(recordsInProcessing) records in processing")

        if let record = record
        {
            func checkForNewerRecord(existingRecord: CKRecord) -> CKRecord
            {
                if record.recordID == existingRecord.recordID
                {
                    let recordChangeTime = record["recordChangeTime"] as! Date
                    let existingRecordChangeTime = existingRecord["recordChangeTime"] as! Date

                    if recordChangeTime > existingRecordChangeTime
                    {
                        return record
                    }
                }
                
                return existingRecord
            }
            
            var recordExists = false
            
            for existingRecord in recordsPendingUpload
            {
                if existingRecord.recordID == record.recordID
                {
                    recordExists = true
                    break
                }
            }

            if recordExists
            {
                recordsPendingUpload = recordsPendingUpload.map({checkForNewerRecord(existingRecord: $0)})
            }
            
            else
            {
                recordsPendingUpload.append(record)
            }
        }
        
        if recordsInProcessing == 0 && recordsPendingUpload.count > 0
        {
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsPendingUpload, recordIDsToDelete: nil)
            modifyOperation.isAtomic = false
            modifyOperation.savePolicy = .allKeys
            modifyOperation.completionBlock = {() in printLog("Modify Operation Complete")}
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let cloudKitError = error as? CKError
                {
                    %>{
                        self.saveObjectForFutureUpload(ID: withID)
                    }
                    printError("CloudKit Error \(cloudKitError.errorCode) on record completion", cloudKitError)
                }
                else if let error = error
                {
                    printError("Unknown error on record completion", error)
                }
                else
                {
                    printLog("I guess a record was updated?")
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printError("During modifyRecords for upload records", error)
                }

                printLog("Let the good times roll")
                self.hideUploadProgress()
            }
            
            modifyOperation.queuePriority = .normal
            recordsPendingUpload.removeAll()
            privateDB.add(modifyOperation)
        }
        
        else if recordsInProcessing == 0
        {
            self.hideUploadProgress()
        }
    }
    
    func saveObjectForFutureUpload(ID: NSManagedObjectID?)
    {
        if let ID = ID
        {
            let managedObject = backgroundContext.object(with: ID)
            
            if managedObject is Pilot
            {
                changedPilots.insert(ID)
                UserDefaults().pilotsToBeUploaded = changedPilots
            }
            
            if managedObject is FlightRecord
            {
                changedFlightRecords.insert(ID)
                UserDefaults().flightRecordsToBeUploaded = changedFlightRecords
            }
            
            if managedObject is AttendanceRecord
            {
                changedAttendanceRecords.insert(ID)
                UserDefaults().attendanceRecordsToBeUploaded = changedAttendanceRecords
            }
            
            if managedObject is AircraftEntity
            {
                changedAircraftEntities.insert(ID)
                UserDefaults().aircraftEntitiesToBeUploaded = changedAircraftEntities
            }
            
            if managedObject is AircraftTimesheet
            {
                changedTimesheets.insert(ID)
                UserDefaults().timesheetsToBeUploaded = changedTimesheets
            }
        }
    }

    
    //MARK: - Methods meant to backup and confirm the integrity of the database
    var BackupDatabaseTask : UIBackgroundTaskIdentifier?

    /// Backs up all changes to the current gliding center from the current year. Obtains all changes from other gliding centers from the CloudKit server for the current year.
    func backupDatabase()
    {
        let task = createBackgroundTask("Backup Database")
        %>{
            self.syncAllPilots() {
                self.saveBackgroundContext()
                self.endBackgroundTask(task)
            }
        }
    }
    
    func syncAllPilots(closure: @escaping () -> ())
    {
        let pilotRequest = Pilot.request
        let predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(Pilot.recordChangeTime), backupStartDate])

        pilotRequest.predicate = predicate
        
        let allPilots = try! backgroundContext.fetch(pilotRequest)
        
        let query = CKQuery(recordType: CloudKitRecordType.Pilot.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        var records = [CKRecord]()

        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }
        
        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in
            if let cursor = cursor
            {
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
            else
            {
                self?.hideDownloadProgress()
                self?.processPilots(localPilots: allPilots, remotePilots: records) {
                    closure()
                }
            }
            
            if let error = error
            {
                printError("Error during syncAllPilots query.", error)
            }
        }

        showDownloadProgress()
        privateDB.add(queryOperation)
    }
    
    func processPilots(localPilots: [Pilot], remotePilots: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(localPilots.count) local pilots modified since \(backupStartDate).")
        printLog("There are \(remotePilots.count) remote pilots modified since \(backupStartDate).")

        // remove pilot already in cloud
        var localPilotsSet = Set<Pilot>(localPilots)
        
        for remotePilot in remotePilots
        {
            let localPilot = self.updatePilotToMatchRecord(remotePilot)
            let dateModifiedInCloud = remotePilot["recordChangeTime"] as! Date
            if localPilot.recordChangeTime <= dateModifiedInCloud, remotePilot.parent != nil
            {
                localPilotsSet.remove(localPilot)
            }
        }

        // if need to update cloud, prepare record to upload
        var count = localPilotsSet.count
        var newRecords = [CKRecord]()
        printLog("There are \(count) pilots left to process.")

        if UserDefaults().viewSharedDatabase == false
        {
            for localPilot in localPilotsSet
            {
                newRecords.append(createPilotRecordFrom(localPilot))
                count -= 1
            }
        }

        // Split cloud records in batches
        printLog("There are \(newRecords.count) pilots to upload.")
        let batchArray = CloudKitController.partitionArray(newRecords)

        if batchArray.count > 0
        {
            showUploadProgress()
        }

        // process each batch of pilots.
        printLog("There are \(batchArray.count) batch of pilots to process.")
        for (idx,batch) in batchArray.enumerated()
        {
            let isFinalModifyOperation = batch == batchArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
            modifyOperation.savePolicy = .allKeys
            modifyOperation.isAtomic = false
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printError("Error for pilot record.", error)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printError("While modifyRecords for pilots (\(idx+1) of \(batchArray.count))", error)
                }
                    
                else
                {
                    if isFinalModifyOperation
                    {
                        printLog("The last modify pilots operation completed (\(idx+1) of \(batchArray.count))")
                        self.hideUploadProgress()
                    }
                    else
                    {
                        printLog("A modify pilots operation was completed (\(idx+1) of \(batchArray.count))")
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
        
        saveBackgroundContext()
        self.syncAttendanceRecords() {
            closure()
        }
    }
    
    func syncAttendanceRecords(closure: @escaping () -> ())
    {
        let attendanceRequest = AttendanceRecord.request
        var glidingSiteName = ""
        
        mainQueue.sync(execute: {glidingSiteName = dataModel.glidingCentre.name})

        var predicate = NSPredicate(format: "%K > %@ AND %K == %@", argumentArray: [#keyPath(AttendanceRecord.recordChangeTime), backupStartDate, #keyPath(AttendanceRecord.glidingCentre.name), glidingSiteName])

        attendanceRequest.predicate = predicate
        let allAttendanceRecords = try! backgroundContext.fetch(attendanceRequest)
        
        predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(AttendanceRecord.recordChangeTime), backupStartDate])
        let query = CKQuery(recordType: CloudKitRecordType.Attendance.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records = [CKRecord]()
        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }
        
        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in
            if let cursor = cursor
            {
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
                
            else
            {
                self?.hideDownloadProgress()
                self?.processAttendanceRecords(allAttendanceRecords: allAttendanceRecords, records: records) {
                    closure()
                }
            }
            
            if let error = error
            {
                printError("Error during syncAttendanceRecords query.", error)
            }
        }

        showDownloadProgress()
        privateDB.add(queryOperation)
    }
    
    func processAttendanceRecords(allAttendanceRecords: [AttendanceRecord], records: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(allAttendanceRecords.count) local attendance records since \(backupStartDate)")
        printLog("There are \(records.count) remote attendance records since \(backupStartDate)")
        
        var allAttendanceRecordsSet = Set<AttendanceRecord>(allAttendanceRecords)
        
        for record in records
        {
            let attendanceRecord = self.updateAttendanceRecordToMatchRecord(record)
            let dateModifiedInCloud = record["recordChangeTime"] as! Date
            if attendanceRecord.recordChangeTime <= dateModifiedInCloud, record.parent != nil
            {
                allAttendanceRecordsSet.remove(attendanceRecord)
            }
        }
        
        var count = allAttendanceRecordsSet.count
        
        var newRecords = [CKRecord]()
        
        if UserDefaults().viewSharedDatabase == false
        {
            for attendanceRecord in allAttendanceRecordsSet
            {
                newRecords.append(createAttendanceRecordRecordFrom(attendanceRecord))
                count -= 1
            }
        }

        printLog("There are \(count) attendance records left to process")

        let portionedArray = CloudKitController.partitionArray(newRecords)

        if portionedArray.count > 0
        {
            showUploadProgress()
        }
        
        for array in portionedArray
        {
            let isFinalModifyOperation = array == portionedArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: array, recordIDsToDelete: nil)
            modifyOperation.savePolicy = .allKeys
            modifyOperation.isAtomic = false
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printLog(error.localizedDescription)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printError("Error during update to attendance records.", error)
                }
                    
                else
                {
                    printLog("A modify attendance operation was completed")
                    if isFinalModifyOperation
                    {
                        printLog("Modifying attendance records complete")
                        self.hideUploadProgress()
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
        
        saveBackgroundContext()
        self.syncAllVehicles() {
            closure()
        }
    }
    
    func syncAllVehicles(closure: @escaping () -> ())
    {
        let vehicleRequest = AircraftEntity.request
        let allVehicleRecords = try! backgroundContext.fetch(vehicleRequest)
        
        let predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(AircraftEntity.recordChangeTime), NSDate.distantPast])
        let query = CKQuery(recordType: CloudKitRecordType.Vehicle.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records = [CKRecord]()
        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }
        
        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in
            if let cursor = cursor
            {
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
                
            else
            {
                self?.hideDownloadProgress()
                self?.processVehicleRecords(allVehicleRecords: allVehicleRecords, records: records) {
                    closure()
                }
            }
            
            if let error = error
            {
                printError("Error during syncAllVehicles query", error)
            }
        }
        
        showDownloadProgress()
        privateDB.add(queryOperation)
    }
    
    func processVehicleRecords(allVehicleRecords: [AircraftEntity], records: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(allVehicleRecords.count) local vehicles")
        printLog("There are \(records.count) remote vehicles")
        
        var allVehicleRecordsSet = Set<AircraftEntity>(allVehicleRecords)
        
        for record in records
        {
            let vehicleRecord = self.updateVehicleToMatchRecord(record)
            let dateModifiedInCloud = record["recordChangeTime"] as! Date
            if vehicleRecord.recordChangeTime <= dateModifiedInCloud, record.parent != nil
            {
                allVehicleRecordsSet.remove(vehicleRecord)
            }
        }
        
        var count = allVehicleRecordsSet.count
        
        var newRecords = [CKRecord]()
        
        if UserDefaults().viewSharedDatabase == false
        {
            for vehicleRecord in allVehicleRecordsSet
            {
                newRecords.append(createVehicleRecordFrom(vehicleRecord))
                count -= 1
            }
        }

        printLog("There are \(count) vehicles left to process")

        let portionedArray = CloudKitController.partitionArray(newRecords)

        if portionedArray.count > 0
        {
            showUploadProgress()
        }
        
        for array in portionedArray
        {
            let isFinalModifyOperation = array == portionedArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: array, recordIDsToDelete: nil)
            modifyOperation.isAtomic = false
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printLog(error.localizedDescription)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printLog(error.localizedDescription)
                }
                    
                else
                {
                    printLog("A modify vehicles operation was completed")
                    if isFinalModifyOperation
                    {
                        printLog("Modifying vehicles complete")
                        self.hideUploadProgress()
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
        
        saveBackgroundContext()
        self.syncTimesheets() {
            closure()
        }
    }
    
    func syncTimesheets(closure: @escaping () -> ())
    {
        let timesheetRequest = AircraftTimesheet.request
        var glidingSiteName = ""
        
        mainQueue.sync(execute: {glidingSiteName = dataModel.glidingCentre.name})
        
        var predicate = NSPredicate(format: "%K > %@ AND %K == %@", argumentArray: [#keyPath(AircraftTimesheet.recordChangeTime), backupStartDate, #keyPath(AircraftTimesheet.glidingCentre.name), glidingSiteName])
        
        timesheetRequest.predicate = predicate
        let allTimesheetRecords = try! backgroundContext.fetch(timesheetRequest)
        
        predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(AircraftTimesheet.recordChangeTime), backupStartDate])
        let query = CKQuery(recordType: CloudKitRecordType.Timesheet.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records = [CKRecord]()
        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }

        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in

            if let error = error
            {
                printError("Error during syncTimesheets query", error)
            }

            if let cursor = cursor
            {
                printLog("Adding newQueryOperation")
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
            else
            {
                self?.hideDownloadProgress()
                self?.processTimesheetRecords(allTimesheetRecords: allTimesheetRecords, records: records) {
                    closure()
                }
            }
        }
        
        showDownloadProgress()
        printLog("Adding queryOperation \(queryOperation.query.debugDescription) to privateDB \(privateDB.debugDescription)")
        privateDB.add(queryOperation)
    }
    
    func processTimesheetRecords(allTimesheetRecords: [AircraftTimesheet], records: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(allTimesheetRecords.count) local timesheet records since \(backupStartDate)")
        printLog("There are \(records.count) remote timesheet records since \(backupStartDate)")
        
        var allTimesheetRecordsSet = Set<AircraftTimesheet>(allTimesheetRecords)

        printLog("Before remove up to date records from local : \(allTimesheetRecordsSet.count).")
        for record in records
        {
            let timesheetRecord = self.updateTimesheetToMatchRecord(record)
            let dateModifiedInCloud = record["recordChangeTime"] as! Date
            printLog("\(timesheetRecord.recordChangeTime) <= \(dateModifiedInCloud) == \(timesheetRecord.recordChangeTime <= dateModifiedInCloud); do record in cloud has a parent? \(record.parent != nil)")
            if timesheetRecord.recordChangeTime <= dateModifiedInCloud, record.parent != nil
            {
                printLog("Removing timesheetRecord from local.")
                allTimesheetRecordsSet.remove(timesheetRecord)
            }
        }
        printLog("After remove up to date records from local : \(allTimesheetRecordsSet.count).")

        var count = allTimesheetRecordsSet.count

        var newRecords = [CKRecord]()

        printLog("Are we viewingSharedDatabase? \(UserDefaults().viewSharedDatabase)")
        if UserDefaults().viewSharedDatabase == false
        {
            for timesheetRecord in allTimesheetRecordsSet
            {
                newRecords.append(createTimesheetRecordFrom(timesheetRecord))
                count -= 1
            }
        }

        printLog("There are \(count) timesheets left to process")
        printLog("Setting up newRecords into portionedArray (block of 100)")
        let portionedArray = CloudKitController.partitionArray(newRecords)

        if portionedArray.count > 0
        {
            showUploadProgress()
        }

        printLog("Processing portionedArray; \(portionedArray.count) block to process.")
        for array in portionedArray
        {
            let isFinalModifyOperation = array == portionedArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: array, recordIDsToDelete: nil)
            modifyOperation.isAtomic = false
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printError("Error occured during perRecordCompletionBlock", error)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printError("Error occured during modifyRecordsCompletionBlock", error)
                }
                    
                else
                {
                    printLog("A modify flight timesheets operation was completed for \(saved?.count ?? 0) records.")
                    if isFinalModifyOperation
                    {
                        printLog("Modifying timesheet records complete")
                        self.hideUploadProgress()
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
        
        saveBackgroundContext()
        self.syncFlightRecords() {
            closure()
        }
    }

    func syncFlightRecords(closure: @escaping () -> ())
    {
        let flightRecordRequest = FlightRecord.request
        var glidingSiteName = ""
        
        mainQueue.sync(execute: {glidingSiteName = dataModel.glidingCentre.name})
        
        var predicate = NSPredicate(format: "%K > %@ AND %K == %@", argumentArray: [#keyPath(FlightRecord.recordChangeTime), backupStartDate, #keyPath(FlightRecord.timesheet.glidingCentre.name), glidingSiteName])
        
        flightRecordRequest.predicate = predicate
        let allFlightRecords = try! backgroundContext.fetch(flightRecordRequest)
        
        predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(FlightRecord.recordChangeTime), backupStartDate])
        let query = CKQuery(recordType: CloudKitRecordType.FlightRecord.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records = [CKRecord]()
        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }
        
        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in
            if let cursor = cursor
            {
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
                
            else
            {
                self?.hideDownloadProgress()
                self?.processFlightRecords(allFlightRecords: allFlightRecords, records: records) {
                    closure()
                }
            }
            
            if let error = error
            {printLog("Error during syncFlightRecords query: \(error)")}
        }
        
        showDownloadProgress()
        privateDB.add(queryOperation)
    }

    func processFlightRecords(allFlightRecords: [FlightRecord], records: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(allFlightRecords.count) local flight records since \(backupStartDate)")
        printLog("There are \(records.count) remote flight records since \(backupStartDate)")
        
        var allFlightRecordsSet = Set<FlightRecord>(allFlightRecords)
        
        for record in records
        {
            let flightRecord = self.updateFlightRecordToMatchRecord(record)
            let dateModifiedInCloud = record["recordChangeTime"] as! Date
            let downTimeInCloud = record["timeDown"] as! Date
            
            if flightRecord.recordChangeTime <= dateModifiedInCloud, record.parent != nil, downTimeInCloud < Date()
            {
                allFlightRecordsSet.remove(flightRecord)
            }
        }
        
        var count = allFlightRecordsSet.count
        
        var newRecords = [CKRecord]()
        
        if UserDefaults().viewSharedDatabase == false
        {
            for flightRecord in allFlightRecordsSet
            {
                newRecords.append(createFlightRecordRecordFrom(flightRecord))
                count -= 1
            }
        }
        printLog("There are \(count) flight records left to process")

        let portionedArray = CloudKitController.partitionArray(newRecords)

        if portionedArray.count > 0
        {
            showUploadProgress()
        }
        
        for array in portionedArray
        {
            let isFinalModifyOperation = array == portionedArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: array, recordIDsToDelete: nil)
            modifyOperation.isAtomic = false
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printError("Error on perRecordCompletionBlock during processFlightRecords", error)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printError("Error on modifyRecordsCompletionBlock during processFlightRecords", error)
                }
                    
                else
                {
                    printLog("A modify flight records operation was completed")
                    if isFinalModifyOperation
                    {
                        printLog("Modifying flight records complete")
                        self.hideUploadProgress()
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
        
        saveBackgroundContext()
        self.syncComments() {
            closure()
        }
    }
    
    func syncComments(closure: @escaping () -> ())
    {
        let commentRequest = GlidingDayComment.request
        var glidingSiteName = ""
        
        mainQueue.sync(execute: {glidingSiteName = dataModel.glidingCentre.name})
        
        var predicate = NSPredicate(format: "%K > %@ AND %K == %@", argumentArray: [#keyPath(GlidingDayComment.recordChangeTime), backupStartDate, #keyPath(GlidingDayComment.glidingCentre.name), glidingSiteName])
        
        commentRequest.predicate = predicate
        let allCommentRecords = try! backgroundContext.fetch(commentRequest)
        
        predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(GlidingDayComment.recordChangeTime), backupStartDate])
        let query = CKQuery(recordType: CloudKitRecordType.Comment.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records = [CKRecord]()
        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }
        
        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in
            if let cursor = cursor
            {
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
                
            else
            {
                self?.hideDownloadProgress()
                self?.processCommentRecords(allCommentRecords: allCommentRecords, records: records) {
                    closure()
                }
            }
            
            if let error = error
            {printLog("Error during sync comments query: \(error)")}
        }

        showDownloadProgress()
        privateDB.add(queryOperation)
    }
    
    func processCommentRecords(allCommentRecords: [GlidingDayComment], records: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(allCommentRecords.count) local comments since \(backupStartDate)")
        printLog("There are \(records.count) remote comments since \(backupStartDate)")
        
        var allCommentRecordsSet = Set<GlidingDayComment>(allCommentRecords)
        
        for record in records
        {
            let commentRecord = self.updateGlidingDayCommentToMatchRecord(record)
            let dateModifiedInCloud = record["recordChangeTime"] as! Date
            if commentRecord.recordChangeTime <= dateModifiedInCloud, record.parent != nil
            {
                allCommentRecordsSet.remove(commentRecord)
            }
        }
        
        var count = allCommentRecordsSet.count
        
        var newRecords = [CKRecord]()
        
        if UserDefaults().viewSharedDatabase == false
        {
            for commentRecord in allCommentRecordsSet
            {
                newRecords.append(createGlidingDayCommentRecordFrom(commentRecord))
                count -= 1
            }
        }
        printLog("There are \(count) comments left to process")

        let portionedArray = CloudKitController.partitionArray(newRecords)

        if portionedArray.count > 0
        {
            showUploadProgress()
        }
        
        for array in portionedArray
        {
            let isFinalModifyOperation = array == portionedArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: array, recordIDsToDelete: nil)
            modifyOperation.isAtomic = false
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printLog(error.localizedDescription)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printLog(error.localizedDescription)
                }
                    
                else
                {
                    printLog("A modify comments operation was completed")
                    if isFinalModifyOperation
                    {
                        printLog("Modifying comments complete")
                        self.hideUploadProgress()
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
        
        saveBackgroundContext()
        self.syncAllMaintenanceIssues() {
            closure()
        }
    }

    func syncAllMaintenanceIssues(closure: @escaping () -> ())
    {
        let issueRequest = MaintenanceEvent.request
        let predicate = NSPredicate(format: "%K > %@", argumentArray: [#keyPath(MaintenanceEvent.recordChangeTime), backupStartDate])
        
        issueRequest.predicate = predicate
        
        let allIssues = try! backgroundContext.fetch(issueRequest)
        let query = CKQuery(recordType: CloudKitRecordType.Maintenance.rawValue, predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        var records = [CKRecord]()
        
        queryOperation.recordFetchedBlock = {(record) in
            records.append(record)
        }
        
        queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryOperation.Cursor?, error: Error?) in
            if let cursor = cursor
            {
                let newQueryOperation = CKQueryOperation(cursor: cursor)
                newQueryOperation.zoneID = self?.zoneID
                
                newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                queryOperation = newQueryOperation
                self!.privateDB.add(newQueryOperation)
            }
                
            else
            {
                self?.hideDownloadProgress()
                self?.processMaintenanceIssues(allIssues: allIssues, records: records) {
                    closure()
                }
            }
            
            if let error = error
            {printLog("Error during sync all issues query: \(error)")}
        }
        
        showDownloadProgress()
        privateDB.add(queryOperation)
    }
    
    func processMaintenanceIssues(allIssues: [MaintenanceEvent], records: [CKRecord], closure: @escaping () -> ())
    {
        printLog("There are \(allIssues.count) local issues")
        printLog("There are \(records.count) remote issues")
        
        var localIssues = Set(allIssues)
        
        for record in records
        {
            let issue = self.updateMaintenanceIssueToMatchRecord(record)
            let dateModifiedInCloud = record["recordChangeTime"] as! Date
            if issue.recordChangeTime <= dateModifiedInCloud, record.parent != nil
            {
                localIssues.remove(issue)
            }
        }
        
        var count = localIssues.count
        var newRecords = [CKRecord]()
        
        if UserDefaults().viewSharedDatabase == false
        {
            for issue in localIssues
            {
                newRecords.append(createMaintenanceIssueRecordFrom(issue))
                count -= 1
            }
            printLog("There are \(count) issues left to process")
        }
        
        let batchArray = CloudKitController.partitionArray(newRecords)

        if batchArray.count > 0
        {
            showUploadProgress()
        }
        else
        {
            // if there nothing else to process... we must call the closure here. Otherwise, it will be called later.
            closure()
        }

        for (idx,batch) in batchArray.enumerated()
        {
            let isFinalModifyOperation = batch == batchArray.last! ? true : false
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
            modifyOperation.isAtomic = false
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {(record, error) in
                if let error = error
                {
                    printError("Error during maintenance issue update", error)
                }
            }
            
            modifyOperation.modifyRecordsCompletionBlock = {(saved, deleted, error) in
                if let error = error
                {
                    printError("Error during maintenance issues update (\(idx) of \(batchArray.count))", error)
                }
                    
                else
                {
                    if isFinalModifyOperation
                    {
                        printLog("The last maintenance issues operation completed (\(idx+1) of \(batchArray.count), batchSize= \(batch.count))")
                        self.hideUploadProgress()
                        // This is the last opportunity to call the closure to save background context and end background task.
                        closure()
                    }
                    else
                    {
                        printLog("A modify maintenance operation was completed (\(idx+1) of \(batchArray.count), batchSize= \(batch.count)")
                    }
                }
            }
            
            modifyOperation.queuePriority = .veryHigh
            privateDB.add(modifyOperation)
        }
    }
    
    //MARK: - Methods that generate a NSManagedObject based on a CKRecord
    
    /// Searches the database for an attendance record matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new Attendance Record object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the Attendance Record object
    func updateAttendanceRecordToMatchRecord(_ record: CKRecord) -> AttendanceRecord
    {
        let ID = record["ID"] as! Date
        let changeTime = record["recordChangeTime"] as! Date
        
        let mainStoreRequest = AttendanceRecord.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        let attendanceRecord: AttendanceRecord
        
        if matchingRecords.count == 0
        {
            attendanceRecord = AttendanceRecord(context: backgroundContext)
        }
            
        else
        {
            attendanceRecord = matchingRecords.first!
            
            if attendanceRecord.recordChangeTime >= changeTime
            {
                return attendanceRecord
            }
        }
        
        attendanceRecord.dayOrSession = record["dayOrSession"] as? Bool ?? true
        attendanceRecord.participantType = record["participantType"] as? String ?? ""
        attendanceRecord.recordChangeTime = record["recordChangeTime"] as? Date ?? Date.distantPast
        attendanceRecord.recordID = record["ID"] as? Date ?? Date.distantPast
        attendanceRecord.timeIn = record["timeIn"] as? Date ?? Date.distantPast
        attendanceRecord.timeOut = record["timeOut"] as? Date ?? Date.distantPast
        
        let gcName = record["glidingCentre"] as? String ?? ""
        
        if attendanceRecord.glidingCentre == nil || attendanceRecord.glidingCentre.name != gcName
        {
            let gcRequest = GlidingCentre.request
            let gcs = try! backgroundContext.fetch(gcRequest)
            
            if gcName != ""
            {
                for gc in gcs
                {
                    if gc.name == gcName
                    {
                        attendanceRecord.glidingCentre = gc
                        break
                    }
                }
                
                if attendanceRecord.glidingCentre == nil || attendanceRecord.glidingCentre.name != gcName
                {
                    let glidingCentre = GlidingCentre(context: backgroundContext)
                    glidingCentre.name = gcName
                    attendanceRecord.glidingCentre = glidingCentre
                }
            }
                
            else
            {
                attendanceRecord.glidingCentre = gcs.first
            }
        }
        
        let pilotID = record["pilot"] as? Date
        
        if let ID = pilotID, attendanceRecord.pilot == nil
        {
            let pilotRequest = Pilot.request
            pilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
            let matchingPilot = try! backgroundContext.fetch(pilotRequest)
            if let pilotFound = matchingPilot.first
            {
                attendanceRecord.pilot = pilotFound
            }
        }
        
        saveBackgroundContext()
        
        return attendanceRecord
    }
    
    /// Searches the database for an aircraft entity matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new aircraft entity object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the aircraft entity object
    func updateVehicleToMatchRecord(_ record: CKRecord) -> AircraftEntity
    {
        let registration = record["registration"] as! String
        let changeTime = record["recordChangeTime"] as! Date

        let mainStoreRequest = AircraftEntity.request
        mainStoreRequest.predicate = NSPredicate(format: "registration == %@", argumentArray: [registration])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        let vehicle: AircraftEntity
        
        if matchingRecords.count == 0
        {
            vehicle = AircraftEntity(context: backgroundContext)
        }
            
        else
        {
            vehicle = matchingRecords.first!
            
            if vehicle.recordChangeTime >= changeTime
            {
                return vehicle
            }
        }
        
        vehicle.recordChangeTime = record["recordChangeTime"] as? Date ?? Date.distantPast
        vehicle.gliderOrTowplane = record["gliderOrTowplane"] as? Int16 ?? 0
//        vehicle.inTheAir = record["inTheAir"] as? Bool ?? false
        vehicle.inTheAir = false

//        vehicle.flightSequence = record["flightSequence"] as? String ?? "Proficiency"
        vehicle.registration = record["registration"] as? String ?? ""
        vehicle.tailNumber = record["tailNumber"] as? String ?? ""
        vehicle.timeToNextInspection = Decimal(string: record["TTNI"] as? String ?? "0.0")! as NSDecimalNumber
        vehicle.remoteChangeTime = Date()
        
        //These are shut down to prevent remote syncs from breaking things. Should fix this
        
//        vehicle.sectionIndex = record["sectionIndex"] as? Int16 ?? 0
        
//        let gcName = record["glidingCentre"] as? String ?? ""
//
//        if vehicle.glidingCentre == nil || vehicle.glidingCentre?.name != gcName
//        {
//            let gcRequest = GlidingCentre.request
//            let gcs = try! backgroundContext.fetch(gcRequest)
//
//            if gcName != ""
//            {
//                for gc in gcs
//                {
//                    if gc.name == gcName
//                    {
//                        vehicle.glidingCentre = gc
//                        break
//                    }
//                }
//
//                if vehicle.glidingCentre == nil || vehicle.glidingCentre?.name != gcName
//                {
//                    let glidingCentre = GlidingCentre(context: backgroundContext)
//                    glidingCentre.name = gcName
//                    vehicle.glidingCentre = glidingCentre
//                }
//            }
//
//            else
//            {
//                vehicle.glidingCentre = gcs.first
//            }
//        }
//
//        if let ID = record["pilot"] as? Date
//        {
//            let pilotRequest = Pilot.request
//            pilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
//            let matchingPilot = try! backgroundContext.fetch(pilotRequest)
//            if let pilotFound = matchingPilot.first
//            {
//                vehicle.pilot = pilotFound
//            }
//        }
//
//        else
//        {
//            vehicle.pilot = nil
//        }
//
//        if let ID = record["passenger"] as? Date
//        {
//            let pilotRequest = Pilot.request
//            pilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
//            let matchingPilot = try! backgroundContext.fetch(pilotRequest)
//            if let pilotFound = matchingPilot.first
//            {
//                vehicle.passenger = pilotFound
//            }
//        }
//
//        else
//        {
//            vehicle.passenger = nil
//        }
//
//        if let ID = record["currentRecord"] as? Date
//        {
//            let recordRequest = FlightRecord.request
//            recordRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
//            let matchingRecord = try! backgroundContext.fetch(recordRequest)
//            if let recordFound = matchingRecord.first
//            {
//                vehicle.currentRecord = recordFound
//            }
//
//            if ID == Date.distantPast
//            {
//                vehicle.currentRecord = nil
//            }
//        }
//
//        if let ID = record["currentTimesheet"] as? Date
//        {
//            let timesheetRequest = AircraftTimesheet.request
//            timesheetRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
//            let matchingTimesheet = try! backgroundContext.fetch(timesheetRequest)
//            if let timesheetFound = matchingTimesheet.first
//            {
//                vehicle.currentTimesheet = timesheetFound
//            }
//
//            if ID == Date.distantPast
//            {
//                vehicle.currentTimesheet = nil
//            }
//        }
        
        saveBackgroundContext()
        
        return vehicle
    }

    /// Searches the database for a timesheet entity matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new timesheet entity object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the aircraft timesheet entity object
    func updateTimesheetToMatchRecord(_ record: CKRecord) -> AircraftTimesheet
    {
        let ID = record["ID"] as! Date
        let changeTime = record["recordChangeTime"] as! Date
        
        let mainStoreTimesheetRequest = AircraftTimesheet.request
        mainStoreTimesheetRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
        let matchingTimesheets = try! backgroundContext.fetch(mainStoreTimesheetRequest)
        let timesheet: AircraftTimesheet
        
        if matchingTimesheets.count == 0
        {
            timesheet = AircraftTimesheet(context: backgroundContext)
        }
            
        else
        {
            timesheet = matchingTimesheets.first!
            
            if timesheet.recordChangeTime >= changeTime
            {
                return timesheet
            }
        }
        
        timesheet.date = record["date"] as? Date ?? Date.distantPast
        timesheet.winchFinalTTSNsetCorrectly = record["winchFinalTTSNsetCorrectly"] as? Bool ?? false
        timesheet.initialTTSN = Decimal(string: record["initialTTSN"] as? String ?? "0.0")! as NSDecimalNumber
        timesheet.finalTTSN = Decimal(string: record["finalTTSN"] as? String ?? "0.0")! as NSDecimalNumber
        timesheet.recordChangeTime = record["recordChangeTime"] as! Date
        timesheet.recordID = record["ID"] as! Date
        timesheet.history = record["history"] as? String ?? ""
        
        let gcName = record["glidingCentre"] as? String ?? ""
        
        if timesheet.glidingCentre == nil || timesheet.glidingCentre?.name != gcName
        {
            let gcRequest = GlidingCentre.request
            let gcs = try! backgroundContext.fetch(gcRequest)
            
            if gcName != ""
            {
                for gc in gcs
                {
                    if gc.name == gcName
                    {
                        timesheet.glidingCentre = gc
                        break
                    }
                }
                
                if timesheet.glidingCentre == nil || timesheet.glidingCentre?.name != gcName
                {
                    let glidingCentre = GlidingCentre(context: backgroundContext)
                    glidingCentre.name = gcName
                    timesheet.glidingCentre = glidingCentre
                }
            }
                
            else
            {
                timesheet.glidingCentre = gcs.first
            }
        }
        
        if let ID = record["vehicleRegistration"] as? String
        {
            let vehicleRequest = AircraftEntity.request
            vehicleRequest.predicate = NSPredicate(format: "registration == %@", argumentArray: [ID])
            let matchingVehicle = try! backgroundContext.fetch(vehicleRequest)
            if let vehicleFound = matchingVehicle.first
            {
                timesheet.aircraft = vehicleFound
            }
        }
        
        saveBackgroundContext()
        
        return timesheet
    }
    
    /// Searches the database for a timesheet entity matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new timesheet entity object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the aircraft timesheet entity object
    func updateMaintenanceIssueToMatchRecord(_ record: CKRecord) -> MaintenanceEvent
    {
        let ID = record["ID"] as! Date
        let changeTime = record["recordChangeTime"] as! Date
        
        let mainStoreMaintenanceRequest = MaintenanceEvent.request
        mainStoreMaintenanceRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
        let matchingMaintenanceIssues = try! backgroundContext.fetch(mainStoreMaintenanceRequest)
        let issue: MaintenanceEvent
        
        if let issueFound = matchingMaintenanceIssues.first
        {
            issue = issueFound
            
            if issue.recordChangeTime >= changeTime
            {
                return issue
            }
        }
            
        else
        {
            issue = MaintenanceEvent(context: backgroundContext)
        }
        
        issue.recordID = record["ID"] as! Date
        issue.recordChangeTime = record["recordChangeTime"] as! Date
        issue.date = record["date"] as! Date
        issue.comment = record["comment"] as! String
        
        if let ID = record["vehicleRegistration"] as? String
        {
            let vehicleRequest = AircraftEntity.request
            vehicleRequest.predicate = NSPredicate(format: "registration == %@", argumentArray: [ID])
            let matchingVehicle = try! backgroundContext.fetch(vehicleRequest)
            if let vehicleFound = matchingVehicle.first
            {
                issue.aircraft = vehicleFound
            }
        }
        
        saveBackgroundContext()
        
        return issue
    }
    
    /// Searches the database for a timesheet entity matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new timesheet entity object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the aircraft timesheet entity object
    func updateGlidingDayCommentToMatchRecord(_ record: CKRecord) -> GlidingDayComment
    {
        let ID = record["ID"] as! Date
        let changeTime = record["recordChangeTime"] as! Date
        
        let mainStoreCommentRequest = GlidingDayComment.request
        mainStoreCommentRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
        let matchingComments = try! backgroundContext.fetch(mainStoreCommentRequest)
        let comment: GlidingDayComment
        
        if let commentFound = matchingComments.first
        {
            comment = commentFound
            
            if comment.recordChangeTime >= changeTime
            {
                return comment
            }
        }
            
        else
        {
            comment = GlidingDayComment(context: backgroundContext)
        }
        
        comment.date = record["date"] as? Date ?? Date.distantPast
        comment.recordChangeTime = record["recordChangeTime"] as! Date
        comment.recordID = record["ID"] as? Date ?? Date.distantPast
        comment.comment = record["comment"] as? String ?? ""
        let gcName = record["glidingCentre"] as? String ?? ""
        
        if comment.glidingCentre == nil || comment.glidingCentre?.name != gcName
        {
            let gcRequest = GlidingCentre.request
            let gcs = try! backgroundContext.fetch(gcRequest)
            
            if gcName != ""
            {
                for gc in gcs
                {
                    if gc.name == gcName
                    {
                        comment.glidingCentre = gc
                        break
                    }
                }
                
                if comment.glidingCentre == nil || comment.glidingCentre?.name != gcName
                {
                    let glidingCentre = GlidingCentre(context: backgroundContext)
                    glidingCentre.name = gcName
                    comment.glidingCentre = glidingCentre
                }
            }
                
            else
            {
                comment.glidingCentre = gcs.first
            }
        }
        
        saveBackgroundContext()
        
        return comment
    }

    
    /// Searches the database for a FlightRecord entity matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new FlightRecord entity object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the FlightRecord object
    func updateFlightRecordToMatchRecord(_ record: CKRecord) -> FlightRecord
    {
        let ID = record["ID"] as! Date
        let changeTime = record["recordChangeTime"] as! Date
        
        let mainStoreFlightRequest = FlightRecord.request
        mainStoreFlightRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
        let matchingFlights = try! backgroundContext.fetch(mainStoreFlightRequest)
        let flight: FlightRecord
        
        if matchingFlights.count == 0
        {
            flight = FlightRecord(context: backgroundContext)
        }
            
        else
        {
            flight = matchingFlights.first!
            
            if flight.recordChangeTime >= changeTime, flight.timesheet != nil, flight.timeDown < Date.distantFuture
            {
                return flight
            }
        }
        
        flight.timeUp = record["timeUp"] as? Date ?? Date.distantPast
        flight.timeDown = record["timeDown"] as? Date ?? Date.distantPast
        flight.recordChangeTime = record["recordChangeTime"] as! Date
        flight.recordID = record["ID"] as! Date
        flight.picParticipantType = record["picParticipantType"] as? String ?? ""
        flight.dualParticipantType = record["dualParticipantType"] as? String
        flight.transitRoute = record["transitRoute"] as? String ?? ""
        flight.flightSequence = record["flightSequence"] as? String ?? ""
        flight.flightLengthInMinutes = record["flightLengthInMinutes"] as? Int16 ?? 0
        
        if let ID = record["picRecordID"] as? Date
        {
            let pilotRequest = Pilot.request
            pilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
            let matchingPilot = try! backgroundContext.fetch(pilotRequest)
            if let pilotFound = matchingPilot.first
            {
                flight.pilot = pilotFound
            }
        }
        
        if let ID = record["passengerRecordID"] as? Date
        {
            let pilotRequest = Pilot.request
            pilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
            let matchingPilots = try! backgroundContext.fetch(pilotRequest)
            if let pilotFound = matchingPilots.first
            {
                flight.passenger = pilotFound
            }
        }
        
        if let ID = record["timesheetRecordID"] as? Date
        {
            let timesheetRequest = AircraftTimesheet.request
            timesheetRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
            let matchingTimesheets = try! backgroundContext.fetch(timesheetRequest)
            if let timesheetFound = matchingTimesheets.first
            {
                flight.timesheet = timesheetFound
            }
        }
        
        if let ID = record["connectedRecordID"] as? Date
        {
            let connectedRecordRequest = FlightRecord.request
            connectedRecordRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
            let matchingFlights = try! backgroundContext.fetch(connectedRecordRequest)
            if let flightFound = matchingFlights.first
            {
                flight.connectedAircraftRecord = flightFound
            }
        }
        
//        if flight.pilot == nil || flight.timesheet == nil
//        {
//            backgroundContext.delete(flight)
//            ~>{self.flightRecordsRemotelyUpdated.insert(record)}
//        }
        
        saveBackgroundContext()
        
        return flight
    }
    
    /// Searches the database for a pilot matching a provided CKRecord. If one is found, it is made to match the record in question. Otherwise, a new Pilot object is created
    ///
    /// - Parameter record: a CKRecord
    /// - Returns: the Pilot object
    func updatePilotToMatchRecord(_ record: CKRecord) -> Pilot
    {
        let ID = record["ID"] as! Date
        let changeTime = record["recordChangeTime"] as! Date
        
        let mainStorePilotRequest = Pilot.request
        mainStorePilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [ID])
        let matchingPilots = try! backgroundContext.fetch(mainStorePilotRequest)
        let pilot: Pilot
        
        if matchingPilots.count == 0
        {
            pilot = Pilot(context: backgroundContext)
        }
            
        else
        {
            pilot = matchingPilots.first!
            
            if pilot.recordChangeTime >= changeTime
            {
                return pilot
            }
        }
        
        pilot.aniversaryOfGliderAPC = record["aniversaryOfGliderAPC"] as? Date ?? Date.distantPast
        pilot.name = record["name"] as? String ?? ""
        pilot.firstName = record["firstName"] as? String ?? ""
        pilot.address = record["address"] as? String ?? ""
        pilot.aniversaryOfTowAPC = record["aniversaryOfTowAPC"] as? Date ?? Date.distantPast
        pilot.birthday = record["birthday"] as? Date ?? Date.distantPast
        pilot.dateOfBasicGliderPilot = record["dateOfBasicGliderPilot"] as? Date ?? Date.distantPast
        pilot.dateOfFrontSeatFamilPilot = record["dateOfFrontSeatFamilPilot"] as? Date ?? Date.distantPast
        pilot.dateOfGliderCheckPilot = record["dateOfGliderCheckPilot"] as? Date ?? Date.distantPast
        pilot.dateOfGliderInstructorPilot = record["dateOfGliderInstructorPilot"] as? Date ?? Date.distantPast
        pilot.dateOfGliderPilotXCountry = record["dateOfGliderPilotXCountry"] as? Date ?? Date.distantPast
        pilot.dateOfGliderStandardsPilot = record["dateOfGliderStandardsPilot"] as? Date ?? Date.distantPast
        pilot.dateOfLaunchControlOfficer = record["dateOfLaunchControlOfficer"] as? Date ?? Date.distantPast
        pilot.dateOfRearSeatFamilPilot = record["dateOfRearSeatFamilPilot"] as? Date ?? Date.distantPast
        pilot.dateOfTowCheckPilot = record["dateOfTowCheckPilot"] as? Date ?? Date.distantPast
        pilot.dateOfTowPilot = record["dateOfTowPilot"] as? Date ?? Date.distantPast
        pilot.dateOfTowPilotXCountry = record["dateOfTowPilotXCountry"] as? Date ?? Date.distantPast
        pilot.dateOfTowStandardsPilot = record["dateOfTowStandardsPilot"] as? Date ?? Date.distantPast
        pilot.dateOfWinchLaunchInstructor = record["dateOfWinchLaunchInstructor"] as? Date ?? Date.distantPast
        pilot.dateOfWinchLaunchOperator = record["dateOfWinchLaunchOperator"] as? Date ?? Date.distantPast
        pilot.dateOfWinchLaunchPilot = record["dateOfWinchLaunchPilot"] as? Date ?? Date.distantPast
        pilot.dateOfWinchRetrieveDriver = record["dateOfWinchRetrieveDriver"] as? Date ?? Date.distantPast
        pilot.email = record["email"] as? String ?? ""
        pilot.fiExpiry = record["fiExpiry"] as? Date ?? Date.distantPast
        pilot.fullName = record["fullName"] as? String ?? ""
        pilot.gliderLicense = record["gliderLicense"] as? String ?? ""
        pilot.highestGliderQual = record["highestGliderQual"] as! Int16
        pilot.highestScoutQual = record["highestScoutQual"] as! Int16
        pilot.inactive = record["inactive"] as! Bool
        pilot.medical = record["medical"] as? Date ?? Date.distantPast
//        pilot.modifiedBy = record["modifiedBy"] as? String
        pilot.phone = record["phone"] as? String ?? ""
        pilot.powerLicense = record["powerLicense"] as? String ?? ""
        pilot.recordChangeTime = record["recordChangeTime"] as! Date
        pilot.signedIn = record["signedIn"] as! Bool
        pilot.squadron = record["squadron"] as! Int16
//        pilot.timeDown = record["timeDown"] as? Date
//        pilot.timeIn = record["timeIn"] as? Date
        pilot.typeOfParticipant = record["typeOfParticipant"] as? String ?? ""
        pilot.recordID = record["ID"] as! Date
        pilot.gliderFlightsAdjustment = record["gliderFlightsAdjustment"] as? Int64 ?? 0
        pilot.gliderInstHoursAdjust = record["gliderInstHoursAdjust"] as? Int64 ?? 0
        pilot.gliderPIChoursAdjust = record["gliderPIChoursAdjust"] as? Int64 ?? 0
        pilot.powerHoursAdjust = record["powerHoursAdjust"] as? Int64 ?? 0

        let gcName = record["glidingCentre"] as? String ?? ""
        
        if pilot.glidingCentre == nil || pilot.glidingCentre.name != gcName
        {
            let gcRequest = GlidingCentre.request
            let gcs = try! backgroundContext.fetch(gcRequest)
            
            if gcName != ""
            {
                for gc in gcs
                {
                    if gc.name == gcName
                    {
                        pilot.glidingCentre = gc
                        break
                    }
                }
                
                if pilot.glidingCentre == nil || pilot.glidingCentre.name != gcName
                {
                    let glidingCentre = GlidingCentre(context: backgroundContext)
                    glidingCentre.name = gcName
                    pilot.glidingCentre = glidingCentre
                }
            }
                
            else
            {
                pilot.glidingCentre = gcs.first
            }
        }
        
        ~>{NotificationCenter.default.post(name: reloadPilotNotification, object: pilot, userInfo: ["Don't upload" : true])}
        
        saveBackgroundContext()
        
        return pilot
    }
    
    //MARK: - Methods that turn an NSManagedObject subclass into a CKRecord
    
    func appendRegionTo(record: CKRecord)
    {
        if let rootRecordID = rootObject?.recordID
        {
            let rootReference = CKRecord.Reference(recordID: rootRecordID, action: .none)
            record.parent = rootReference
        }
    }
    
    /// Returns a CKRecord with the same data as an Attendance Record object. If an existing CKRecord is provided it will have its data changed to match the Attendance Record object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - pilot: The Pilot NSManagedObject the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createAttendanceRecordRecordFrom(_ attendanceRecord: AttendanceRecord, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let attendanceRecordID = CKRecord.ID(recordName: String(attendanceRecord.recordID.timeIntervalSince1970), zoneID: zoneID)
        let attendanceCK = record ?? CKRecord(recordType: CloudKitRecordType.Attendance.rawValue, recordID: attendanceRecordID)
        
        if let changeTime = attendanceCK["recordChangeTime"] as? Date, changeTime >= attendanceRecord.recordChangeTime
        {
            return attendanceCK
        }
        
        attendanceCK["dayOrSession"] = attendanceRecord.dayOrSession as NSNumber
        attendanceCK["participantType"] = attendanceRecord.participantType as NSString
        attendanceCK["recordChangeTime"] = attendanceRecord.recordChangeTime as NSDate
        attendanceCK["ID"] = attendanceRecord.recordID as NSDate
        attendanceCK["timeIn"] = attendanceRecord.timeIn as NSDate
        attendanceCK["timeOut"] = attendanceRecord.timeOut as NSDate
        attendanceCK["glidingCentre"] = attendanceRecord.glidingCentre?.name as NSString? ?? nil
        attendanceCK["pilot"] = attendanceRecord.pilot?.recordID as NSDate? ?? nil
        attendanceCK["pilotFullName"] = attendanceRecord.pilot?.fullName as NSString? ?? nil
        appendRegionTo(record: attendanceCK)
        
        return attendanceCK
    }
    
    /// Returns a CKRecord with the same data as an GlidingDayComment object. If an existing CKRecord is provided it will have its data changed to match the GlidingDayComment object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - glidingDayComment: The GlidingDayComment NSManagedObject the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createGlidingDayCommentRecordFrom(_ glidingDayComment: GlidingDayComment, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let commentRecordID = CKRecord.ID(recordName: String(glidingDayComment.recordID.timeIntervalSince1970), zoneID: zoneID)
        let commentCK = record ?? CKRecord(recordType: CloudKitRecordType.Comment.rawValue, recordID: commentRecordID)
        
        if let changeTime = commentCK["recordChangeTime"] as? Date, changeTime >= glidingDayComment.recordChangeTime
        {
            return commentCK
        }
        
        commentCK["recordChangeTime"] = glidingDayComment.recordChangeTime as NSDate
        commentCK["ID"] = glidingDayComment.recordID as NSDate
        commentCK["date"] = glidingDayComment.date as NSDate
        commentCK["glidingCentre"] = glidingDayComment.glidingCentre?.name as NSString? ?? nil
        commentCK["comment"] = glidingDayComment.comment as NSString
        appendRegionTo(record: commentCK)

        return commentCK
    }
    
    /// Returns a CKRecord with the same data as an MaintenanceEvent object. If an existing CKRecord is provided it will have its data changed to match the MaintenanceEvent object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - MaintenanceEvent: The MaintenanceEvent the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createMaintenanceIssueRecordFrom(_ maintenanceIssue: MaintenanceEvent, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let maintenanceRecordID = CKRecord.ID(recordName: String(maintenanceIssue.recordID.timeIntervalSince1970), zoneID: zoneID)
        let maintenanceIssueCK = record ?? CKRecord(recordType: CloudKitRecordType.Maintenance.rawValue, recordID: maintenanceRecordID)
        
        if let changeTime = maintenanceIssueCK["recordChangeTime"] as? Date, changeTime >= maintenanceIssue.recordChangeTime
        {
            return maintenanceIssueCK
        }
        
        maintenanceIssueCK["recordChangeTime"] = maintenanceIssue.recordChangeTime as NSDate
        maintenanceIssueCK["ID"] = maintenanceIssue.recordID as NSDate
        maintenanceIssueCK["date"] = maintenanceIssue.date as NSDate
        maintenanceIssueCK["comment"] = maintenanceIssue.comment as NSString
        maintenanceIssueCK["vehicleRegistration"] = maintenanceIssue.aircraft.registration as NSString
        appendRegionTo(record: maintenanceIssueCK)

        return maintenanceIssueCK
    }
    
    /// Returns a CKRecord with the same data as an Flight Record object. If an existing CKRecord is provided it will have its data changed to match the Flight Record object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - flightRecord: The Flight Record NSManagedObject the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createFlightRecordRecordFrom(_ flightRecord: FlightRecord, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let flightRecordID = CKRecord.ID(recordName: String(flightRecord.recordID.timeIntervalSince1970), zoneID: zoneID)
        let flightCK = record ?? CKRecord(recordType: CloudKitRecordType.FlightRecord.rawValue, recordID: flightRecordID)
        
        if let changeTime = flightCK["recordChangeTime"] as? Date, changeTime >= flightRecord.recordChangeTime
        {
            if flightCK.parent == nil {appendRegionTo(record: flightCK)}
            if flightCK["timeDown"] as! Date > Date()
            {
                flightCK["timeDown"] = flightRecord.timeDown as NSDate
            }
            return flightCK
        }
        
        flightCK["timeUp"] = flightRecord.timeUp as NSDate
        flightCK["timeDown"] = flightRecord.timeDown as NSDate
        flightCK["recordChangeTime"] = flightRecord.recordChangeTime as NSDate
        flightCK["ID"] = flightRecord.recordID as NSDate
        flightCK["picParticipantType"] = flightRecord.picParticipantType as NSString
        flightCK["dualParticipantType"] = flightRecord.dualParticipantType as NSString?
        flightCK["transitRoute"] = flightRecord.transitRoute as NSString?
        flightCK["flightSequence"] = flightRecord.flightSequence as NSString
        flightCK["flightLengthInMinutes"] = flightRecord.flightLengthInMinutes as NSNumber
        flightCK["picRecordID"] = flightRecord.pilot?.recordID as NSDate? ?? nil
        flightCK["passengerRecordID"] = flightRecord.passenger?.recordID as NSDate? ?? nil
        flightCK["timesheetRecordID"] = flightRecord.timesheet?.recordID as NSDate? ?? nil
        flightCK["connectedRecordID"] = flightRecord.connectedAircraftRecord?.recordID as NSDate? ?? nil
        flightCK["pilot"] = flightRecord.pilot.fullName as NSString? ?? nil
        flightCK["passenger"] = flightRecord.passenger?.fullName as NSString? ?? nil
        flightCK["aircraft"] = flightRecord.timesheet.aircraft.tailNumber as NSString? ?? nil
        flightCK["connectedAircraft"] = flightRecord.connectedAircraftRecord?.timesheet?.aircraft?.tailNumber as NSString? ?? nil
        flightCK["gliderOrTowplane"] = flightRecord.timesheet.aircraft.gliderOrTowplane as NSNumber
        flightCK["glidingCenter"] = flightRecord.timesheet.glidingCentre.name as NSString
        appendRegionTo(record: flightCK)

        return flightCK
    }
    
    /// Returns a CKRecord with the same data as an Aircraft Timesheet object. If an existing CKRecord is provided it will have its data changed to match the Aircraft Timesheet object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - timesheet: The Timesheet NSManagedObject the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createTimesheetRecordFrom(_ timesheet: AircraftTimesheet, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let timesheetRecordID = CKRecord.ID(recordName: String(timesheet.recordID.timeIntervalSince1970), zoneID: zoneID)
        let timesheetCK = record ?? CKRecord(recordType: CloudKitRecordType.Timesheet.rawValue, recordID: timesheetRecordID)
        
        if let changeTime = timesheetCK["recordChangeTime"] as? Date, changeTime >= timesheet.recordChangeTime
        {
            return timesheetCK
        }
        
        timesheetCK["recordChangeTime"] = timesheet.recordChangeTime as NSDate
        timesheetCK["ID"] = timesheet.recordID as NSDate
        timesheetCK["date"] = timesheet.date as NSDate
        timesheetCK["winchFinalTTSNsetCorrectly"] = timesheet.winchFinalTTSNsetCorrectly as NSNumber
        timesheetCK["initialTTSN"] = timesheet.initialTTSN.stringWithDecimal as NSString
        timesheetCK["finalTTSN"] = timesheet.finalTTSN.stringWithDecimal as NSString
        timesheetCK["glidingCentre"] = timesheet.glidingCentre?.name as NSString?
        timesheetCK["vehicleRegistration"] = timesheet.aircraft.registration as NSString
        timesheetCK["history"] = timesheet.history as NSString

        appendRegionTo(record: timesheetCK)

        return timesheetCK
    }
    
    /// Returns a CKRecord with the same data as an AircraftEntity object. If an existing CKRecord is provided it will have its data changed to match the AircraftEntity object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - vehicle: The AircraftEntity NSManagedObject the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createVehicleRecordFrom(_ vehicle: AircraftEntity, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let vehicleRecordID = CKRecord.ID(recordName: String(self.regionName + vehicle.registration), zoneID: zoneID)
        let vehicleCK = record ?? CKRecord(recordType: CloudKitRecordType.Vehicle.rawValue, recordID: vehicleRecordID)
        
        vehicleCK["gliderOrTowplane"] = vehicle.gliderOrTowplane as NSNumber
        vehicleCK["flightSequence"] = vehicle.flightSequence as NSString
        vehicleCK["inTheAir"] = vehicle.inTheAir as NSNumber
        vehicleCK["registration"] = vehicle.registration as NSString
        vehicleCK["tailNumber"] = vehicle.tailNumber as NSString
        vehicleCK["TTNI"] = vehicle.timeToNextInspection.stringWithDecimal as NSString
        vehicleCK["sectionIndex"] = vehicle.sectionIndex as NSNumber
        vehicleCK["currentRecord"] = vehicle.currentRecord?.recordID as NSDate? ?? Date.distantPast as NSDate
        vehicleCK["glidingCentre"] = vehicle.glidingCentre?.name as NSString? ?? nil
        vehicleCK["pilot"] = vehicle.pilot?.recordID as NSDate? ?? nil
        vehicleCK["passenger"] = vehicle.passenger?.recordID as NSDate? ?? nil
        vehicleCK["recordChangeTime"] = vehicle.recordChangeTime as NSDate
        appendRegionTo(record: vehicleCK)

        return vehicleCK
    }


    
    /// Returns a CKRecord with the same data as a Pilot object. If an existing CKRecord is provided it will have its data changed to match the Pilot object, otherwise a new CKRecord is created
    ///
    /// - Parameters:
    ///   - pilot: The Pilot NSManagedObject the CKRecord will be based off of
    ///   - record: An existing CKRecord to be updated
    /// - Returns: A matching CKRecord
    func createPilotRecordFrom(_ pilot: Pilot, withExistingRecord record: CKRecord? = nil) -> CKRecord
    {
        let pilotRecordID = CKRecord.ID(recordName: String(pilot.recordID.timeIntervalSince1970), zoneID: zoneID)
        let pilotRecord = record ?? CKRecord(recordType: CloudKitRecordType.Pilot.rawValue, recordID: pilotRecordID)
        
        if let changeTime = pilotRecord["recordChangeTime"] as? Date, changeTime >= pilot.recordChangeTime
        {
            return pilotRecord
        }
        
        pilotRecord["aniversaryOfGliderAPC"] = pilot.aniversaryOfGliderAPC as NSDate
        pilotRecord["name"] = pilot.name as NSString
        pilotRecord["firstName"] = pilot.firstName as NSString
        pilotRecord["address"] = pilot.address as NSString
        pilotRecord["aniversaryOfTowAPC"] = pilot.aniversaryOfTowAPC as NSDate
        pilotRecord["birthday"] = pilot.birthday as NSDate
        pilotRecord["dateOfBasicGliderPilot"] = pilot.dateOfBasicGliderPilot as NSDate
        pilotRecord["dateOfFrontSeatFamilPilot"] = pilot.dateOfFrontSeatFamilPilot as NSDate
        pilotRecord["dateOfGliderCheckPilot"] = pilot.dateOfGliderCheckPilot as NSDate
        pilotRecord["dateOfGliderInstructorPilot"] = pilot.dateOfGliderInstructorPilot as NSDate
        pilotRecord["dateOfGliderPilotXCountry"] = pilot.dateOfGliderPilotXCountry as NSDate
        pilotRecord["dateOfGliderStandardsPilot"] = pilot.dateOfGliderStandardsPilot as NSDate
        pilotRecord["dateOfLaunchControlOfficer"] = pilot.dateOfLaunchControlOfficer as NSDate
        pilotRecord["dateOfRearSeatFamilPilot"] = pilot.dateOfRearSeatFamilPilot as NSDate
        pilotRecord["dateOfTowCheckPilot"] = pilot.dateOfTowCheckPilot as NSDate
        pilotRecord["dateOfTowPilot"] = pilot.dateOfTowPilot as NSDate
        pilotRecord["dateOfTowPilotXCountry"] = pilot.dateOfTowPilotXCountry as NSDate
        pilotRecord["dateOfTowStandardsPilot"] = pilot.dateOfTowStandardsPilot as NSDate
        pilotRecord["dateOfWinchLaunchInstructor"] = pilot.dateOfWinchLaunchInstructor as NSDate
        pilotRecord["dateOfWinchLaunchOperator"] = pilot.dateOfWinchLaunchOperator as NSDate
        pilotRecord["dateOfWinchLaunchPilot"] = pilot.dateOfWinchLaunchPilot as NSDate
        pilotRecord["dateOfWinchRetrieveDriver"] = pilot.dateOfWinchRetrieveDriver as NSDate
        pilotRecord["email"] = pilot.email as NSString
        pilotRecord["fiExpiry"] = pilot.fiExpiry as NSDate
        pilotRecord["fullName"] = pilot.fullName as NSString
        pilotRecord["gliderLicense"] = pilot.gliderLicense as NSString
        pilotRecord["highestGliderQual"] = pilot.highestGliderQual as NSNumber
        pilotRecord["highestScoutQual"] = pilot.highestScoutQual as NSNumber
        pilotRecord["inactive"] = pilot.inactive as NSNumber
        pilotRecord["medical"] = pilot.medical as NSDate
        pilotRecord["phone"] = pilot.phone as NSString
        pilotRecord["powerLicense"] = pilot.powerLicense as NSString
        pilotRecord["recordChangeTime"] = pilot.recordChangeTime as NSDate
        pilotRecord["signedIn"] = pilot.signedIn as NSNumber
        pilotRecord["squadron"] = pilot.squadron as NSNumber
        pilotRecord["typeOfParticipant"] = pilot.typeOfParticipant as NSString
        pilotRecord["ID"] = pilot.recordID as NSDate
        pilotRecord["glidingCentre"] = pilot.glidingCentre?.name as NSString? ?? ""
        pilotRecord["gliderFlightsAdjustment"] = pilot.gliderFlightsAdjustment as NSNumber
        pilotRecord["gliderInstHoursAdjust"] = pilot.gliderInstHoursAdjust as NSNumber
        pilotRecord["gliderPIChoursAdjust"] = pilot.gliderPIChoursAdjust as NSNumber
        pilotRecord["powerHoursAdjust"] = pilot.powerHoursAdjust as NSNumber
        appendRegionTo(record: pilotRecord)

        return pilotRecord
    }
    
    //MARK: - Methods that handle remote deletions
    
    func deleteAttendanceRecordWithID(_ recordID: CKRecord.ID)
    {
        let timeSince1970 = Double(recordID.recordName)!
        let approxRecordID = Date(timeIntervalSince1970: timeSince1970)
        let intervalBegin = approxRecordID - 0.0001
        let intervalEnd = approxRecordID + 0.0001

        let mainStoreRequest = AttendanceRecord.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID > %@ AND recordID < %@", argumentArray: [intervalBegin, intervalEnd])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        
        if matchingRecords.count > 1
        {
            printLog("Delete attendance record aborted, multiple records with similar ID")
            return
        }
        
        if let attendanceRecord = matchingRecords.first
        {
            backgroundContext.delete(attendanceRecord)
            saveBackgroundContext()
        }
    }
    
    func deletePilotWithID(_ recordID: CKRecord.ID)
    {
        let timeSince1970 = Double(recordID.recordName)!
        let approxRecordID = Date(timeIntervalSince1970: timeSince1970)
        let intervalBegin = approxRecordID - 0.0001
        let intervalEnd = approxRecordID + 0.0001
        
        let mainStoreRequest = Pilot.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID > %@ AND recordID < %@", argumentArray: [intervalBegin, intervalEnd])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        
        if matchingRecords.count > 1
        {
            printLog("Delete pilot aborted, multiple records with similar ID")
            return
        }
        
        if let pilot = matchingRecords.first, pilot.picFlights.count == 0, pilot.dualFlights.count == 0
        {
            backgroundContext.delete(pilot)
            saveBackgroundContext()
        }
    }
    
    func deleteFlightRecordWithID(_ recordID: CKRecord.ID)
    {
        let timeSince1970 = Double(recordID.recordName)!
        let approxRecordID = Date(timeIntervalSince1970: timeSince1970)
        let intervalBegin = approxRecordID - 0.0001
        let intervalEnd = approxRecordID + 0.0001
        
        let mainStoreRequest = FlightRecord.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID > %@ AND recordID < %@", argumentArray: [intervalBegin, intervalEnd])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        
        if matchingRecords.count > 1
        {
            printLog("Delete attendance record aborted, multiple records with similar ID")
            return
        }
        
        if let flightRecord = matchingRecords.first
        {
            backgroundContext.delete(flightRecord)
            saveBackgroundContext()
        }
    }
    
    func deleteTimesheetWithID(_ recordID: CKRecord.ID)
    {
        let timeSince1970 = Double(recordID.recordName)!
        let approxRecordID = Date(timeIntervalSince1970: timeSince1970)
        let intervalBegin = approxRecordID - 0.0001
        let intervalEnd = approxRecordID + 0.0001
        
        let mainStoreRequest = AircraftTimesheet.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID > %@ AND recordID < %@", argumentArray: [intervalBegin, intervalEnd])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        
        if matchingRecords.count > 1
        {
            printLog("Delete timesheet aborted, multiple records with similar ID")
            return
        }
        
        if let timesheet = matchingRecords.first
        {
            if timesheet.flightRecords.count > 0
            {
                printLog("Delete timesheet aborted, timesheet has records")
                return
            }
            
            backgroundContext.delete(timesheet)
            saveBackgroundContext()
        }
    }
    
    func deleteCommentWithID(_ recordID: CKRecord.ID)
    {
        let timeSince1970 = Double(recordID.recordName)!
        let approxRecordID = Date(timeIntervalSince1970: timeSince1970)
        let intervalBegin = approxRecordID - 0.0001
        let intervalEnd = approxRecordID + 0.0001
        
        let mainStoreRequest = GlidingDayComment.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID > %@ AND recordID < %@", argumentArray: [intervalBegin, intervalEnd])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        
        if matchingRecords.count > 1
        {
            printLog("Delete comment record aborted, multiple records with similar ID")
            return
        }
        
        if let comment = matchingRecords.first
        {
            backgroundContext.delete(comment)
            saveBackgroundContext()
        }
    }
    
    func deleteMaintenanceIssueWithID(_ recordID: CKRecord.ID)
    {
        let timeSince1970 = Double(recordID.recordName)!
        let approxRecordID = Date(timeIntervalSince1970: timeSince1970)
        let intervalBegin = approxRecordID - 0.0001
        let intervalEnd = approxRecordID + 0.0001
        
        let mainStoreRequest = MaintenanceEvent.request
        mainStoreRequest.predicate = NSPredicate(format: "recordID > %@ AND recordID < %@", argumentArray: [intervalBegin, intervalEnd])
        let matchingRecords = try! backgroundContext.fetch(mainStoreRequest)
        
        if matchingRecords.count > 1
        {
            printLog("Delete maintenance record aborted, multiple records with similar ID")
            return
        }
        
        if let issue = matchingRecords.first
        {
            backgroundContext.delete(issue)
            saveBackgroundContext()
        }
    }
    
    //MARK: - Methods that handle local deletions
    func deleteAttendanceRecord(_ record: AttendanceRecord?)
    {
        guard UserDefaults().viewSharedDatabase == false else{return}
        
        if let record = record
        {
            let recordIDstring = String(record.recordID.timeIntervalSince1970)
            deletedAttendanceRecords.insert(recordIDstring)
            changedAttendanceRecords.remove(record.objectID)            //must not attempt to update it if it is gone
        }
        
        if networkReachable == false
        {
            return
        }
        
        let deletedAttendanceRecordsCopy = deletedAttendanceRecords
        deletedAttendanceRecords.removeAll()
        UserDefaults().attendanceRecordsToBeDeleted = deletedAttendanceRecords
        
        for objectID in deletedAttendanceRecordsCopy
        {
            %>{
                let deletedRecordID = CKRecord.ID(recordName: String(objectID), zoneID: self.zoneID)
            
                self.privateDB.delete(withRecordID: deletedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        printLog("Attendance record didn't get deleted.")
                        printLog(error.localizedDescription)

                        ~>{self.deletedAttendanceRecords.insert(objectID)
                            UserDefaults().attendanceRecordsToBeDeleted = self.deletedAttendanceRecords}
                    }
                }
            }
        }
    }
    
    func deleteFlightRecord(_ record: FlightRecord?)
    {
        guard UserDefaults().viewSharedDatabase == false else{return}

        if let record = record
        {
            let recordIDstring = String(record.recordID.timeIntervalSince1970)
            deletedFlightRecords.insert(recordIDstring)
            changedFlightRecords.remove(record.objectID)            //must not attempt to update it if it is gone
        }
        
        if networkReachable == false
        {
            return
        }
        
        let deletedFlightRecordsCopy = deletedFlightRecords
        deletedFlightRecords.removeAll()
        UserDefaults().flightRecordsToBeDeleted = deletedFlightRecords
        
        for objectID in deletedFlightRecordsCopy
        {
            %>{
                let deletedRecordID = CKRecord.ID(recordName: String(objectID), zoneID: self.zoneID)
                
                self.privateDB.delete(withRecordID: deletedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        printLog("Flight record didn't get deleted.")
                        printLog(error.localizedDescription)
                        
                        ~>{self.deletedFlightRecords.insert(objectID)
                            UserDefaults().flightRecordsToBeDeleted = self.deletedFlightRecords}
                    }
                }
            }
        }
    }
    
    func deletePilot(_ record: Pilot?)
    {
        guard UserDefaults().viewSharedDatabase == false else{return}

        if let record = record
        {
            let recordIDstring = String(record.recordID.timeIntervalSince1970)
            deletedPilots.insert(recordIDstring)
            changedPilots.remove(record.objectID)            //must not attempt to update it if it is gone
        }
        
        if networkReachable == false
        {
            return
        }
        
        let deletedPilotsCopy = deletedPilots
        deletedPilots.removeAll()
        UserDefaults().pilotsToBeDeleted = deletedPilots
        
        for objectID in deletedPilotsCopy
        {
            %>{
                let deletedRecordID = CKRecord.ID(recordName: String(objectID), zoneID: self.zoneID)
                
                self.privateDB.delete(withRecordID: deletedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        printLog("Pilot didn't get deleted.")
                        printLog(error.localizedDescription)
                        
                        ~>{self.deletedPilots.insert(objectID)
                            UserDefaults().pilotsToBeDeleted = self.deletedPilots}
                    }
                }
            }
        }
    }
    
    func deleteTimesheet(_ record: AircraftTimesheet?)
    {
        guard UserDefaults().viewSharedDatabase == false else{return}

        if let record = record
        {
            let recordIDstring = String(record.recordID.timeIntervalSince1970)
            deletedTimesheets.insert(recordIDstring)
            changedTimesheets.remove(record.objectID)            //must not attempt to update it if it is gone
        }
        
        if networkReachable == false
        {
            return
        }
        
        let deletedTimesheetsCopy = deletedTimesheets
        deletedTimesheets.removeAll()
        UserDefaults().timesheetsToBeDeleted = deletedTimesheets
        
        for objectID in deletedTimesheetsCopy
        {
            %>{
                let deletedRecordID = CKRecord.ID(recordName: String(objectID), zoneID: self.zoneID)
                
                self.privateDB.delete(withRecordID: deletedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        printLog("Timesheet record didn't get deleted.")
                        printLog(error.localizedDescription)
                        
                        ~>{self.deletedTimesheets.insert(objectID)
                            UserDefaults().timesheetsToBeDeleted = self.deletedTimesheets}
                    }
                }
            }
        }
    }
    
    func deleteComment(_ record: GlidingDayComment?)
    {
        guard UserDefaults().viewSharedDatabase == false else{return}

        if let record = record
        {
            let recordIDstring = String(record.recordID.timeIntervalSince1970)
            deletedComments.insert(recordIDstring)
            changedGlidingDayComments.remove(record.objectID)            //must not attempt to update it if it is gone
        }
        
        if networkReachable == false
        {
            return
        }
        
        let deletedCommentsCopy = deletedComments
        deletedComments.removeAll()
        UserDefaults().commentsToBeDeleted = deletedComments
        
        for objectID in deletedCommentsCopy
        {
            %>{
                let deletedRecordID = CKRecord.ID(recordName: String(objectID), zoneID: self.zoneID)
                
                self.privateDB.delete(withRecordID: deletedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        printLog("Comment record didn't get deleted.")
                        printLog(error.localizedDescription)
                        
                        ~>{self.deletedComments.insert(objectID)
                            UserDefaults().commentsToBeDeleted = self.deletedComments}
                    }
                }
            }
        }
    }
    
    func deleteMaintenanceIssue(_ record: MaintenanceEvent?)
    {
        guard UserDefaults().viewSharedDatabase == false else{return}

        if let record = record
        {
            let recordIDstring = String(record.recordID.timeIntervalSince1970)
            deletedMaintenanceIssues.insert(recordIDstring)
            changedMaintenanceIssues.remove(record.objectID)            //must not attempt to update it if it is gone
        }
        
        if networkReachable == false
        {
            return
        }
        
        let deletedMaintenanceIssuesCopy = deletedMaintenanceIssues
        deletedMaintenanceIssues.removeAll()
        UserDefaults().maintenanceIssuesToBeDeleted = deletedMaintenanceIssues
        
        for objectID in deletedMaintenanceIssuesCopy
        {
            %>{
                let deletedRecordID = CKRecord.ID(recordName: String(objectID), zoneID: self.zoneID)
                self.privateDB.delete(withRecordID: deletedRecordID)
                {
                    (record, error) in
                    if let error = error as? CKError
                    {
                        printLog("Maintenance record didn't get deleted.")
                        printLog(error.localizedDescription)
                        
                        ~>{self.deletedMaintenanceIssues.insert(objectID)
                            UserDefaults().maintenanceIssuesToBeDeleted = self.deletedMaintenanceIssues}
                    }
                }
            }
        }
    }

    func createBackgroundTask(_ name : String, _ file : String = #file, _ function : String = #function, _ line : Int = #line) -> UIBackgroundTaskIdentifier
    {
        let task = UIApplication.shared.beginBackgroundTask(withName: name)
        printDebug("Starting backgroundUploadTask \(name) : \(task)", file, function, line)
        return task
    }

    func endBackgroundTask(_ task : UIBackgroundTaskIdentifier, _ file : String = #file, _ function : String = #function, _ line : Int = #line)
    {
        printDebug("Ending the backgroundUploadTask \(task)", file, function, line)
        UIApplication.shared.endBackgroundTask(task)
    }
}
