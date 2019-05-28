//
//  ChangePilotPopover.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-16.
//
//

import Foundation
import UIKit
import CoreData

final class ChangePilotPopover : UITableViewController
{
    var indexPathBeingEdited: IndexPath!
    var yesMeansRecord = false
    var aircraftBeingEdited: AircraftEntity!
    var flightRecord: FlightRecord!
    private var sectionHeaders = [String]()
    @IBOutlet var clearButton: UIBarButtonItem?
    private var fetchController: NSFetchedResultsController<AttendanceRecord>!
    
    //MARK: - Utility Methods
    @IBAction func clearPilot()
    {
        aircraftBeingEdited.pilot = nil
        dataModel.saveContext()
        
//        dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
        let _ = navigationController?.popViewController(animated: true)
    }
    
    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        if yesMeansRecord
        {
            navigationItem.rightBarButtonItem = nil
        }
        
        let vehicleType = yesMeansRecord ? flightRecord.timesheet.aircraft.type : aircraftBeingEdited.type
        let qualType = vehicleType == .glider ? #keyPath(AttendanceRecord.pilot.highestGliderQual) : #keyPath(AttendanceRecord.pilot.highestScoutQual)
        
        let request = AttendanceRecord.request
        if yesMeansRecord
        {
            let midnightOnTargetDate = flightRecord.timeUp.startOfDay
            let oneDayLater = midnightOnTargetDate + (60*60*24)
            let centre = dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre
            request.predicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND glidingCentre == %@ AND %K > 0", argumentArray: [midnightOnTargetDate, oneDayLater,centre!, qualType])
        }
            
        else
        {
            request.predicate = NSPredicate(format: "timeIn > %@ AND timeOut == %@ AND glidingCentre == %@ AND %K > 0", argumentArray: [Date().startOfDay, Date.distantFuture, dataModel.glidingCentre!, qualType])
        }
        
        let highestQualSortDescriptor = NSSortDescriptor(key: qualType, ascending: false)
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.name), ascending: true)
        request.sortDescriptors = [highestQualSortDescriptor, nameSortDescriptor]
        fetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: qualType, cacheName: nil)
        try! fetchController.performFetch()
        
        sectionHeaders = vehicleType == .glider ? ["None","Student","Basic Glider Pilot","Front Seat Famil","Rear seat Famil","Glider Instructor","Glider Check Pilot","Glider Standards Pilot"] : ["None", "Tow Pilot", "Tow Check Pilot", "Tow Standards Pilot"]
        
        if yesMeansRecord
        {
            clearButton?.isEnabled = false
        }
            
        else
        {
            if aircraftBeingEdited.status == .flying
            {
                clearButton?.isEnabled = false
            }
        }
        
        
        if fetchController.fetchedObjects?.count == 0
        {
            let messageText: String
            let title = vehicleType == .glider ? "No Glider Pilots" : "No Towplane Pilots"
            let path = vehicleType == .glider ? "'Glider Info' then 'Highest Qual'." : "'Tow Aircraft Info' then 'Highest Qual'."
            
            if regularFormat
            {
                messageText = "Tap 'Attendance' on the left then use the button in the top centre to add people or touch existing people to change their qualifications by navigating to \(path)"
            }
                
            else
            {
                messageText = "Tap the 'Pilots' tab then add people with the button at the top or touch existing people to change their qualifications by navigating to \(path)"
            }
            
            let noPilotError = UIAlertController(title: title, message: messageText, preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "OK", style: .default, handler: nil)
            noPilotError.addAction(cancelButton)
            present(noPilotError, animated:true, completion:nil)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableView Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let record = fetchController.object(at: indexPath)
        let pilot = record.pilot!
        
        if yesMeansRecord
        {
            let formerPilot = flightRecord.pilot
            flightRecord.timesheet.logChangesTo(record: flightRecord)
            flightRecord.pilot = pilot
            flightRecord.picParticipantType = pilot.typeOfParticipant
            NotificationCenter.default.post(name: recordsChangedNotification, object:pilot, userInfo:nil)
            pilot.checkConsistencyBasedOnChangesToRecord(flightRecord)
            
            if formerPilot !== pilot
            {
                NotificationCenter.default.post(name: recordsChangedNotification, object:formerPilot, userInfo:nil)
            }
            
            let _ = navigationController?.popViewController(animated: true)
        }
            
        else
        {
            if let aircraft = pilot.aircraft
            {
                if aircraft === aircraftBeingEdited
                {
                    if aircraft.passenger === pilot
                    {
                        let formerPilot = aircraft.pilot
                        aircraftBeingEdited.passenger = nil
                        aircraftBeingEdited.pilot = pilot
//                        dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
                        
                        if aircraftBeingEdited.status == .flying
                        {
                            aircraftBeingEdited.currentRecord?.pilot = pilot
                            aircraftBeingEdited.currentRecord?.picParticipantType = pilot.typeOfParticipant
                            aircraftBeingEdited.currentRecord?.passenger = nil
                            aircraftBeingEdited.currentRecord?.dualParticipantType = nil
                        }
                        
                        NotificationCenter.default.post(name: recordsChangedNotification, object:pilot, userInfo:nil)
                        NotificationCenter.default.post(name: recordsChangedNotification, object:formerPilot, userInfo:nil)
                    }
                    
                    let _ = navigationController?.popViewController(animated: true)
                }
                    
                else
                {
                    if aircraft.status == .flying
                    {
                        let errorMessage = "\(pilot.name) is already flying in \(aircraft.tailNumber)."
                        
                        let assignPilotError = UIAlertController(title: "Pilot Already Flying", message: errorMessage, preferredStyle: .alert)
                        
                        let cancelButton = UIAlertAction(title: "Cancel", style: .default){_ in let _ = self.navigationController?.popViewController(animated: true)}
                        
                        assignPilotError.addAction(cancelButton)
                        present(assignPilotError, animated:true, completion:nil)
                    }
                        
                    else
                    {
                        let errorMessage = "\(pilot.name) is already flying in \(aircraft.tailNumber). Should \(pilot.name) be switched to \(aircraftBeingEdited.tailNumber) or remain in \(aircraft.tailNumber)?"
                        
                        let assignPilotError = UIAlertController(title: "Pilot In Another Aircraft", message: errorMessage, preferredStyle: .alert)
                        let cancelButton = UIAlertAction(title: aircraft.tailNumber, style: .default){_ in let _ = self.navigationController?.popViewController(animated: true)}
                        
                        let continueButton = UIAlertAction(title: aircraftBeingEdited.tailNumber, style: .default){_ in
                            let formerPilot = self.aircraftBeingEdited.pilot
                            let record = self.fetchController.object(at: self.tableView.indexPathForSelectedRow!)
                            if record.pilot.aircraft?.passenger === record.pilot
                            {
                                record.pilot.aircraft?.passenger = nil
                            }
                        
                            else
                            {
                                record.pilot.aircraft?.pilot = nil
                            }
                        
                            self.aircraftBeingEdited.pilot = record.pilot
                        
                            if self.aircraftBeingEdited.status == .flying
                            {
                                self.aircraftBeingEdited.currentRecord?.pilot = record.pilot
                                self.aircraftBeingEdited.currentRecord?.picParticipantType = record.pilot.typeOfParticipant
                                NotificationCenter.default.post(name: flightRecordsChangedNotification, object:self.aircraftBeingEdited.currentRecord, userInfo:nil)
                            }
                        
                        NotificationCenter.default.post(name: recordsChangedNotification, object:formerPilot, userInfo:nil)
                        NotificationCenter.default.post(name: recordsChangedNotification, object:record.pilot, userInfo:nil)
                        
                        dataModel.saveContext()
                        let _ = self.navigationController?.popViewController(animated: true)
                        }
                        
                        assignPilotError.addAction(continueButton)
                        assignPilotError.addAction(cancelButton)
                        present(assignPilotError, animated:true, completion:nil)
                    }
                }
            }
                
            else
            {
                let formerPilot = aircraftBeingEdited?.pilot
                aircraftBeingEdited.pilot = pilot
                
                if aircraftBeingEdited.status == .flying
                {
                    aircraftBeingEdited.currentRecord?.pilot = pilot
                    aircraftBeingEdited.currentRecord?.picParticipantType = pilot.typeOfParticipant
                    NotificationCenter.default.post(name: flightRecordsChangedNotification, object:aircraftBeingEdited.currentRecord, userInfo:nil)
                }
                
                if let previousPilot = formerPilot
                {
                    NotificationCenter.default.post(name: recordsChangedNotification, object: previousPilot, userInfo:nil)
                }
//                dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
                let _ = navigationController?.popViewController(animated: true)
            }
        }
        
        dataModel.saveContext()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let sectionInfo = fetchController.sections?[section]
        return sectionInfo?.numberOfObjects ?? 0
    }
   
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let record = fetchController.object(at: indexPath)
        
        cell.textLabel?.text = record.pilot.fullName
        cell.accessoryType = .none
        cell.textLabel?.textColor = UIColor.black
        
        if let aircraft = record.pilot.aircraft
        {
            cell.textLabel?.textColor = aircraft.status == .flying ? UIColor.blue : UIColor.darkGreen()
        }
        
        cell.imageView?.image = record.pilot.photoThumbnailImage as? UIImage
        
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return fetchController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let sectionInfo = fetchController.sections![section]
        return sectionHeaders[Int(sectionInfo.name)!]
    }
}
