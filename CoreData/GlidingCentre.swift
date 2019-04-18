//
//  GlidingCentre.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-21.
//
//

import Foundation
import UIKit
import CoreData

final class GlidingCentre: NSManagedObject
{
    @NSManaged var name: String
    @NSManaged var aircraft: Set<AircraftEntity>
    @NSManaged var attendaceRecords: Set<AttendanceRecord>
    @NSManaged var pilots: Set<Pilot>
    @NSManaged var timesheets: Set<AircraftTimesheet>
    @NSManaged var glidingDayComments: Set<GlidingDayComment>

    class var request: NSFetchRequest<GlidingCentre>
    {
        return self.fetchRequest() as! NSFetchRequest<GlidingCentre>
    }
    
    override var description: String
    {
        return "\(name) contains \(aircraft.count) aircraft, \(pilots.count) pilots, \(attendaceRecords.count) attendance records, \(timesheets.count) timesheets, and \(glidingDayComments.count) gliding day comments."
    }
    
    override var debugDescription: String
    {
        return description
    }
}
