//
//  AircraftTimesheet.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-23.
//
//

import Foundation
import UIKit
import CoreData

final class AircraftTimesheet: NSManagedObject, HasID, RecordsChanges, AttachedToGlidingUnit, AttachedToAircraft
{
    @NSManaged var date: Date
    @NSManaged var finalTTSN: NSDecimalNumber
    @NSManaged var initialTTSN: NSDecimalNumber
    @NSManaged var history: String
    @NSManaged var recordChangeTime: Date
    @NSManaged var recordID: Date
    @NSManaged var winchFinalTTSNsetCorrectly: Bool
    @NSManaged var aircraft: Timesheets.AircraftEntity!
    @NSManaged var currentAircraft: Timesheets.AircraftEntity?
    @NSManaged var glidingCentre: Timesheets.GlidingCentre!
    @NSManaged var flightRecords: Set<FlightRecord>

    class var request: NSFetchRequest<AircraftTimesheet>
    {
        return self.fetchRequest() as! NSFetchRequest<AircraftTimesheet>
    }
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        recordChangeTime = Date()
        recordID = Date()
        
        if managedObjectContext == dataModel.managedObjectContext
        {
            glidingCentre = dataModel.glidingCentre
        }
        
        initialTTSN = NSDecimalNumber(value: 0)
        finalTTSN = NSDecimalNumber(value: 0)
        date = Date()
        winchFinalTTSNsetCorrectly = false
    }
        
    override func didSave()
    {
        if isDeleted == false, managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadTimesheetChanges(self)
        }
    }
    
    var TTSNinitial: Decimal
        {
        get
        {
            return initialTTSN as Decimal
        }
        
        set (new)
        {
            initialTTSN = new as NSDecimalNumber
        }
    }
    
    var TTSNfinal: Decimal
        {
        get
        {
            return finalTTSN as Decimal
        }
        
        set (new)
        {
            finalTTSN = new as NSDecimalNumber
        }
    }
    
    func clearRelationships()
    {
        glidingCentre = nil
        aircraft = nil
        currentAircraft = nil
        flightRecords.removeAll(keepingCapacity: false)
    }
    
    func logChangesTo(record: FlightRecord)
    {
        guard record.recordID < Date().midnight, record.recordChangeTime < Date() - 60*30 else{return}
//        guard record.timeUp < Date().midnight else{return}

        let separator = "*****"
        var changeLog = record.recordID.hoursAndMinutes + separator
        changeLog += Date().militaryFormatWithMinutes + separator
        changeLog += dataModel.editorName + separator
        changeLog += dataModel.editorLicense + separator
        changeLog += "Record modified. Original state: PIC- \(record.pilot.fullName), Passenger- \(record.passenger?.fullName ?? "None"), Time Up \(record.timeUp.militaryFormatWithMinutes), Time Down \(record.timeDown.militaryFormatWithMinutes)" + separator
        history += changeLog
    }
    
    func logInsertionOf(record: FlightRecord)
    {
        let separator = "*****"
        var changeLog = record.recordID.hoursAndMinutes + separator
        changeLog += Date().militaryFormatWithMinutes + separator
        changeLog += dataModel.editorName + separator
        changeLog += dataModel.editorLicense + separator
        changeLog += "Record inserted." + separator
        history += changeLog
    }
    
    func logDeletionOf(record: FlightRecord)
    {
        guard record.recordID < Date().midnight else{return}
        let separator = "*****"
        var changeLog = record.recordID.hoursAndMinutes + separator
        changeLog += Date().militaryFormatWithMinutes + separator
        changeLog += dataModel.editorName + separator
        changeLog += dataModel.editorLicense + separator
        changeLog += "Record deleted. Original state: PIC- \(record.pilot.fullName), Passenger- \(record.passenger?.fullName ?? "None"), Time Up \(record.timeUp.militaryFormatWithMinutes), Time Down \(record.timeDown.militaryFormatWithMinutes)" + separator
        history += changeLog
    }
    
    /// Sets the finalTTSN property to be the initial TTSN plus the sum of the flight lengths. Does nothing for ground based launchers.
    func updateTTSN()
    {
        if aircraft.type.isAircraft()
        {
            var totalMinutes = Int16(0)
            
            for record in flightRecords
            {
                totalMinutes += record.flightLengthInMinutes
            }
            
            let hourString = String(fromMinutes: Double(totalMinutes))
            let decimalString = hourString.decimalHoursValue
            let initialTTSNdecimal = TTSNinitial
            let newTotal = initialTTSNdecimal + (Decimal(string: decimalString) ?? 0)
            finalTTSN = newTotal as NSDecimalNumber
        }
    }
    
    /// Sets the initialTTSN property to be the finalTTSN of the preceeding entry.
    func setTTSN()
    {
        let fetchRequest = AircraftTimesheet.request 
        fetchRequest.predicate = NSPredicate(format: "%K = %@ AND %K < %@", argumentArray: [#keyPath(AircraftTimesheet.aircraft), aircraft, #keyPath(AircraftTimesheet.date), date])
        let sortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchBatchSize = 1
        
        let results = try? dataModel.managedObjectContext.fetch(fetchRequest)
        
        if let priorTimesheet = results?.first
        {
            initialTTSN = priorTimesheet.finalTTSN
            
            if priorTimesheet.date.startOfDay == date.startOfDay
            {
                date = priorTimesheet.date + 1
            }
            
            else
            {
                date = date - 1000
            }
        }
            
        else
        {
            initialTTSN = 0
            date = date - 1000
        }
        
        updateTTSN()
    }
    
    override var description: String
    {
        return "recordID:\(recordID) \r recordChangeTime \(recordChangeTime)"
    }
}
