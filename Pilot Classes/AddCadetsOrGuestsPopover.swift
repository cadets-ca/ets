//
//  AddCadetsOrGuestsPopover.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-21.
//
//

import Foundation
import UIKit
import CoreData

final class AddCadetsOrGuestsPopover : UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate
{
    var namesOfPersonsToSignIn:[(firstName: String, lastName: String)] = [("", ""), ("", "")]
    var typeOfPassengerBeingSignedIn: PassengerType!
    var rowBeingEdited = 0

    @IBOutlet var tableView: UITableView!
    @IBOutlet var distanceToBottomLayoutGuide: NSLayoutConstraint?
    @IBOutlet var squadronNumber: UITextField?
    @IBOutlet var cadetLevel: UISegmentedControl?

    //MARK: - View Lifecycle
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector:#selector(AddCadetsOrGuestsPopover.keyboardWasShown(_:)), name: UIResponder.keyboardDidShowNotification, object:nil)
        NotificationCenter.default.addObserver(self, selector:#selector(AddCadetsOrGuestsPopover.keyboardWillHide(_:)), name: UIResponder.keyboardDidHideNotification, object:nil)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        navigationController?.popoverPresentationController?.delegate = self
    }
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool
    {
        return false
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        dataModel.aircraftAreaController?.becomeFirstResponder()
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func cancel()
    {
        navigationController?.popoverPresentationController?.delegate = nil
        let _ = navigationController?.popViewController(animated: true)
    }
    
    @IBAction func done()
    {
        navigationController?.popoverPresentationController?.delegate = nil
        
        let indexPathOfRowBeingEdited = IndexPath(item: rowBeingEdited, section:0)
        let cell = tableView.cellForRow(at: indexPathOfRowBeingEdited)
        let lastNameField = cell?.viewWithTag(1) as? UITextField
        let firstNameField = cell?.viewWithTag(2) as? UITextField

        lastNameField?.endEditing(false)
        firstNameField?.endEditing(false)
        
        var saveRequired = false
        let set = CharacterSet.decimalDigits.inverted
        
        let squadronNumbersOnly = (squadronNumber?.text ?? "").components(separatedBy: set).reduce("", +)

        if (typeOfPassengerBeingSignedIn == .cadet) && !((Int(squadronNumbersOnly) ?? 0) > 0)
        {
            let alert = UIAlertController(title:"Invalid Squadron", message:"You must assign cadets a squadron number of 1 or greater.", preferredStyle:.alert)
            let done = UIAlertAction(title: "OK", style: .default, handler:nil)
            alert.addAction(done)
            present(alert, animated:true, completion:nil)
            return
        }
        
        for personsNames in namesOfPersonsToSignIn
        {
            let gliderQual: GliderQuals
            let fullName = personsNames.lastName + ", " + personsNames.firstName

            if personsNames.lastName.count > 0
            {
                if typeOfPassengerBeingSignedIn == .cadet
                {
                    switch cadetLevel?.selectedSegmentIndex ?? 0
                    {
                    case 1:
                        gliderQual = .level2Cadet

                    case 2:
                        gliderQual = .level3Cadet

                    case 3:
                        gliderQual = .level4Cadet
                        
                    default:
                        gliderQual = .level1Cadet
                    }
                }
                    
                else
                {
                    gliderQual = .noGlider
                }
                
                let typeOfParticipant = typeOfPassengerBeingSignedIn == .cadet ? "cadet" : "guest"
                let pilot: Pilot
                
                let pilotRequest = Pilot.request
                pilotRequest.predicate = NSPredicate(format: "typeOfParticipant == %@ AND fullName == %@ AND squadron == %@ AND highestGliderQual <= %@",typeOfParticipant, fullName, squadronNumbersOnly, NSNumber(value: gliderQual.rawValue))
                
                let pilotList = try! dataModel.managedObjectContext.fetch(pilotRequest)
                
                if pilotList.count > 0
                {
                    pilot = pilotList[0]
                }
                    
                else
                {
                    pilot = Pilot(context: dataModel.managedObjectContext)
                    pilot.glidingCentre = dataModel.glidingCentre
                    pilot.signedIn = false
                    pilot.highestScoutQual = Int16(TowplaneQuals.noScout.rawValue)
                    pilot.name = personsNames.lastName
                    pilot.typeOfParticipant = typeOfParticipant
                    pilot.squadron = (Int16(squadronNumbersOnly) ?? 0)
                    pilot.firstName = personsNames.firstName
                    pilot.fullName = pilot.firstName != "" ? fullName : pilot.name
                }
                
                pilot.highestGliderQual = Int16(gliderQual.rawValue)
                dataModel.createAttendanceRecordForPerson(pilot)
                saveRequired = true
            }
        }
        
        if saveRequired
        {
            dataModel.saveContext()
        }
        
        let _ = navigationController?.popToRootViewController(animated: true)
    }

    //MARK: - UITableView Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return namesOfPersonsToSignIn.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Name Cell", for: indexPath)
        let personsNames = namesOfPersonsToSignIn[(indexPath as NSIndexPath).row]
        let personsLastName = personsNames.lastName
        let personsFirstName = personsNames.firstName
        
        let lastNameField = cell.viewWithTag(1) as! UITextField
        lastNameField.text = personsLastName
        
        let firstNameField = cell.viewWithTag(2) as! UITextField
        firstNameField.text = personsFirstName
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        if cadetLevel == nil
        {
            return "  Last Name                   First Name"
        }
        
        else
        {
            return nil
        }
    }
        
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        return tableView.numberOfRows(inSection: (indexPath as NSIndexPath).section) == 1 ? false : true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle
    {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            namesOfPersonsToSignIn.remove(at: (indexPath as NSIndexPath).row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)
    {
        let path = IndexPath(item: rowBeingEdited, section:0)
        if let cell = tableView.cellForRow(at: path)
        {
            let lastNameField = cell.viewWithTag(1) as! UITextField
            let firstNameField = cell.viewWithTag(2) as! UITextField
            
            if !firstNameField.isFirstResponder
            {
                lastNameField.becomeFirstResponder()
            }
        }
    }

    //MARK: - UITextField Methods
    func textFieldDidBeginEditing(_ textField: UITextField)
    {
        let cell = textField.tableViewCell!
        let path = tableView.indexPath(for: cell)!
        rowBeingEdited = (path as NSIndexPath).row
    }
    
    @objc func keyboardWasShown(_ notification: Notification)
    {
        distanceToBottomLayoutGuide?.constant = 160
    }
    
    @objc func keyboardWillHide(_ notification: Notification)
    {
        distanceToBottomLayoutGuide?.constant = -49
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        switch textField.tag
        {
        case 1:
            let firstNameField = textField.tableViewCell!.viewWithTag(2) as! UITextField
            firstNameField.becomeFirstResponder()
            
        case 2:
            let cell = textField.tableViewCell!
            let path = tableView.indexPath(for: cell)!
            
            if (path as NSIndexPath).row == namesOfPersonsToSignIn.count - 1
            {
                let newPath = IndexPath(item: namesOfPersonsToSignIn.count, section: 0)
                namesOfPersonsToSignIn.append((firstName: "", lastName: ""))
                tableView.insertRows(at: [newPath], with: .automatic)
                rowBeingEdited = (newPath as NSIndexPath).row
                tableView.scrollToRow(at: newPath, at: .none, animated:true)
                let newCell = tableView.cellForRow(at: newPath)
                let lastNameField = newCell?.viewWithTag(1) as? UITextField
                lastNameField?.becomeFirstResponder()
            }
                
            else
            {
                let nextCellPath = IndexPath(item: ((path as NSIndexPath).row + 1), section: 0)
                let nextCell = tableView.cellForRow(at: nextCellPath)!
                tableView.scrollToRow(at: nextCellPath, at: .none, animated:true)
                rowBeingEdited = (nextCellPath as NSIndexPath).row
                let lastNameField = nextCell.viewWithTag(1) as! UITextField
                lastNameField.becomeFirstResponder()
            }
            
        default:
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        let cell = textField.tableViewCell!
        if let path = tableView.indexPath(for: cell)
        {
            var personName = namesOfPersonsToSignIn[(path as NSIndexPath).row]
            
            if textField.tag == 1
            {
                if (textField.text?.count) ?? 0 > 0
                {
                    personName.lastName = textField.text ?? ""
                }
            }
            
            if textField.tag == 2
            {
                if textField.text?.count ?? 0 > 0
                {
                    personName.firstName = textField.text ?? ""
                }
            }
            
            namesOfPersonsToSignIn[(path as NSIndexPath).row] = personName
        }
    }
}
