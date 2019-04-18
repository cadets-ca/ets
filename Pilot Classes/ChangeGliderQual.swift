//
//  ChangeGliderQual.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-25.
//
//

import Foundation
import UIKit

final class ChangeGliderQual : UITableViewController, ChangeSignificantDateDelegate
{
    var pilot: Pilot!
    lazy var emptyCheckmark: UIImage = UIImage(assetIdentifier: .EmptyCheckmark)
    lazy var checkmark: UIImage = UIImage(assetIdentifier: .GreenCheckmark)
    var initialHighestGliderQual: GliderQuals!
    var customDatePicker: ChangeSignificantDate?

    func dateChanged()
    {
        tableView.reloadData()
    }
    
    //MARK: - View Lifecycle
    override func viewDidLoad()
    {
        initialHighestGliderQual = pilot.gliderQual
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if pilot.gliderQual != initialHighestGliderQual
        {
            NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
            dataModel.saveContext()
            NotificationCenter.default.post(name: highestQualChangedNotification, object:self)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableView Methods
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let qual = pilot.gliderQual.rawValue
        let checkmarkImageView = cell.viewWithTag(3) as? UIImageView
        let detailTextLabel = cell.viewWithTag(2) as? UILabel
        
        if qual >= (indexPath as NSIndexPath).row
        {
            checkmarkImageView?.image = checkmark
            switch (indexPath as NSIndexPath).row
            {
            case 2:
                detailTextLabel?.text = pilot.dateOfBasicGliderPilot.militaryFormatShort
                
            case 3:
                detailTextLabel?.text = pilot.dateOfFrontSeatFamilPilot.militaryFormatShort
                
            case 4:
                detailTextLabel?.text = pilot.dateOfRearSeatFamilPilot.militaryFormatShort
                
            case 5:
                detailTextLabel?.text = pilot.dateOfGliderInstructorPilot.militaryFormatShort
                
            case 6:
                detailTextLabel?.text = pilot.dateOfGliderCheckPilot.militaryFormatShort
                
            case 7:
                detailTextLabel?.text = pilot.dateOfGliderStandardsPilot.militaryFormatShort
                
            default:
                break
            }
        }
            
        else
        {
            checkmarkImageView?.image = emptyCheckmark
            detailTextLabel?.text = ""
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cell = tableView.cellForRow(at: indexPath)
        pilot.highestGliderQual = Int16((indexPath as NSIndexPath).row)
        
        switch (indexPath as NSIndexPath).row
        {
        case 2:
            if pilot.dateOfBasicGliderPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfBasicGliderPilot = Date()
            }
            
        case 3:
            if pilot.dateOfFrontSeatFamilPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfFrontSeatFamilPilot = Date()
            }
            
        case 4:
            if pilot.dateOfRearSeatFamilPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfRearSeatFamilPilot = Date()
            }
            
        case 5:
            if pilot.dateOfGliderInstructorPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfGliderInstructorPilot = Date()
            }
            
        case 6:
            if pilot.dateOfGliderCheckPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfGliderCheckPilot = Date()
            }
            
        case 7:
            if pilot.dateOfGliderStandardsPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfGliderStandardsPilot = Date()
            }
            
        default:
            break
        }
        
        tableView.reloadData()
        
        if (indexPath as NSIndexPath).row > 1
        {
            if customDatePicker == nil
            {
                addPickerToCell(cell, atIndexPath:indexPath)
            }
                
            else
            {
                let previouslySelectedCell = customDatePicker?.tableViewCell as? TableViewCellStylePicker
                customDatePicker = nil
                previouslySelectedCell?.removePickerFromStackView()

                if previouslySelectedCell !== cell
                {
                    addPickerToCell(cell, atIndexPath:indexPath)
                }
            }
            
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
    
    func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        guard let cell = cell as? TableViewCellStylePicker, let path = indexPath else {return}
        
        switch (path as NSIndexPath).row
        {
        case 2:
            let picker =  ChangeSignificantDate(mode: .basicGliderPilotDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        case 3:
            let picker =  ChangeSignificantDate(mode: .fsfDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        case 4:
            let picker =  ChangeSignificantDate(mode: .rsfDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker

        case 5:
            let picker =  ChangeSignificantDate(mode: .qgiDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        case 6:
            let picker =  ChangeSignificantDate(mode: .gliderCheckPilotDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker

        case 7:
            let picker =  ChangeSignificantDate(mode: .gliderStandardsPilotDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        default:
            break
        }
        
        customDatePicker?.delegate = self
    }
}
