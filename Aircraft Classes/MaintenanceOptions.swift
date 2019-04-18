//
//  MaintenanceOptions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-06.
//
//

import Foundation
import UIKit
import CoreData

final class MaintenanceOptions: UITableViewController
{
    var aircraftBeingEdited: AircraftEntity!
    @IBOutlet var TTSN: UITableViewCell!
    @IBOutlet var TNI: UITableViewCell!
    @IBOutlet var TTNI: UITableViewCell!
    @IBOutlet var newTimesheet: UITableViewCell!

    enum SegueIdentifiers: String
    {
        case TTSNSegue = "TTSNSegue"
        case TNISegue = "TNISegue"
        case TTNISegue = "TTNISegue"
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        TNI.textLabel?.text = dataModel.aircraftAreaController?.calculateTNIforAircraft(aircraftBeingEdited).stringWithDecimal
        var timesheet: AircraftTimesheet?
        let numberOfTimesheetsForAircraft = aircraftBeingEdited.timesheets.count 
        
        if numberOfTimesheetsForAircraft > 0
        {
            timesheet = aircraftBeingEdited.currentTimesheet
            
            if timesheet == nil
            {
                dataModel.setCurrentTimesheetForAircraft(aircraftBeingEdited, possibleContext:nil)
                timesheet = aircraftBeingEdited.currentTimesheet
            }
        }
            
        else
        {
            timesheet = AircraftTimesheet(context: dataModel.managedObjectContext)
            timesheet?.glidingCentre = dataModel.glidingCentre
            timesheet?.aircraft = aircraftBeingEdited
            timesheet?.currentAircraft = aircraftBeingEdited
            timesheet?.TTSNinitial = 0
            timesheet?.TTSNfinal = 0
            timesheet?.date = Date()
        }
        
        TTSN.textLabel?.text = timesheet?.TTSNfinal.stringWithDecimal
        TTNI.textLabel?.text = aircraftBeingEdited.TTNI.stringWithDecimal
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        let TNIPicker = segue.destination as? TNIPickerView
        TNIPicker?.aircraftBeingEdited = aircraftBeingEdited
        
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .TTSNSegue:
            TNIPicker?.mode = .ttsn

        case .TNISegue:
            TNIPicker?.mode = .tni

        case .TTNISegue:
            TNIPicker?.mode = .ttni
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if tableView.cellForRow(at: indexPath) === newTimesheet
        {
            tableView.deselectRow(at: indexPath, animated:true)
            
            let newTimesheetWarning = UIAlertController(title: nil, message: "If you create  new timesheet, all further flights will appear on another timesheet when you print the timehseets. This cannot be undone.", preferredStyle: .actionSheet)
            
            let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
            newTimesheetWarning.addAction(cancel)
            
            let newTimesheetAction = UIAlertAction(title: "New Timesheet", style: UIAlertAction.Style.destructive){_ in
                let timesheet = AircraftTimesheet(context: dataModel.managedObjectContext)
                timesheet.glidingCentre = dataModel.glidingCentre
                let numberOfTimesheetsForAircraft = self.aircraftBeingEdited.timesheets.count 
                timesheet.TTSNinitial = numberOfTimesheetsForAircraft > 0 ? self.aircraftBeingEdited.currentTimesheet!.TTSNfinal : 0
                timesheet.aircraft = self.aircraftBeingEdited
                timesheet.currentAircraft = self.aircraftBeingEdited
                timesheet.TTSNfinal = timesheet.TTSNinitial
                timesheet.date = Date()
                dataModel.saveContext()
            }

            newTimesheetWarning.addAction(newTimesheetAction)
            self.present(newTimesheetWarning, animated:true, completion:nil)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        let type = aircraftBeingEdited.type
        let numberOfSections = type < .towplane ? 2 : 3
        return numberOfSections
    }
}
