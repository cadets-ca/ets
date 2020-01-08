//
//  CloudKitControllerTV.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-15.
//

import Foundation
import CloudKit

prefix operator ~>

prefix func ~> (closure: @escaping () -> ())
{
    mainQueue.async(execute: closure)
}

enum VehicleType: Int, Comparable
{
    case glider = 1, towplane = 0, winch = -1, auto = -2
    
    func isAircraft() -> Bool
    {
        return self.rawValue >= 0 ? true : false
    }
}

func == (left: VehicleType, right: VehicleType) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: VehicleType, right: VehicleType) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

let newDataNotification = Notification.Name("dataChanged")
let noDataNotification = Notification.Name("noData")

final class CloudKitControllerTV
{
    var recordsSortedBySite = [(siteName: String, gliderRecords: [CKRecord], launcherRecords: [CKRecord])]()
    var allRecordsToday = Set<CKRecord>()
    var allRecordsThisSeason = Set<CKRecord>()
    var allGliderStaffRecords = Set<CKRecord>()
    var allTowStaffRecords = Set<CKRecord>()
    var modifiedRecords = Set<CKRecord>()
    let container = CKContainer(identifier: "iCloud.ca.cadets.Timesheets")
    var lastUpdate = Date.distantPast
    var selectedDatabase: String {
        return UserDefaults.standard.string(forKey: "Database") ?? "Your Database"
    }
    var initialFetchInProgress = false
    
    func performInitialFetch()
    {
        if initialFetchInProgress
        {
            return
        }
        
        initialFetchInProgress = true
        allRecordsToday.removeAll()
        allRecordsThisSeason.removeAll()
        let database = selectedDatabase == "Shared Database" ? container.sharedCloudDatabase : container.privateCloudDatabase
        
//        let timePeriodStart = Date() + TIME_PERIOD_FOR_FUN_STATS + 60*60*24*50
//        let displayDate = Date().startOfDay
//        let timePeriodEnd = Date.distantFuture
        
        let displayDate = (Date() - 246*24*60*60).startOfDay
        print("The display date is \(displayDate.militaryFormatShort)")
        let timePeriodStart = displayDate
        let timePeriodEnd = timePeriodStart + 24*60*60
        
        let endDisplayDate = displayDate + 60*60*24
        let predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@", argumentArray: [timePeriodStart, timePeriodEnd])

        let query = CKQuery(recordType: "FlightRecord", predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)

        database.fetchAllRecordZones { zones, error in
            if let err = error
            {
                print("Error fetting shared record zones: \(err)")
                return
            }
            
            guard let recordZones = zones else
            {
                print("no error getting shared zones, but no zones returned")
                return
            }
            
            guard let zone = recordZones.first else {return}
            
            let zoneID = zone.zoneID
            queryOperation.zoneID = zoneID
            
            queryOperation.recordFetchedBlock = {(record) in
                ~>{self.allRecordsThisSeason.insert(record)}
                
                if let upTime = record["timeUp"] as? Date, upTime > displayDate, upTime < endDisplayDate
                {
                    ~>{self.allRecordsToday.insert(record)}
                }
            }
            
            queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryCursor?, error: Error?) in
                if let cursor = cursor
                {
                    let newQueryOperation = CKQueryOperation(cursor: cursor)
                    newQueryOperation.zoneID = zoneID
                    
                    newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                    newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                    queryOperation = newQueryOperation
                    database.add(newQueryOperation)
                }
                    
                else
                {
                    ~>{
                        self!.recordsSortedBySite = self!.sortRecordsBySite(records: self!.allRecordsToday)
                        self!.initialFetchInProgress = false
                        print("Initial fetch done")
                        NotificationCenter.default.post(name: newDataNotification, object:self, userInfo:nil)
                    }
                }
                
                if let error = error
                {print("Error during performInitialFetch query", error)}
            }
            
            database.add(queryOperation)
        }
    }
    
    func performSubsequentFetch()
    {
        if initialFetchInProgress
        {
            return
        }
        
        modifiedRecords.removeAll()

        let database = selectedDatabase == "Shared Database" ? container.sharedCloudDatabase : container.privateCloudDatabase
        let startTime: Date
        
        if Date() - lastUpdate > 3600
        {
            lastUpdate = Date()
            performInitialFetch()
            return
        }
        
        else
        {
            startTime = lastUpdate
        }
        
        let predicate = NSPredicate(format: "recordChangeTime > %@", argumentArray: [startTime])
        let query = CKQuery(recordType: "FlightRecord", predicate: predicate)
        var queryOperation = CKQueryOperation(query: query)
        
        database.fetchAllRecordZones { zones, error in
            if let err = error
            {
                print("Error fetting shared record zones: \(err)")
                return
            }
            
            guard let recordZones = zones else
            {
                print("no error getting shared zones, but no zones returned")
                return
            }
            
            guard let zone = recordZones.first else {return}
            
            let zoneID = zone.zoneID
            queryOperation.zoneID = zoneID
            
            queryOperation.recordFetchedBlock = {(record) in
                ~>{self.modifiedRecords.insert(record)}
            }
            
            queryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryCursor?, error: Error?) in
                if let cursor = cursor
                {
                    let newQueryOperation = CKQueryOperation(cursor: cursor)
                    newQueryOperation.zoneID = zoneID
                    
                    newQueryOperation.recordFetchedBlock = queryOperation.recordFetchedBlock
                    newQueryOperation.queryCompletionBlock = queryOperation.queryCompletionBlock
                    queryOperation = newQueryOperation
                    database.add(newQueryOperation)
                }
                    
                else
                {
                    ~>{
                        self!.mergeChangedRecords()
                        self!.recordsSortedBySite = self!.sortRecordsBySite(records: self!.allRecordsToday)
                        NotificationCenter.default.post(name: newDataNotification, object:self, userInfo:nil)
                    }
                }
                
                if let error = error
                {print("Error during performSubsequentFetch query", error)}
            }
            
            database.add(queryOperation)
        }
    }
    
    func mergeChangedRecords()
    {
        for record in modifiedRecords
        {
            var foundRecord: CKRecord? = nil
            
            for priorRecord in allRecordsToday
            {
                if record.recordID == priorRecord.recordID
                {
                    foundRecord = priorRecord
                    break
                }
            }
            
            if let foundRecord = foundRecord
            {
                allRecordsToday.remove(foundRecord)
                allRecordsToday.insert(record)
                allRecordsThisSeason.remove(foundRecord)
                allRecordsThisSeason.insert(record)
            }
            
            else
            {
                allRecordsToday.insert(record)
                allRecordsThisSeason.insert(record)
            }
        }
    }

    
    func processChangesToRecord(withID ID: CKRecordID)
    {
        let database = selectedDatabase == "Shared Database" ? container.sharedCloudDatabase : container.privateCloudDatabase
        database.fetch(withRecordID: ID)
        {(record, error) in
            ~>{
                if let record = record
                {
                    for oldRecord in self.allRecordsToday
                    {
                        if oldRecord.recordID == record.recordID
                        {
                            self.allRecordsToday.remove(oldRecord)
                            break
                        }
                    }
                    
                    self.allRecordsToday.insert(record)
                    self.recordsSortedBySite = self.sortRecordsBySite(records: self.allRecordsToday)
                    NotificationCenter.default.post(name: newDataNotification, object:self, userInfo:nil)
                }
            }
        }
    }
    
    func processDeletionOfRecord(withID ID: CKRecordID)
    {
        for oldRecord in self.allRecordsToday
        {
            if oldRecord.recordID.recordName == ID.recordName
            {
                self.allRecordsToday.remove(oldRecord)
                self.recordsSortedBySite = self.sortRecordsBySite(records: self.allRecordsToday)
                NotificationCenter.default.post(name: newDataNotification, object:self, userInfo:nil)
                break
            }
        }
    }
    
    func sortRecordsBySite(records: Set<CKRecord>) -> [(siteName: String, gliderRecords: [CKRecord], launcherRecords: [CKRecord])]
    {
        print("There are \(records.count) records")
        
        if allRecordsThisSeason.count == 0
        {
            NotificationCenter.default.post(name: noDataNotification, object:self, userInfo:nil)
        }
        
        var sortedRecords = [String: (gliderRecords: [CKRecord], launcherRecords: [CKRecord])]()
        
        for record in records
        {
            guard let glidingSite = record["glidingCenter"] as? String else{print("missing gc"); continue}
            
            var recordsForSite = sortedRecords[glidingSite] ?? (gliderRecords: [CKRecord](), launcherRecords: [CKRecord]())
            
            if let type = VehicleType(rawValue: record["gliderOrTowplane"] as! Int), type == .glider
            {
                var gliderFlights = recordsForSite.gliderRecords
                gliderFlights.append(record)
                recordsForSite.gliderRecords = gliderFlights
            }
            
            else
            {
                var nonGliderFlights = recordsForSite.launcherRecords
                nonGliderFlights.append(record)
                recordsForSite.launcherRecords = nonGliderFlights
            }
            
            sortedRecords[glidingSite] = recordsForSite
        }
        
        var returnArray = [(siteName: String, gliderRecords: [CKRecord], launcherRecords: [CKRecord])]()
        
        for (key, values) in sortedRecords
        {
            returnArray.append((key, values.gliderRecords, values.launcherRecords))
        }
        
        returnArray.sort(by: {$0.gliderRecords.count > $1.gliderRecords.count})
    
        return returnArray
    }

    func performInitialStaffFetch()
    {
        initialFetchInProgress = true
        allGliderStaffRecords.removeAll()
        allTowStaffRecords.removeAll()

        let database = selectedDatabase == "Shared Database" ? container.sharedCloudDatabase : container.privateCloudDatabase
        let gliderPilotPredicate = NSPredicate(format: "highestGliderQual > %d AND inactive == NO", argumentArray: [0])
        let towPilotPredicate = NSPredicate(format: "highestScoutQual > %d AND inactive == NO", argumentArray: [0])
        let gliderPilotQuery = CKQuery(recordType: "Pilot", predicate: gliderPilotPredicate)
        let towPilotQuery = CKQuery(recordType: "Pilot", predicate: towPilotPredicate)
        var gliderPilotQueryOperation = CKQueryOperation(query: gliderPilotQuery)
        var towPilotQueryOperation = CKQueryOperation(query: towPilotQuery)

        database.fetchAllRecordZones { zones, error in
            if let err = error
            {
                print("Error fetting shared record zones: \(err)")
                return
            }
            
            guard let recordZones = zones else
            {
                print("no error getting shared zones, but no zones returned")
                return
            }
            
            guard let zone = recordZones.first else {return}
            
            let zoneID = zone.zoneID
            gliderPilotQueryOperation.zoneID = zoneID
            towPilotQueryOperation.zoneID = zoneID
            
            gliderPilotQueryOperation.recordFetchedBlock = {(record) in
                ~>{self.allGliderStaffRecords.insert(record)}
            }
            
            towPilotQueryOperation.recordFetchedBlock = {(record) in
                ~>{self.allTowStaffRecords.insert(record)}
            }
            
            gliderPilotQueryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryCursor?, error: Error?) in
                if let cursor = cursor
                {
                    let newQueryOperation = CKQueryOperation(cursor: cursor)
                    newQueryOperation.zoneID = zoneID
                    
                    newQueryOperation.recordFetchedBlock = gliderPilotQueryOperation.recordFetchedBlock
                    newQueryOperation.queryCompletionBlock = gliderPilotQueryOperation.queryCompletionBlock
                    gliderPilotQueryOperation = newQueryOperation
                    database.add(newQueryOperation)
                }
                    
                else
                {
                    ~>{
                        print("Glider staff fetch done")
                        NotificationCenter.default.post(name: newDataNotification, object:self, userInfo:nil)
                    }
                }
                
                if let error = error
                {print("Error during staff query", error)}
            }
            
            towPilotQueryOperation.queryCompletionBlock = {[weak self](cursor: CKQueryCursor?, error: Error?) in
                if let cursor = cursor
                {
                    let newQueryOperation = CKQueryOperation(cursor: cursor)
                    newQueryOperation.zoneID = zoneID
                    
                    newQueryOperation.recordFetchedBlock = towPilotQueryOperation.recordFetchedBlock
                    newQueryOperation.queryCompletionBlock = towPilotQueryOperation.queryCompletionBlock
                    towPilotQueryOperation = newQueryOperation
                    database.add(newQueryOperation)
                }
                    
                else
                {
                    ~>{
                        print("Tow Staff fetch done")
                        NotificationCenter.default.post(name: newDataNotification, object:self, userInfo:nil)
                    }
                }
                
                if let error = error
                {print("Error during staff query", error)}
            }
            
            database.add(gliderPilotQueryOperation)
            database.add(towPilotQueryOperation)
        }
    }


}
