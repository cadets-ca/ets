//
//  ChangeOperator.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-18.
//
//

import Foundation
import UIKit
import CoreData

final class ChangeOperator : UITableViewController
{
    var indexPathBeingEdited: IndexPath!
    var yesMeansRecord = false
    var aircraftBeingEdited: AircraftEntity!
    var flightRecord: FlightRecord!

    @IBOutlet var clearButton: UIBarButtonItem?
    private var winchOperators = [AttendanceRecord]()

    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if yesMeansRecord
        {
            self.navigationItem.rightBarButtonItem = nil
        }
        
        let vehicleType = yesMeansRecord ? flightRecord.timesheet.aircraft.type : aircraftBeingEdited.type
        
        if vehicleType == .auto
        {
            title = "Driver"
        }
        
        let nameOfQual = vehicleType == .winch ? "Winch Operator" : "Auto Tow Driver"
        let qualRequest = Qualification.request
        qualRequest.predicate = NSPredicate(format: "nameOfQualification == %@",nameOfQual)
        let qualResults = try! dataModel.managedObjectContext.fetch(qualRequest)
        
        let winchOperator = qualResults.first
        
        let pilotRequest = AttendanceRecord.request
        
        if yesMeansRecord
        {
            let midnightOnTargetDate = flightRecord.timeUp.startOfDay
            let oneDayLater = midnightOnTargetDate + (60*60*24)
            let centre = dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre
            pilotRequest.predicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND glidingCentre == %@", argumentArray: [midnightOnTargetDate, oneDayLater, centre!])
        }
            
        else
        {
            pilotRequest.predicate = NSPredicate(format: "timeIn > %@ AND timeOut == %@ AND glidingCentre == %@", argumentArray: [Date().startOfDay, Date.distantFuture, dataModel.glidingCentre])
        }
        
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.name), ascending: true)
        pilotRequest.sortDescriptors = [nameSortDescriptor]
        let pilotResults = try! dataModel.managedObjectContext.fetch(pilotRequest)
        
        if let qual = winchOperator
        {
            for record in pilotResults
            {
                if record.pilot.qualifications.contains(qual)
                {
                    winchOperators.append(record)
                }
            }
        }
        
        if !yesMeansRecord
        {
            if aircraftBeingEdited.status == .flying
            {
                clearButton?.isEnabled = false
            }
        }
            
        else
        {
            clearButton?.isEnabled = false
        }
        
        if winchOperators.count == 0
        {
            var messageText = ""
            var errorTitle = ""
            
            if vehicleType == .winch
            {
                if regularFormat
                {
                    messageText += "Tap 'Attendance' on the left then add people via the button in the top centre or touch existing staff to change their qualifications to 'Winch Launch Operator' under 'Other Qualifications'."
                }
                    
                else
                {
                    messageText += "Tap the 'Pilots' tab then add people via the button at the top or touch existing people to change their qualifications to 'Winch Launch Operator' under 'Other Qualifications'."
                }
                
                errorTitle = "No Operators Signed In"
            }
                
            else
            {
                if regularFormat
                {
                    messageText += "Tap 'Attendance' on the left then add people via the button in the top centre or touch existing staff to change their qualifications to 'Auto Tow Driver' under 'Other Qualifications'."
                }
                    
                else
                {
                    messageText += "Tap the 'Pilots' tab then add people via the button at the top or touch existing people to change their qualifications to 'Auto Tow Driver' under 'Other Qualifications'."
                }
                
                errorTitle = "No Drivers Signed In"
            }
            
            let noOperatorError = UIAlertController(title: errorTitle, message: messageText, preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "OK", style: .default, handler: nil)
            noOperatorError.addAction(cancelButton)
            self.present(noOperatorError, animated:true, completion:nil)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableView Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let record = winchOperators[(indexPath as NSIndexPath).row]
        let pilot = record.pilot!
        
        if yesMeansRecord
        {
            flightRecord.pilot = pilot
            let _ = navigationController?.popViewController(animated: true)
        }
            
        else
        {
            if let aircraft = pilot.aircraft
            {
                if pilot.aircraft === aircraftBeingEdited
                {
                    if aircraft.passenger === pilot
                    {
                        aircraftBeingEdited.passenger = nil
                        aircraftBeingEdited.pilot = pilot
                        dataModel.saveContext()
                        dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
                    }
                    
                    let _ = navigationController?.popViewController(animated: true)
                }
                    
                else
                {
                    if aircraft.status == .flying
                    {
                        let errorMessage = "\(pilot.name) is already in \(aircraft.tailNumber)."
                        let assignPilotError = UIAlertController(title: "Pilot Already Flying", message: errorMessage, preferredStyle: .alert)
                        
                        let cancelButton = UIAlertAction(title: "Cancel", style: .default){_ in
                            let _ = self.navigationController?.popViewController(animated: true)
                            return
                        }
                        
                        assignPilotError.addAction(cancelButton)
                        present(assignPilotError, animated:true, completion:nil)
                    }
                        
                    else
                    {
                        let errorMessage = "\(pilot.name) is already in \(aircraft.tailNumber). Should \(pilot.name) be switched to \(aircraftBeingEdited.tailNumber) or remain in \(aircraft.tailNumber)?"
                        
                        let assignPilotError = UIAlertController(title: "Operator In Another Aircraft", message: errorMessage, preferredStyle: .alert)
                        
                        let cancelButton = UIAlertAction(title: aircraft.tailNumber, style: .default){_ in
                            let _ = self.navigationController?.popViewController(animated: true)
                            return
                        }
                        
                        let continueButton = UIAlertAction(title: aircraftBeingEdited.tailNumber, style: .default){_ in
                            let record = self.winchOperators[(self.tableView.indexPathForSelectedRow! as NSIndexPath).row]
                            if aircraft.passenger === record.pilot
                            {
                                record.pilot?.aircraft?.passenger = nil
                            }
                            
                            else
                            {
                                record.pilot?.aircraft?.pilot = nil
                            }
                            
                            self.aircraftBeingEdited.pilot = record.pilot
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
                aircraftBeingEdited.pilot = pilot
                
                if aircraftBeingEdited.status == .flying
                {
                    aircraftBeingEdited.currentRecord?.pilot = pilot
                    NotificationCenter.default.post(name: flightRecordsChangedNotification, object:aircraftBeingEdited.currentRecord, userInfo:nil)
                }
                
                dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
                let _ = navigationController?.popViewController(animated: true)
            }
        }
        
        dataModel.saveContext()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return winchOperators.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let record = winchOperators[(indexPath as NSIndexPath).row]
        
        cell.textLabel?.text = record.pilot?.fullName
        cell.accessoryType = .none
        
        cell.textLabel?.textColor = UIColor.black
        
        if let aircraft = record.pilot.aircraft
        {
            cell.textLabel?.textColor = aircraft.status == .flying ? UIColor.blue : UIColor.darkGreen()
        }
        
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    //MARK: - Utility Methods     
    @IBAction func clearPilot()
    {
        aircraftBeingEdited.pilot = nil
        dataModel.saveContext()
        
        dataModel.reloadAircraftAtIndexPath(indexPathBeingEdited)
        let _ = navigationController?.popViewController(animated: true)
    }
}
