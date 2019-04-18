//
//  ChangeTowQual.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-25.
//
//

import Foundation
import UIKit

final class ChangeTowQual : UITableViewController, ChangeSignificantDateDelegate
{
    var pilot: Pilot!
    lazy var emptyCheckmark: UIImage = UIImage(assetIdentifier: .EmptyCheckmark)
    lazy var checkmark: UIImage = UIImage(assetIdentifier: .GreenCheckmark)
    var initialHighestTowQual: TowplaneQuals!
    var customDatePicker: ChangeSignificantDate?

    func dateChanged()
    {
        tableView.reloadData()
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        initialHighestTowQual = pilot.towQual
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
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
        let qual = pilot.towQual.rawValue
        let checkmarkImageView = cell.viewWithTag(3) as? UIImageView
        let detailTextLabel = cell.viewWithTag(2) as? UILabel

        if qual >= (indexPath as NSIndexPath).row
        {
            checkmarkImageView?.image = checkmark
            switch (indexPath as NSIndexPath).row
            {
            case 1:
                detailTextLabel?.text = pilot.dateOfTowPilot.militaryFormatShort
                
            case 2:
                detailTextLabel?.text = pilot.dateOfTowCheckPilot.militaryFormatShort
                
            case 3:
                detailTextLabel?.text = pilot.dateOfTowStandardsPilot.militaryFormatShort
                
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
        pilot.highestScoutQual = Int16((indexPath as NSIndexPath).row)
        
        switch (indexPath as NSIndexPath).row
        {
        case 1:
            if pilot.dateOfTowPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfTowPilot = Date()
            }
            
        case 2:
            if pilot.dateOfTowCheckPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfTowCheckPilot = Date()
            }
            
        case 3:
            if pilot.dateOfTowStandardsPilot < Date() - 1000*365*24*60*60
            {
                pilot.dateOfTowStandardsPilot = Date()
            }
            
        default:
            break
        }
        
        tableView.reloadData()
        
        if (indexPath as NSIndexPath).row > 0
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
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if pilot.towQual != initialHighestTowQual
        {
            NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
            dataModel.saveContext()
            NotificationCenter.default.post(name: highestQualChangedNotification, object:self, userInfo:nil)
        }
    }
    
    func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        guard let cell = cell as? TableViewCellStylePicker, let path = indexPath else {return}
        
        switch (path as NSIndexPath).row
        {
        case 1:
            let picker =  ChangeSignificantDate(mode: .towPilotDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        case 2:
            let picker =  ChangeSignificantDate(mode:.towCheckPilotDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        case 3:
            let picker =  ChangeSignificantDate(mode: .towStandardsPilotDate, pilotBeingEdited: pilot)
            cell.addPickerToStackView(picker)
            customDatePicker = picker
            
        default:
            break
        }
        
        customDatePicker?.delegate = self
    }
}
