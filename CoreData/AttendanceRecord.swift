//
//  AttendanceRecord.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class AttendanceRecord: NSManagedObject, RecordsChanges, AttachedToGlidingUnit, AttachedToPilot
{
    @NSManaged var dayOrSession: Bool
    @NSManaged var participantType: String
    @NSManaged var recordChangeTime: Date
    @NSManaged var recordID: Date
    @NSManaged var timeIn: Date
    @NSManaged var timeOut: Date
    @NSManaged var glidingCentre: Timesheets.GlidingCentre!
    @NSManaged var pilot: Timesheets.Pilot!

    class var request: NSFetchRequest<AttendanceRecord>
    {
        return self.fetchRequest() as! NSFetchRequest<AttendanceRecord>
    }
    
    lazy var sessionType: SessionTypes = {return self.dayOrSession == true ? .day : .session}()
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        recordChangeTime = Date()
        recordID = Date()
    }
    
    override func willSave()
    {
        if shouldUpdateChangeTimes
        {
            let changeTime = Date()
            setPrimitiveValue(changeTime, forKey:"recordChangeTime")
            pilot?.setPrimitiveValue(changeTime, forKey:"recordChangeTime")
        }
        
        super.willSave()
    }
    
    override func didSave()
    {
        if isDeleted == false, managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadAttendanceRecordChanges(self)
        }
    }
    
    func clearRelationships()
    {
        glidingCentre = nil
        pilot = nil
    }
        
    override var description: String
    {
        return "recordID:\(recordID) \r recordChangeTime \(recordChangeTime) \r pilotName \(pilot.uniqueName) \r timeIn \(timeIn) \r timeOut \(timeOut)"
    }
}
