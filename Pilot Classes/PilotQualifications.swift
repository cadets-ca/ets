//
//  PilotQualifications.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-27.
//
//

import Foundation
import UIKit
import CoreData

final class PilotQualifications : UITableViewController, ChangeSignificantDateDelegate
{
    @IBOutlet var LCO: UITableViewCell!
    @IBOutlet var winchLaunch: UITableViewCell!
    @IBOutlet var winchOperator: UITableViewCell!
    @IBOutlet var winchLaunchInstructor: UITableViewCell!
    @IBOutlet var winchRetrieveDriver: UITableViewCell!
    @IBOutlet var autoLaunch: UITableViewCell!
    @IBOutlet var autoTowDriver: UITableViewCell!
    @IBOutlet var autoLaunchInstructor: UITableViewCell!
    @IBOutlet var autoLaunchObserver: UITableViewCell!
    @IBOutlet var gliderMaintenancePilot: UITableViewCell!
    @IBOutlet var towAircraftMaintenancePilot: UITableViewCell!
    @IBOutlet var gliderXcountry: UITableViewCell!
    @IBOutlet var towXcountry: UITableViewCell!
    @IBOutlet var DND404: UITableViewCell!
    @IBOutlet var driversLicense: UITableViewCell!
    @IBOutlet var standardFirstAid: UITableViewCell!
    @IBOutlet var emergencyFirstAid: UITableViewCell!

    var pilot: Pilot!

    lazy var emptyCheckmark: UIImage = UIImage(assetIdentifier: .EmptyCheckmark)
    lazy var checkmark: UIImage = UIImage(assetIdentifier: .GreenCheckmark)
    
    var customDatePicker: ChangeSignificantDate?

    func dateChanged()
    {
        viewWillAppear(false)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        for qual in pilot.qualifications
        {
            checkCellForQual(qual.nameOfQualification)
        }
        
        func processQual(_ qual: String, cell: UITableViewCell, date: Date?)
        {
            let checkmarkImageView = cell.viewWithTag(3) as? UIImageView
            let detailTextLabel = cell.viewWithTag(2) as? UILabel
            
            if pilot.pilotHoldsQual(qual)
            {
                checkmarkImageView?.image = checkmark
                detailTextLabel?.text = date?.militaryFormatShort ?? ""
            }
                
            else
            {
                checkmarkImageView?.image = emptyCheckmark
                detailTextLabel?.text = ""
            }
        }
        
        processQual("LCO", cell: LCO, date: pilot.dateOfLaunchControlOfficer)
        processQual("Winch Launch", cell: winchLaunch, date: pilot.dateOfWinchLaunchPilot)
        processQual("Winch Operator", cell: winchOperator, date: pilot.dateOfWinchLaunchOperator)
        processQual("Winch Launch Instructor", cell: winchLaunchInstructor, date: pilot.dateOfWinchLaunchInstructor)
        processQual("Winch Retrieve Driver", cell: winchRetrieveDriver, date: pilot.dateOfWinchRetrieveDriver)
        processQual("Glider Xcountry", cell: gliderXcountry, date: pilot.dateOfGliderPilotXCountry)
        processQual("Tow Xcountry", cell: towXcountry, date: pilot.dateOfTowPilotXCountry)

        tableView.reloadData()
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
    
    func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        guard let cell = cell as? TableViewCellStylePicker, let indexPath = indexPath else {return}

        switch ((indexPath as NSIndexPath).section, (indexPath as NSIndexPath).row)
        {
        case (0, _):
            let picker =  ChangeSignificantDate(mode: .lcoDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)
            
        case (1, 0):
            let picker =  ChangeSignificantDate(mode: .winchLaunchDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)

        case (1, 1):
            let picker =  ChangeSignificantDate(mode: .winchOperatorDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)
                
        case (1, 2):
            let picker =  ChangeSignificantDate(mode: .winchLaunchInstructorDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)
                
        case (1, 3):
            let picker =  ChangeSignificantDate(mode: .winchRetrieveDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)
            
        case (4, 0):
            let picker =  ChangeSignificantDate(mode: .gliderXCountryDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)
        
        case (4, 1):
            let picker =  ChangeSignificantDate(mode: .towXCountryDate, pilotBeingEdited: pilot)
            customDatePicker = picker
            cell.addPickerToStackView(picker)
            
        default:
            break
        }
        
        customDatePicker?.delegate = self
    }
    
    func checkCellForQual(_ qual: String)
    {
        switch qual
        {
        case "Auto Tow Driver":
            autoTowDriver.accessoryType = .checkmark
            
        case "Auto Launch Instructor":
            autoLaunchInstructor.accessoryType = .checkmark
            
        case "Auto Launch Observer":
            autoLaunchObserver.accessoryType = .checkmark
            
        case "Glider Maintenance Pilot":
            gliderMaintenancePilot.accessoryType = .checkmark
            
        case "Tow Maintenance Pilot":
            towAircraftMaintenancePilot.accessoryType = .checkmark
            
        case "DND 404":
            DND404.accessoryType = .checkmark
            
        case "Drivers License":
            driversLicense.accessoryType = .checkmark
            
        case "Standard First Aid":
            standardFirstAid.accessoryType = .checkmark
            
        case "Emergency First Aid":
            emergencyFirstAid.accessoryType = .checkmark

        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard let cell = tableView.cellForRow(at: indexPath) else {return}
        var qual: Qualification
        var nameOfQual = ""
        var cellCanAccomodateDatePicker = false
        
        func verifyThatQualHasDate(_ qual: String, date: inout Date)
        {
            nameOfQual = qual
            cellCanAccomodateDatePicker = true
        }
        
        switch cell
        {
        case LCO:
            verifyThatQualHasDate("LCO", date: &pilot.dateOfLaunchControlOfficer)
            
        case winchLaunch:
            verifyThatQualHasDate("Winch Launch", date: &pilot.dateOfWinchLaunchPilot)

        case winchOperator:
            verifyThatQualHasDate("Winch Operator", date: &pilot.dateOfWinchLaunchOperator)

        case winchLaunchInstructor:
            verifyThatQualHasDate("Winch Launch Instructor", date: &pilot.dateOfWinchLaunchInstructor)

        case winchRetrieveDriver:
            verifyThatQualHasDate("Winch Retrieve Driver", date: &pilot.dateOfWinchLaunchPilot)

        case gliderXcountry:
            verifyThatQualHasDate("Glider Xcountry", date: &pilot.dateOfGliderPilotXCountry)

        case towXcountry:
            verifyThatQualHasDate("Tow Xcountry", date: &pilot.dateOfTowPilotXCountry)

        case autoLaunch:
            nameOfQual = "Auto Tow Launch"
            
        case autoTowDriver:
            nameOfQual = "Auto Tow Driver"
            
        case autoLaunchInstructor:
            nameOfQual = "Auto Launch Instructor"

        case autoLaunchObserver:
            nameOfQual = "Auto Launch Observer"

        case gliderMaintenancePilot:
            nameOfQual = "Glider Maintenance Pilot"

        case towAircraftMaintenancePilot:
            nameOfQual = "Tow Maintenance Pilot"

        case DND404:
            nameOfQual = "DND 404"

        case driversLicense:
            nameOfQual = "Drivers License"

        case standardFirstAid:
            nameOfQual = "Standard First Aid"

        case emergencyFirstAid:
            nameOfQual = "Emergency First Aid"
            
        default:
            break
        }
    
        let qualRequest = Qualification.request
        qualRequest.predicate = NSPredicate(format: "nameOfQualification == %@", nameOfQual)
        let matchingQuals = try! dataModel.managedObjectContext.fetch(qualRequest) 
        
        if matchingQuals.count > 0
        {
            qual = matchingQuals[0]
        }
            
        else
        {
            qual = Qualification(context: dataModel.managedObjectContext)
            qual.nameOfQualification = nameOfQual
        }
        
        var pilotQuals = pilot.qualifications

        if cellCanAccomodateDatePicker
        {
            if (pilotQuals.contains(qual)) && !(customDatePicker?.tableViewCell == cell)
            {
                pilotQuals.remove(qual)
                pilot.qualifications = pilotQuals
            }
                
            else
            {
                pilotQuals.insert(qual)
                pilot.qualifications = pilotQuals
                
                if customDatePicker == nil
                {
                    addPickerToCell(cell, atIndexPath:indexPath)
                }
                    
                else
                {
                    let previouslySelectedCell = customDatePicker?.tableViewCell as? TableViewCellStylePicker
                    previouslySelectedCell?.removePickerFromStackView()
                    customDatePicker = nil
                    
                    if previouslySelectedCell != cell
                    {
                        addPickerToCell(cell, atIndexPath:indexPath)
                    }
                }
            }
            
            tableView.beginUpdates()
            tableView.endUpdates()
        }
            
        else
        {
            if cell.accessoryType == .checkmark
            {
                cell.accessoryType = .none
                pilotQuals.remove(qual)
                pilot.qualifications =  pilotQuals
                tableView.deselectRow(at: indexPath, animated:true)
                NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
                return
            }
                
            else
            {
                pilotQuals.insert(qual)
                pilot.qualifications =  pilotQuals
                cell.accessoryType = .checkmark
            }
        }
        
        tableView.deselectRow(at: indexPath, animated:true)
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        viewWillAppear(false)
    }
}
