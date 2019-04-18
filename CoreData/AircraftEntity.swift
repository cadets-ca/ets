//
//  AircraftEntity.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class AircraftEntity: NSManagedObject
{
    @NSManaged var beaconNumber: Int16
    @NSManaged var flightSequence: String
    @NSManaged var gliderOrTowplane: Int16
    @NSManaged var inTheAir: Bool
    @NSManaged var picTimeInAircraft: Int16
    @NSManaged var registration: String
    @NSManaged var sectionIndex: Int16
    @NSManaged var tailNumber: String
    @NSManaged var timeToNextInspection: NSDecimalNumber
    @NSManaged var connectedAircraft: Timesheets.AircraftEntity?
    @NSManaged var currentRecord: Timesheets.FlightRecord?
    @NSManaged var currentTimesheet: Timesheets.AircraftTimesheet?
    @NSManaged var glidingCentre: Timesheets.GlidingCentre?
    @NSManaged var maintenanceItems: Set<MaintenanceEvent>
    @NSManaged var passenger: Timesheets.Pilot?
    @NSManaged var pilot: Timesheets.Pilot?
    @NSManaged var timesheets: Set<AircraftTimesheet>
    @NSManaged var remoteChangeTime: Date
    @NSManaged var recordChangeTime: Date

    class var request: NSFetchRequest<AircraftEntity>
    {
        return self.fetchRequest() as! NSFetchRequest<AircraftEntity>
    }
    
    var registrationWithTailNumberInBrackets: String
    {
        return (registration == tailNumber) ? registration : "\(registration) (\(tailNumber))"
    }
    
    lazy var type: VehicleType = {return VehicleType(rawValue: Int(self.gliderOrTowplane))!}()
    var status: FlyingStatus {return inTheAir ? .flying : .landed}
    var hookupStatus: HookStatus {return connectedAircraft != nil ? .hooked : .unhooked}

    var TTNI: Decimal
    {
        get
        {
            return timeToNextInspection as Decimal
        }
        
        set (new)
        {
            timeToNextInspection = new as NSDecimalNumber
        }
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
        if managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadVehicleChanges(self)
        }
    }
    
    func checkConsistencyBasedOnChangesToRecord(_ record: FlightRecord)
    {
        let request = FlightRecord.request
        
        request.predicate = NSPredicate(format:"timeDown > %@ AND timeUp < %@ AND timesheet.aircraft == %@ AND recordID != %@", argumentArray: [record.timeUp, record.timeDown,self, record.recordID])
        let numberOfConflicts = try! managedObjectContext!.count(for: request)
        if numberOfConflicts > 0
        {
            let errorText = "There is a conflict- \(tailNumber) is now recorded as doing two flights at once!"
            let alert = UIAlertController(title:"Warning", message:errorText, preferredStyle:.alert)
            let cancel = UIAlertAction(title:"OK", style:.cancel, handler:nil)
            alert.addAction(cancel)
            UIViewController.presentOnTopmostViewController(alert)
        }
    }
    
    func updateTTSN()
    {
        if currentTimesheet == nil
        {
            dataModel.setCurrentTimesheetForAircraft(self, possibleContext:nil)
        }
        
        currentTimesheet!.updateTTSN()
    }
    
    func updateTTSNforAircraftVIACOLLECTIONOPERATORS()
    {
        if currentTimesheet == nil
        {
            dataModel.setCurrentTimesheetForAircraft(self, possibleContext:nil)
        }
        
        let totalMinutes = currentTimesheet!.flightRecords.reduce(0){$0 + $1.flightLengthInMinutes}
        
        let hourString = String(fromMinutes: Double(totalMinutes))
        let decimalString = hourString.decimalHoursValue
        let initialTTSNdecimal = currentTimesheet!.TTSNinitial
        let newTotal = initialTTSNdecimal + Decimal(string: decimalString)!
        currentTimesheet?.TTSNfinal = newTotal
    }
    
    func insertNewTimeSheetForAircraft(withContext context: NSManagedObjectContext = dataModel.managedObjectContext) -> AircraftTimesheet
    {
        let newTimesheet = AircraftTimesheet(context: context)
        newTimesheet.TTSNinitial = timesheets.count > 0 ? (currentTimesheet?.TTSNfinal ?? 0) : 0
        currentTimesheet = newTimesheet
        newTimesheet.aircraft = self
        newTimesheet.TTSNfinal = newTimesheet.TTSNinitial
        newTimesheet.currentAircraft = self
        return newTimesheet
    }
}

func < (left: AircraftEntity, right: AircraftEntity) -> Bool
{
    return left.tailNumber < right.tailNumber
}
