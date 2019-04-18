//
//  FlightRecord.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-23.
//
//

import Foundation
import UIKit
import CoreData

final class FlightRecord: NSManagedObject, RecordsChanges, HasID, AttachedToPilot, AttachedToPassenger, AttachedToTimesheet
{
    @NSManaged var dualParticipantType: String?
    @NSManaged var flightLengthInMinutes: Int16
    @NSManaged var flightSequence: String
    @NSManaged var picParticipantType: String
    @NSManaged var recordChangeTime: Date
    @NSManaged var recordID: Date
    @NSManaged var timeDown: Date
    @NSManaged var timeUp: Date
    @NSManaged var transitRoute: String
    @NSManaged var passenger: Timesheets.Pilot?
    @NSManaged var pilot: Timesheets.Pilot!
    @NSManaged var aircraft: Timesheets.AircraftEntity!
    @NSManaged var timesheet: Timesheets.AircraftTimesheet!
    @NSManaged var connectedAircraftRecord: Timesheets.FlightRecord?

    class var request: NSFetchRequest<FlightRecord>
    {
        return self.fetchRequest() as! NSFetchRequest<FlightRecord>
    }

    @objc var sectionTitleWhenSortedByPassenger: String
    {
        return self.passenger?.fullName ?? "Solo"
    }
    
    @objc var sectionTitleWhenSortedByConnectedAircraft: String
    {
        return connectedAircraftRecord?.timesheet?.aircraft?.tailNumber ?? "Tow Training"
    }
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        recordChangeTime = Date()
        recordID = Date()
        transitRoute = ""
    }
    
    override func willSave()
    {
        if shouldUpdateChangeTimes
        {
            let changeTime = Date()
            setPrimitiveValue(changeTime, forKey:"recordChangeTime")
            timesheet?.setPrimitiveValue(changeTime, forKey:"recordChangeTime")
            
            if let connectedRecord = connectedAircraftRecord
            {
                connectedRecord.setPrimitiveValue(changeTime, forKey:"recordChangeTime")
                connectedRecord.timesheet.setPrimitiveValue(changeTime, forKey:"recordChangeTime")
            }
        }
        
        super.willSave()
    }
    
    override func didSave()
    {
        if isDeleted == false, managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadFlightRecordChanges(self)
        }
    }
    
    func clearRelationships()
    {
        aircraft = nil
        connectedAircraftRecord = nil
        passenger = nil
        pilot = nil
        timesheet = nil
    }
    
    override var description: String
    {
        return "aircraft:\(aircraft?.tailNumber ?? "Missing Aircraft") \r timeUp \(timeUp) \r timeDown \(timeDown) \r pilot \(pilot?.fullName ?? "no pilot") \r passenger \(passenger?.name ?? "no pax") \r length \(flightLengthInMinutes)"
    }
    
    override var debugDescription: String
    {
        return description
    }
}
