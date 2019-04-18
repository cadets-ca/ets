//
//  MaintenanceEvent.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class MaintenanceEvent: NSManagedObject, HasID, RecordsChanges, AttachedToAircraft
{
    @NSManaged var comment: String
    @NSManaged var date: Date
    @NSManaged var recordChangeTime: Date
    @NSManaged var recordID: Date
    @NSManaged var ttsn: NSNumber
    @NSManaged var aircraft: Timesheets.AircraftEntity!
    
    class var request: NSFetchRequest<MaintenanceEvent>
    {
        return self.fetchRequest() as! NSFetchRequest<MaintenanceEvent>
    }
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        recordChangeTime = Date()
        recordID = Date()
        comment = ""
    }
    
    override func willSave()
    {
        if shouldUpdateChangeTimes
        {
            let changeTime = Date()
            setPrimitiveValue(changeTime, forKey:"recordChangeTime")
        }
        super.willSave()
    }

    override func didSave()
    {
        if isDeleted == false, managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadMaintenanceChanges(self)
        }
    }
}
