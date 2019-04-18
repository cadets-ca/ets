//
//  AddCadetsIndividually.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2016-10-06.
//
//

import Foundation
import UIKit
import CoreData

final class AddCadetsIndividually : UIViewController, UITextFieldDelegate, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate
{
    @IBOutlet var squadronNumber: UITextField!
    @IBOutlet var cadetLevel: UISegmentedControl!
    @IBOutlet var lastName: UISearchBar!
    @IBOutlet var firstName: UISearchBar!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var lastNameLabel: UILabel!
    @IBOutlet var firstNameLabel: UILabel!
    @IBOutlet var cadetLevelLabel: UILabel!
    @IBOutlet var toolbar: UIToolbar!
    
    var number = Int16(0)
    var level = Int16(0)
    var likelyCadets = [Pilot]()

    //MARK: - View Lifecycle
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        setup()
    }
    
    func setup()
    {
        cadetLevel.isHidden = true
        cadetLevel.selectedSegmentIndex = -1
        lastName.isHidden = true
        lastName.text = ""
        firstName.isHidden = true
        firstName.text = ""
        tableView.isHidden = true
        lastNameLabel.isHidden = true
        firstNameLabel.isHidden = true
        cadetLevelLabel.isHidden = true
        toolbar.isHidden = true
        lastName.returnKeyType = .next
        firstName.returnKeyType = .done
        squadronNumber.becomeFirstResponder()
        if traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.compact
        {
            squadronNumber.keyboardType = .default
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
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
    
    @IBAction func quit()
    {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func levelChanged()
    {
        lastName.isHidden = false
        lastNameLabel.isHidden = false
        firstName.isHidden = false
        firstNameLabel.isHidden = false
        tableView.isHidden = false
        lastName.becomeFirstResponder()
        level = Int16(cadetLevel.selectedSegmentIndex + 1)
    }
    
    //MARK: - UITableView Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return likelyCadets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let likelyCadet = likelyCadets[indexPath.row]
        cell.textLabel?.text = likelyCadet.fullName
        
        guard let mostRecentAttendanceRecord = likelyCadet.attendanceRecords.first else {cell.detailTextLabel?.text = nil; return cell}
        cell.detailTextLabel?.text = "Attended Gliding on \(mostRecentAttendanceRecord.timeIn.militaryFormatShort)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        return "Suggestions"
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cadet = likelyCadets[indexPath.row]
        
        let gliderQual: GliderQuals
        
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

        
        let welcomeTitle = "Are you \(cadet.fullName)?"
        let welcomeMessage = "If so, welcome back! Press sign in and pass the iPad to the next cadet. Otherwise press cancel."
        
        let welcome = UIAlertController(title: welcomeTitle, message: welcomeMessage, preferredStyle: .alert)
        let signIn = UIAlertAction(title: "Sign In", style: .default, handler: {_ in cadet.highestGliderQual = Int16(gliderQual.rawValue); dataModel.createAttendanceRecordForPerson(cadet); dataModel.saveContext(); self.setup()})
        welcome.addAction(signIn)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {_ in self.tableView.deselectRow(at: indexPath, animated: true)})
        welcome.addAction(cancel)

        present(welcome, animated:true, completion:nil)
    }
    
    //MARK: - UITextField Methods
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
    {
        if let lastNameText = lastName.text, let firstNameText = firstName.text
        {
            let fetchRequest = Pilot.request
            
            if firstNameText == ""
            {
                fetchRequest.predicate = NSPredicate(format: "%K = %d AND %K BEGINSWITH %@", #keyPath(Pilot.squadron), number, #keyPath(Pilot.name), lastNameText)
            }
            
            else
            {
                fetchRequest.predicate = NSPredicate(format: "%K = %d AND %K BEGINSWITH %@ AND %K CONTAINS %@", #keyPath(Pilot.squadron), number, #keyPath(Pilot.name), lastNameText, #keyPath(Pilot.firstName), firstNameText)

            }
            
            let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.name), ascending: true)
            fetchRequest.sortDescriptors = [nameSortDescriptor]
            likelyCadets = try! dataModel.managedObjectContext.fetch(fetchRequest)

            print("\(likelyCadets.count) cadets found")
            
            tableView.reloadData()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        if searchBar === lastName
        {
            searchBar.resignFirstResponder()
            firstName.becomeFirstResponder()
        }
        
        else
        {
            let gliderQual: GliderQuals
            
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
            
            let cadet = Pilot(context: dataModel.managedObjectContext)
            cadet.glidingCentre = dataModel.glidingCentre
            cadet.signedIn = false
            cadet.highestScoutQual = Int16(TowplaneQuals.noScout.rawValue)
            cadet.name = lastName.text ?? ""
            cadet.firstName = firstName.text ?? ""
            cadet.typeOfParticipant = "cadet"
            cadet.squadron = number
            let fullName = cadet.name + ", " + (firstName.text ?? "")
            cadet.fullName = firstName.text != "" ? fullName : cadet.name
            cadet.highestGliderQual = Int16(gliderQual.rawValue)
            dataModel.createAttendanceRecordForPerson(cadet)
            dataModel.saveContext()
            
            let welcomeTitle = "Welcome, \(cadet.fullName)"
            let welcomeMessage = "You are signed in. Pass the iPad to the next cadet. If you have made a mistake, let a gliding staff member know."
            
            let welcome = UIAlertController(title: welcomeTitle, message: welcomeMessage, preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel, handler: {_ in self.setup()})
            welcome.addAction(ok)
            present(welcome, animated:true, completion:nil)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        switch textField
        {
        case squadronNumber:
            if let number = Int(squadronNumber.text ?? ""), number > 0
            {
                self.number = Int16(number)
                cadetLevel.isHidden = false
                cadetLevelLabel.isHidden = false
                squadronNumber.resignFirstResponder()
                cadetLevel.becomeFirstResponder()
            }
            
            else
            {
                let errorTitle = "No Squadron Number Entered"
                let errorMessage = "You must enter a squadron number to continue."
                
                let error = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                error.addAction(cancel)
                present(error, animated:true, completion:nil)
            }
            
        case lastName:
            break
            
        case firstName:
            break

        default:
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        return
    }
}
