//
//  ChangePassengerPopover.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-18.
//
//

import Foundation
import UIKit
import CoreData

final class ChangePassengerPopover : UITableViewController
{
    var indexPathBeingEdited: IndexPath!
    var yesMeansRecord = false
    var aircraftBeingEdited: AircraftEntity!
    var flightRecord: FlightRecord!
    private var gliderFetchController: NSFetchedResultsController<AttendanceRecord>!
    private var towplaneFetchController: NSFetchedResultsController<AttendanceRecord>!
    private var gliderSectionHeaders = [String]()
    private var towplaneSectionHeaders = [String]()

    //MARK: - Utility Methods
    @IBAction func clearPassenger()
    {
        var formerPilot: Pilot?
        
        if !yesMeansRecord
        {
            formerPilot = aircraftBeingEdited.passenger
            aircraftBeingEdited.passenger = nil
            dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
            
            if aircraftBeingEdited.status == .flying
            {
                aircraftBeingEdited.currentRecord?.passenger = nil
                aircraftBeingEdited.currentRecord?.dualParticipantType = nil
            }
        }
            
        else
        {
            formerPilot = flightRecord.passenger
            flightRecord.timesheet.logChangesTo(record: flightRecord)
            flightRecord.passenger = nil
            flightRecord.dualParticipantType = nil
        }
        
        if formerPilot != nil
        {
            NotificationCenter.default.post(name: recordsChangedNotification, object:formerPilot, userInfo:nil)
            dataModel.saveContext()
            let _ = navigationController?.popViewController(animated: true)
        }
    }
    
    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let gliderPilotFetchRequest = AttendanceRecord.request
        let midnightOnTargetDate = yesMeansRecord ? flightRecord.timeUp.startOfDay : Date()
        let oneDayLater = midnightOnTargetDate + (60*60*24)
        
        if yesMeansRecord
        {
            let centre = dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre
            gliderPilotFetchRequest.predicate = NSPredicate(format: "timeIn >= %@ AND timeIn < %@ AND glidingCentre == %@ AND pilot.highestScoutQual == 0",midnightOnTargetDate as NSDate,oneDayLater as NSDate, centre!)
        }
            
        else
        {
            gliderPilotFetchRequest.predicate = NSPredicate(format: "timeIn >= %@ AND timeOut == %@ AND glidingCentre == %@ AND pilot.highestScoutQual == 0",Date().startOfDay  as NSDate, Date.distantFuture  as NSDate, dataModel.glidingCentre)
        }
        
        let highestGliderQualSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.highestGliderQual), ascending: false)
        let pilotNameSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.name), ascending: true)
        gliderPilotFetchRequest.sortDescriptors = [highestGliderQualSortDescriptor, pilotNameSortDescriptor]
        gliderFetchController = NSFetchedResultsController(fetchRequest: gliderPilotFetchRequest, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: #keyPath(AttendanceRecord.pilot.highestGliderQual), cacheName: nil)
        do {
            try gliderFetchController.performFetch()
        } catch _ {
        }
        
        let towPilotFetchRequest = AttendanceRecord.request
        
        if yesMeansRecord
        {
            towPilotFetchRequest.predicate = NSPredicate(format: "timeIn >= %@ AND timeIn < %@ AND glidingCentre == %@ AND pilot.highestScoutQual > 0", argumentArray: [midnightOnTargetDate, oneDayLater, dataModel.glidingCentre!])
        }
            
        else
        {
            towPilotFetchRequest.predicate = NSPredicate(format: "timeIn >= %@ AND timeOut == %@ AND glidingCentre == %@ AND pilot.highestScoutQual > 0", argumentArray: [Date().startOfDay, Date.distantFuture, dataModel.glidingCentre!])
        }
        
        let highestTowQualSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.highestScoutQual), ascending: false)
        towPilotFetchRequest.sortDescriptors = [highestTowQualSortDescriptor, pilotNameSortDescriptor]
        towplaneFetchController = NSFetchedResultsController(fetchRequest: towPilotFetchRequest, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: #keyPath(AttendanceRecord.pilot.highestScoutQual), cacheName: nil)
        do {
            try towplaneFetchController.performFetch()
        } catch _ {
        }
        
        gliderSectionHeaders = ["Level 4+ Cadet", "Level 3 Cadet", "Level 2 Cadet", "Level 1 Cadet", "Guest", "Student", "Basic Glider Pilot", "Front Seat Famil", "Rear seat Famil", "Glider Instructor", "Glider Check Pilot", "Glider Standards Pilot"]
        
        towplaneSectionHeaders = ["None", "Tow Pilot", "Tow Check Pilot", "Tow Standards Pilot"]
        
        if (gliderFetchController.fetchedObjects?.count == 0) && (towplaneFetchController.fetchedObjects?.count == 0)
        {
            let messageText: String
            
            if regularFormat
            {
                messageText = "There is nobody signed in. Tap 'Attendance' on the left then use the button in the top centre to add people."
            }
                
            else
            {
                messageText = "There is nobody signed in. Tap the 'Pilots' tab then add people with the button at the top."
            }
            
            let noPilotError = UIAlertController(title: "No Pilots", message: messageText, preferredStyle: .alert)
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
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return gliderFetchController.sections!.count + towplaneFetchController.sections!.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {        
        if section < gliderFetchController.sections!.count
        {
            let sectionInfo = gliderFetchController.sections?[section]
            return sectionInfo?.numberOfObjects ?? 0
        }
            
        else
        {
            let relativeSection = section - gliderFetchController.sections!.count
            let sectionInfo = towplaneFetchController.sections?[relativeSection]
            return sectionInfo?.numberOfObjects ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        if section < gliderFetchController.sections!.count
        {
            let sectionInfo = gliderFetchController.sections?[section]
            let indexOfTitle = (sectionInfo?.name.intValueWithNegatives ?? 0) + 4
            return gliderSectionHeaders[indexOfTitle]
        }
            
        else
        {
            let relativeSection = section - (gliderFetchController.sections?.count ?? 0)
            let sectionInfo = towplaneFetchController.sections?[relativeSection]
            let indexOfTitle = (sectionInfo?.name.intValueWithNegatives ?? 0)
            return towplaneSectionHeaders[indexOfTitle]
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let record: AttendanceRecord
        
        let section = (indexPath as NSIndexPath).section
        let row = (indexPath as NSIndexPath).row
        if section < gliderFetchController.sections!.count
        {
            record = gliderFetchController.object(at: indexPath) 
        }
            
        else
        {
            let relativeSection = section - gliderFetchController.sections!.count
            let path = IndexPath(row: row, section: relativeSection)
            record = towplaneFetchController.object(at: path) 
        }
        
        cell.textLabel?.text = record.pilot?.fullName
        cell.accessoryType = .none
        
        cell.textLabel?.textColor = UIColor.label
        
        if let aircraft = record.pilot?.aircraft
        {
            cell.textLabel?.textColor = aircraft.status == .flying ? UIColor.blue : UIColor.darkGreen()
        }
        
        let request = FlightRecord.request
        request.predicate = NSPredicate(format: "timeUp > %@ AND (pilot == %@ OR passenger = %@)", argumentArray: [Date().startOfDay, record.pilot!, record.pilot!])
        
        let flightsToday = try! dataModel.managedObjectContext.fetch(request) 
        cell.accessoryType = flightsToday.count < 1 ? .none : .checkmark
        cell.imageView?.image = record.pilot.photoThumbnailImage as? UIImage

        return cell
    }

    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let section = (indexPath as NSIndexPath).section
        let row = (indexPath as NSIndexPath).row
        let record: AttendanceRecord
        var formerPassenger: Pilot?
        
        if section < gliderFetchController.sections!.count
        {
            record = gliderFetchController.object(at: indexPath) 
        }
            
        else
        {
            let relativeSection = section - (gliderFetchController.sections?.count ?? 0)
            let path = IndexPath(row: row, section: relativeSection)
            record = towplaneFetchController.object(at: path) 
        }
        
        if yesMeansRecord
        {
            let passenger = record.pilot
            flightRecord.timesheet.logChangesTo(record: flightRecord)
            flightRecord.passenger = passenger
            flightRecord.dualParticipantType = passenger?.typeOfParticipant
            passenger?.checkConsistencyBasedOnChangesToRecord(flightRecord)
            let _ = navigationController?.popViewController(animated: true)
        }
            
        else
        {
            guard let passenger = record.pilot else {return}
            
            if let aircraft = passenger.aircraft
            {
                if aircraft === aircraftBeingEdited
                {
                    if (aircraft.pilot === passenger) && (aircraftBeingEdited.status == .landed)
                    {
                        aircraftBeingEdited.pilot = nil
                        aircraftBeingEdited.passenger = passenger
                        dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
                        let _ = navigationController?.popViewController(animated: true)
                    }
                        
                    else
                    {
                        if aircraftBeingEdited.status == .flying
                        {
                            let errorMessage = "\(passenger.name) is already flying in \(aircraft.tailNumber). Make sure you have the correct PIC before setting the passenger."
                            
                            let assignPilotError = UIAlertController(title: "Pilot Already Flying", message: errorMessage, preferredStyle: .alert)
                            
                            let cancelButton = UIAlertAction(title: "Cancel", style: .default){_ in
                                let _ = self.navigationController?.popViewController(animated: true)
                            }
                            
                            assignPilotError.addAction(cancelButton)
                            present(assignPilotError, animated:true, completion:nil)
                        }
                    }
                }
                    
                else
                {
                    if aircraft.status == .flying
                    {
                        let errorMessage = "\(passenger.name) is already flying in \(aircraft.tailNumber)."
                        let assignPilotError = UIAlertController(title: "Pilot Already Flying", message: errorMessage, preferredStyle: .alert)
                        
                        let cancelButton = UIAlertAction(title: "Cancel", style: .default){_ in
                            let _ = self.navigationController?.popViewController(animated: true)
                        }
                        
                        assignPilotError.addAction(cancelButton)
                        present(assignPilotError, animated:true, completion:nil)
                    }
                        
                    else
                    {
                        let errorMessage = "\(passenger.name) is already flying in \(aircraft.tailNumber). Should \(passenger.name) be switched to \(aircraftBeingEdited.tailNumber) or remain in \(aircraft.tailNumber)?"
                        
                        let assignPilotError = UIAlertController(title: "Pilot In Another Aircraft", message: errorMessage, preferredStyle: .alert)
                        
                        let cancelButton = UIAlertAction(title: passenger.aircraft!.tailNumber, style: .default){_ in
                            let _ = self.navigationController?.popViewController(animated: true)
                        }
                        
                        let continueButton = UIAlertAction(title: aircraftBeingEdited.tailNumber, style: .default){_ in
                            formerPassenger = self.aircraftBeingEdited.passenger
                            let section = (self.tableView.indexPathForSelectedRow! as NSIndexPath).section
                            let row = (self.tableView.indexPathForSelectedRow! as NSIndexPath).row
                            let record: AttendanceRecord
                            
                            if section < self.gliderFetchController.sections!.count
                            {
                                record = self.gliderFetchController.object(at: self.tableView.indexPathForSelectedRow!)
                            }
                                
                            else
                            {
                                let relativeSection = section - (self.gliderFetchController.sections?.count ?? 0)
                                let path = IndexPath(row: row, section: relativeSection)
                                record = self.towplaneFetchController.object(at: path) 
                            }
                            
                            if record.pilot.aircraft?.passenger === record.pilot
                            {
                                record.pilot.aircraft?.passenger = nil
                            }
                                
                            else
                            {
                                record.pilot.aircraft?.pilot = nil
                            }
                            
                            self.aircraftBeingEdited.passenger = record.pilot
                            
                            if self.aircraftBeingEdited.status == .flying
                            {
                                self.aircraftBeingEdited.currentRecord?.passenger = record.pilot
                                self.aircraftBeingEdited.currentRecord?.dualParticipantType = record.pilot!.typeOfParticipant
                                NotificationCenter.default.post(name: recordsChangedNotification, object:self.aircraftBeingEdited.currentRecord, userInfo:nil)
                            }
                            
                            NotificationCenter.default.post(name: recordsChangedNotification, object:formerPassenger, userInfo:nil)
                            NotificationCenter.default.post(name: recordsChangedNotification, object:record.pilot, userInfo:nil)
                            dataModel.saveContext()
                            
                            let _ = self.navigationController?.popViewController(animated: true)
                            return
                        }
                        assignPilotError.addAction(continueButton)
                        assignPilotError.addAction(cancelButton)
                        
                        present(assignPilotError, animated:true, completion:nil)
                    }
                }
            }
                
            else
            {
                aircraftBeingEdited.passenger = passenger
                
                if aircraftBeingEdited.status == .flying
                {
                    aircraftBeingEdited.currentRecord?.passenger = passenger
                    aircraftBeingEdited.currentRecord?.dualParticipantType = passenger.typeOfParticipant
                    NotificationCenter.default.post(name: flightRecordsChangedNotification, object:aircraftBeingEdited.currentRecord, userInfo:nil)
                }
                
                dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
                let _ = navigationController?.popViewController(animated: true)
            }
            
            NotificationCenter.default.post(name: recordsChangedNotification, object:formerPassenger, userInfo:nil)
        }
        dataModel.saveContext()
    }
}
