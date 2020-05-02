//
//  EditRecordPopover.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-22.
//
//

import Foundation
import UIKit

final class EditRecordPopover : UITableViewController, UITextFieldDelegate, ChangeSignificantDateDelegate
{
    @IBOutlet var pilot: UITableViewCell?
    @IBOutlet var passenger: UITableViewCell?
    @IBOutlet var upTime: UITableViewCell?
    @IBOutlet var downTime: UITableViewCell?
    @IBOutlet var sequence: UITableViewCell?
    @IBOutlet var vehicle: UITableViewCell?
    @IBOutlet var route: UITextField?
    var indexPathBeingEdited: IndexPath!
    var record: FlightRecord!
    var customDatePicker: ChangeSignificantDate?

    enum SegueIdentifiers: String
    {
        case ChangePilotForRecordSegue = "ChangePilotForRecordSegue"
        case ChangeOperatorForRecordSegue = "ChangeOperatorForRecordSegue"
        case ChangePassengerForRecordSegue = "ChangePassengerForRecordSegue"
        case ChangeSequenceForRecordSegue = "ChangeSequenceForRecordSegue"
        case ChangeVehicleSegue = "ChangeVehicleSegue"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}

        switch segueIdentifer
        {
        case .ChangePilotForRecordSegue:
            let changePilot = segue.destination as? ChangePilotPopover
            changePilot?.indexPathBeingEdited = indexPathBeingEdited
            changePilot?.yesMeansRecord = true
            changePilot?.flightRecord = record

        case .ChangeOperatorForRecordSegue:
            let changeOperator = segue.destination as? ChangeOperator
            changeOperator?.indexPathBeingEdited = indexPathBeingEdited
            changeOperator?.yesMeansRecord = true
            changeOperator?.flightRecord = record
        
        case .ChangePassengerForRecordSegue:
            let changePassenger = segue.destination as? ChangePassengerPopover
            changePassenger?.flightRecord = record
            changePassenger?.indexPathBeingEdited = indexPathBeingEdited
            changePassenger?.yesMeansRecord = true
        
        case .ChangeSequenceForRecordSegue:
            let changeSequence = segue.destination as? ChangeSequence
            changeSequence?.flightRecord = record
            
        case .ChangeVehicleSegue:
            let changeVehicle = segue.destination as? ChangeVehicle
            changeVehicle?.record = record
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        var returnValue = 7
        let type: VehicleType = record.timesheet?.aircraft?.type ?? .glider
        
        switch type
        {
        case .towplane:
            if let _ = record.connectedAircraftRecord
            {
                returnValue = 6
            }
            
        case .winch, .auto:
            returnValue = 5
            
        default:
            break
        }
        
        return returnValue
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard let cell = tableView.cellForRow(at: indexPath) else {return}
        
        if (cell == upTime) || (cell == downTime)
        {
            if let picker = customDatePicker
            {
                customDatePicker = nil
                guard let previouslySelectedCell = picker.tableViewCell as? TableViewCellStylePicker else {return}
                
                previouslySelectedCell.removePickerFromStackView()
                
                if previouslySelectedCell !== cell
                {
                    addPickerToCell(cell, atIndexPath:indexPath)
                }
            }
                
            else
            {
                addPickerToCell(cell, atIndexPath: indexPath)
            }
            
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        
        if cell == pilot
        {
            if record.timesheet.aircraft.type >= .towplane
            {
                self.performSegue(withIdentifier: "ChangePilotForRecordSegue", sender:self)
            }
                
            else
            {
                self.performSegue(withIdentifier: "ChangeOperatorForRecordSegue", sender:self)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated:true)
    }
    
    private func addPickerToCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath)
    {
            switch (indexPath as NSIndexPath).section
            {
            case 2:
                customDatePicker = ChangeTime(record: record, upOrDown: .uptime, aircraftIsFlying: false)
                
            case 3:
                customDatePicker = ChangeTime(record: record, upOrDown: .downtime, aircraftIsFlying: false)
                
            default:
                break
            }
            
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!)
            customDatePicker?.delegate = self
    }
    
    func dateChanged()
    {
        self.viewWillAppear(false)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "done")

        pilot?.textLabel?.text = record.pilot?.fullName
        passenger?.textLabel?.text = record.passenger?.fullName
        sequence?.textLabel?.text = record.flightSequence
        vehicle?.textLabel?.text = record.timesheet?.aircraft?.tailNumber
        
        var label = upTime?.viewWithTag(2) as? UILabel
        label?.text = record.timeUp.hoursAndMinutes
        
        label = downTime?.viewWithTag(2) as? UILabel
        label?.text = record.timeDown.hoursAndMinutes
        
        route?.isEnabled = record.flightSequence == "Transit" ? true : false
        
        if record.transitRoute != ""
        {
            route?.text = record.transitRoute
        }
        
        if record.timeUp < Date().midnight && dataModel.editorSignInTime < Date() - 30*60
        {
            let title = "Sign In"
            let message = "You must sign in to edit records from prior days. Your license number will be logged on all edits taking place in the next half hour."
            let signInAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel){_ in self.presentingViewController?.dismiss(animated: true)}
            signInAlert.addAction(cancelAction)
            
            let proceedAction = UIAlertAction(title: "Login", style: .default){_ in
                guard let name = signInAlert.textFields?.first?.text, name.count > 0 else {self.presentingViewController?.dismiss(animated: true); return}
                guard let license = signInAlert.textFields?.last?.text, license.count > 3 else {self.presentingViewController?.dismiss(animated: true); return}
                dataModel.editorName = name
                dataModel.editorLicense = license
                dataModel.editorSignInTime = Date()
            }
            
            signInAlert.addAction(proceedAction)
            signInAlert.addTextField(){textField in textField.placeholder = "Name"}
            signInAlert.addTextField(){textField in textField.placeholder = "License Number"}
            
            present(signInAlert, animated: true)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "done")
    }
  
    @objc func done()
    {
        presentingViewController?.dismiss(animated: true, completion:nil)
    }
    
    //MARK: - UITextFieldDelegate Methods

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        if string == "\n"
        {
            textField.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        if textField == route
        {
            record.transitRoute = textField.text ?? ""
        }
        
        dataModel.aircraftAreaController?.becomeFirstResponder()
        dataModel.saveContext()
    }
}
