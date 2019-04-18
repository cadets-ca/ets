//
//  LogBookCreator.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-25.
//
//

import Foundation
import UIKit

final class LogBookCreator : UITableViewController, ChangeSignificantDateDelegate
{
    @IBOutlet var startDateCell: UITableViewCell!
    @IBOutlet var endDateCell: UITableViewCell!

    var pilot: Pilot!
    var startDate = Date.startOfYear
    var endDate = Date()
    var customDatePicker: ChangeSignificantDate?

    func dateChanged()
    {
        viewWillAppear(false)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        let startDateLabel = startDateCell.viewWithTag(1) as? UILabel
        let endDateLabel = endDateCell.viewWithTag(1) as? UILabel
        
        startDateLabel?.text = startDate.militaryFormatShort
        endDateLabel?.text = endDate.militaryFormatShort
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        guard let cellToGetPicker = cell as? TableViewCellStylePicker, let indexPath = indexPath else {return}
        
        if (indexPath as NSIndexPath).section == 0
        {
            switch (indexPath as NSIndexPath).row
            {
            case 0:
                let picker =  ChangeSignificantDate(mode: .logBookStartDate, logBookCreator: self)
                customDatePicker = picker
                cellToGetPicker.addPickerToStackView(picker)
                
            case 1:
                let picker =  ChangeSignificantDate(mode: .logBookEndDate, logBookCreator: self)
                customDatePicker = picker
                cellToGetPicker.addPickerToStackView(picker)
                
            default:
                break
            }
        }
        
        customDatePicker?.delegate = self
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    //MARK: - UITableView delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cell = tableView.cellForRow(at: indexPath)
        
        if (indexPath as NSIndexPath).section == 0
        {
            if customDatePicker == nil
            {
                self.addPickerToCell(cell, atIndexPath:indexPath)
            }
                
            else
            {
                let previouslySelectedCell = customDatePicker?.tableViewCell as? TableViewCellStylePicker
                previouslySelectedCell?.removePickerFromStackView()
                customDatePicker = nil

                if previouslySelectedCell !== cell
                {
                    self.addPickerToCell(cell, atIndexPath: indexPath)
                }
                
                else
                {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
        }
        
        if (indexPath as NSIndexPath).section == 1
        {
            dataModel.emailLogBookForPilot(pilot, fromDate: startDate, toDate: endDate)
        }
    }
}
