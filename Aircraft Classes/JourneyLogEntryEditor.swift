//
//  JourneyLogEntryEditor.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-17.
//
//

import Foundation
import UIKit

final class JourneyLogEntryEditor : UITableViewController, ChangeSignificantDateDelegate
{
    @IBOutlet var date: UITableViewCell!
    @IBOutlet var location: UITableViewCell!
    @IBOutlet var initialTTSN: UITableViewCell!
    @IBOutlet var TTSNfinal: UITableViewCell!
    @IBOutlet var airTime: UITableViewCell!
    var timesheetBeingEdited: AircraftTimesheet!
    var pathOfCellWithDatePicker: IndexPath!
    var customDatePicker: ChangeSignificantDate!

    enum SegueIdentifiers: String
    {
        case InitialTTSNSegue = "InitialTTSNSegue"
        case FinalTTSNSegue = "FinalTTSNSegue"
        case ChangeUnitForTimesheetSegue = "ChangeUnitForTimesheetSegue"
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        initialTTSN.detailTextLabel?.text = timesheetBeingEdited.TTSNinitial.stringWithDecimal
        location.textLabel?.text = timesheetBeingEdited.glidingCentre?.name
        location.imageView?.image = UIImage(named: timesheetBeingEdited.glidingCentre.name)
        TTSNfinal.detailTextLabel?.text = timesheetBeingEdited.TTSNfinal.stringWithDecimal
        TTSNfinal.accessoryType = timesheetBeingEdited.aircraft.type > .winch ? .none : .disclosureIndicator
        
        let dateLabel = date.viewWithTag(1) as? UILabel
        dateLabel?.text = timesheetBeingEdited.date.militaryFormatLong
        
        let hoursString = timesheetBeingEdited.TTSNfinal - timesheetBeingEdited.TTSNinitial
        airTime.detailTextLabel?.text = hoursString.stringWithDecimal
        airTime.textLabel?.text = timesheetBeingEdited.aircraft.type > .winch ? "Air Time" : "Engine Time"
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .InitialTTSNSegue:
            let TNIPicker = segue.destination as? TNIPickerView
            TNIPicker?.timesheetBeingEdited = timesheetBeingEdited
            TNIPicker?.mode = .initialTTSN
            
        case .FinalTTSNSegue:
            let TNIPicker = segue.destination as? TNIPickerView
            TNIPicker?.timesheetBeingEdited = timesheetBeingEdited
            TNIPicker?.mode = .finalTTSN

        case .ChangeUnitForTimesheetSegue:
            let changeGC = segue.destination as? ChangeGlidingCentreForTimesheet
            changeGC?.timesheet = timesheetBeingEdited
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cell = tableView.cellForRow(at: indexPath)
        
        if cell === date
        {
            if customDatePicker == nil
            {
                addPickerToCell(cell, atIndexPath:indexPath)
                customDatePicker?.maximumDate = Date()
            }
                
            else
            {
                let previouslySelectedCell = customDatePicker.tableViewCell!
                let previousPath = tableView.indexPath(for: previouslySelectedCell)
                
                if previouslySelectedCell !== cell
                {
                    removePickerFromCell(previouslySelectedCell, atIndexPath: previousPath!, andMovePickerToCell:cell, atIndexPath:indexPath)
                }
                    
                else
                {
                    removePickerFromCell(previouslySelectedCell, atIndexPath: previousPath!)
                }
            }
        }
        
        tableView.deselectRow(at: indexPath, animated:true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        var height = CGFloat(44.0)
        
        guard let path = pathOfCellWithDatePicker else {return height}

        if (indexPath as NSIndexPath).compare(path) == .orderedSame
        {
            height += 217
        }
        
        return height
    }
    
    func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        guard let cell = cell, let indexPath = indexPath else {return}

        tableView.beginUpdates()
        pathOfCellWithDatePicker = indexPath
        
        switch (indexPath as NSIndexPath).section
        {
        case 0:
                customDatePicker =  ChangeTimesheetDate(timesheet: timesheetBeingEdited)
                cell.addSubview(customDatePicker)
            
        default:
            break
        }
        
        customDatePicker.alpha = 0
        customDatePicker.frame = CGRect(x: 0, y: 44, width: cell.frame.size.width, height: 217)
        customDatePicker.delegate = self
        tableView.endUpdates()
        UIView.animate(withDuration: 0.2, animations:{self.customDatePicker.alpha = 1}, completion:nil)
    }
    
    func removePickerFromCell(_ cell: UITableViewCell, atIndexPath originalIndexPath:IndexPath, andMovePickerToCell newCell:UITableViewCell? = nil, atIndexPath newIndexPath:IndexPath? = nil)
    {
        UIView.animate(withDuration: 0.2, animations:{self.customDatePicker.alpha = 0}){_ in
            self.customDatePicker.removeFromSuperview()
            self.customDatePicker = nil
            self.addPickerToCell(newCell, atIndexPath:newIndexPath)
        }
        
        tableView.beginUpdates()
        pathOfCellWithDatePicker = nil
        tableView.endUpdates()
    }
    
    func dateChanged()
    {        
        timesheetBeingEdited.date = customDatePicker.date
        var newDateComponents = gregorian.dateComponents([.year, .month, .day], from: customDatePicker.date)

        for record in timesheetBeingEdited.flightRecords
        {
            record.timesheet.logChangesTo(record: record)
            var oldDateComponents = gregorian.dateComponents([.hour, .minute], from: record.timeUp)
            newDateComponents.minute = oldDateComponents.minute
            newDateComponents.hour = oldDateComponents.hour
            record.timeUp = gregorian.date(from: newDateComponents)!
            
            oldDateComponents = gregorian.dateComponents([.hour, .minute], from: record.timeDown)
            newDateComponents.minute = oldDateComponents.minute
            newDateComponents.hour = oldDateComponents.hour
            record.timeDown = gregorian.date(from: newDateComponents)!
        }
        dataModel.saveContext()
        viewWillAppear(false)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool
    {
        if identifier == "FinalTTSNSegue"
        {
            if timesheetBeingEdited.aircraft.type > .winch
            {
                return false
            }
        }
        
        return true
    }
}
