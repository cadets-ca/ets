//
//  UserDefaults.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2017-06-21.
//
//

import Foundation
import CloudKit
import CoreData

public extension UserDefaults
{
    public var databaseChangeToken: CKServerChangeToken?
    {
        get {
            guard let data = self.value(forKey: "DatabaseChangeToken") as? Data else {
                return nil
            }
            
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue
            {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "DatabaseChangeToken")
            }
                
            else
            {
                self.removeObject(forKey: "DatabaseChangeToken")
            }
        }
    }
    
    public var zoneChangeToken: CKServerChangeToken?
    {
        get {
            guard let data = self.value(forKey: "ZoneChangeToken") as? Data else {
                return nil
            }
            
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue
            {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "ZoneChangeToken")
            }
                
            else
            {
                self.removeObject(forKey: "ZoneChangeToken")
            }
        }
    }
    
    public var sharedDatabaseChangeToken: CKServerChangeToken?
    {
        get {
            guard let data = self.value(forKey: "sharedDatabaseChangeToken") as? Data else {
                return nil
            }
            
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue
            {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "sharedDatabaseChangeToken")
            }
                
            else
            {
                self.removeObject(forKey: "sharedDatabaseChangeToken")
            }
        }
    }
    
    public var sharedZoneChangeToken: CKServerChangeToken?
    {
        get {
            guard let data = self.value(forKey: "sharedZoneChangeToken") as? Data else {
                return nil
            }
            
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue
            {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "sharedZoneChangeToken")
            }
                
            else
            {
                self.removeObject(forKey: "sharedZoneChangeToken")
            }
        }
    }
    
    public var createdCustomZone: Bool
    {
        get
        {
            guard let data = self.value(forKey: "createdCustomZone") as? Bool else {return false}
            return data
        }
        
        set
        {
            self.set(newValue, forKey: "createdCustomZone")
        }
    }
    
    public var subscribedToPrivateChanges: Bool
    {
        get
        {
            guard let data = self.value(forKey: "subscribedToPrivateChanges") as? Bool else {return false}
            return data
        }
        
        set
        {
            self.set(newValue, forKey: "subscribedToPrivateChanges")
        }
    }
    
    public var subscribedToSharedChanges: Bool
    {
        get
        {
            guard let data = self.value(forKey: "subscribedToSharedChanges") as? Bool else {return false}
            return data
        }
        
        set
        {
            self.set(newValue, forKey: "subscribedToSharedChanges")
        }
    }
    
    public var viewSharedDatabase: Bool
    {
        get
        {
            guard let data = self.value(forKey: "viewSharedDatabase") as? Bool else {return false}
            return data
        }
        
        set
        {
            self.set(newValue, forKey: "viewSharedDatabase")
        }
    }
    
    public var lastRunDate: Date
    {
        get
        {
            if let date = self.value(forKey: "lastRunDate") as? Date
            {
                return date
            }
            
            else
            {
                self.set(Date() as NSDate, forKey: "lastRunDate")
                return Date()
            }
        }
        
        set
        {
            self.set(newValue as NSDate, forKey: "lastRunDate")
        }
    }
    
    public var attendanceRecordsToBeDeleted: Set<String>?
    {
        get
        {
            var values = Set<String>()
            guard let storeValues = self.value(forKey: "attendanceRecordsDeleted") as? Array<String> else {return values}
            values = Set(storeValues)
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                self.set(Array(newSet), forKey: "attendanceRecordsDeleted")
            }
                
            else
            {
                self.removeObject(forKey: "attendanceRecordsDeleted")
            }
        }
    }
    
    public var flightRecordsToBeDeleted: Set<String>?
    {
        get
        {
            var values = Set<String>()
            guard let storeValues = self.value(forKey: "flightRecordsDeleted") as? Array<String> else {return values}
            values = Set(storeValues)
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                self.set(Array(newSet), forKey: "flightRecordsDeleted")
            }
                
            else
            {
                self.removeObject(forKey: "flightRecordsDeleted")
            }
        }
    }
    
    public var timesheetsToBeDeleted: Set<String>?
    {
        get
        {
            var values = Set<String>()
            guard let storeValues = self.value(forKey: "timesheetsDeleted") as? Array<String> else {return values}
            values = Set(storeValues)
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                self.set(Array(newSet), forKey: "timesheetsDeleted")
            }
                
            else
            {
                self.removeObject(forKey: "timesheetsDeleted")
            }
        }
    }
    
    public var commentsToBeDeleted: Set<String>?
    {
        get
        {
            var values = Set<String>()
            guard let storeValues = self.value(forKey: "commentsDeleted") as? Array<String> else {return values}
            values = Set(storeValues)
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                self.set(Array(newSet), forKey: "commentsDeleted")
            }
                
            else
            {
                self.removeObject(forKey: "commentsDeleted")
            }
        }
    }
    
    public var maintenanceIssuesToBeDeleted: Set<String>?
    {
        get
        {
            var values = Set<String>()
            guard let storeValues = self.value(forKey: "maintenanceIssuesDeleted") as? Array<String> else {return values}
            values = Set(storeValues)
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                self.set(Array(newSet), forKey: "maintenanceIssuesDeleted")
            }
                
            else
            {
                self.removeObject(forKey: "maintenanceIssuesDeleted")
            }
        }
    }
    
    public var pilotsToBeDeleted: Set<String>?
    {
        get
        {
            var values = Set<String>()
            guard let storeValues = self.value(forKey: "pilotsDeleted") as? Array<String> else {return values}
            values = Set(storeValues)
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                self.set(Array(newSet), forKey: "pilotsDeleted")
            }
                
            else
            {
                self.removeObject(forKey: "pilotsDeleted")
            }
        }
    }
    
    public var pilotsToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "pilotsToBeUploaded") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "pilotsToBeUploaded")
            }
                
            else
            {
                self.removeObject(forKey: "pilotsToBeUploaded")
            }
        }
    }
    
    public var attendanceRecordsToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "attendanceRecords") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "attendanceRecords")
            }
                
            else
            {
                self.removeObject(forKey: "attendanceRecords")
            }
        }
    }

    
    public var aircraftEntitiesToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "aircraftEntities") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "aircraftEntities")
            }
                
            else
            {
                self.removeObject(forKey: "aircraftEntities")
            }
        }
    }
    
    public var flightRecordsToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "flightRecords") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "flightRecords")
            }
                
            else
            {
                self.removeObject(forKey: "flightRecords")
            }
        }
    }
    
    public var timesheetsToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "timesheets") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "timesheets")
            }
                
            else
            {
                self.removeObject(forKey: "timesheets")
            }
        }
    }
    
    public var commentsToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "comments") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "comments")
            }
                
            else
            {
                self.removeObject(forKey: "comments")
            }
        }
    }

    public var maintenanceIssuesToBeUploaded: Set<NSManagedObjectID>?
    {
        get
        {
            var values = Set<NSManagedObjectID>()
            guard let URLstrings = self.value(forKey: "maintenance") as? Array<String> else {return values}
            
            for URLstring in URLstrings
            {
                if let ID = dataModel.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URL(string: URLstring)!)
                {
                    values.insert(ID)
                }
            }
            
            return values
        }
        
        set
        {
            if let newSet = newValue
            {
                var URLstrings = Array<String>()
                for NSManagedObjectID in newSet
                {
                    URLstrings.append(NSManagedObjectID.uriRepresentation().absoluteString)
                }
                
                self.set(Array(URLstrings), forKey: "maintenance")
            }
                
            else
            {
                self.removeObject(forKey: "maintenance")
            }
        }
    }
}
