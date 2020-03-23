//
//  SignInPilotFromList.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-02.
//
//

import Foundation
import UIKit
import CoreData

protocol AddPilotPopoverDelegate
{
    func createAttendanceRecordForPerson(_ pilotToAdd: Pilot)
    func signOutPerson(_ pilotToRemove: Pilot)
}

final class SignInPilotFromList: UITableViewController, UISearchBarDelegate
{
    @IBOutlet var showInactivePilotsSwitch: UISwitch!
    @IBOutlet var pilotSearchBar: UISearchBar!

    var showInactivePilots = false
    var pilotNamesGroupedAlphabeticallyByInitial = [[Pilot]]()
    var pilotNamesSectionTitles = [String]()
    var rowDisplayingMenu: IndexPath?
    var currentlyDisplayedPilots = [Pilot]()
    var delegate: AddPilotPopoverDelegate?

    //MARK: - Responding to Events
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
    {
        if searchText.count == 0
        {
            searchBar.resignFirstResponder()
        }
        
        let formerlyDisplayedPilots = Set(currentlyDisplayedPilots)
        currentlyDisplayedPilots = getPilotsToDisplay()
        
        var sectionIndex = 0
        var deletePaths = [IndexPath]()
        let deleteSections = NSMutableIndexSet()
        for arrayOfPilotsWithSameFirstLetter in pilotNamesGroupedAlphabeticallyByInitial
        {
            var rowIndex = 0
            var deletePathsThisSection = [IndexPath]()
            for pilot in arrayOfPilotsWithSameFirstLetter
            {
                if currentlyDisplayedPilots.firstIndex(of: pilot) == nil
                {
                    let pathOfPilotToRemove = IndexPath(row: rowIndex, section: sectionIndex)
                    deletePathsThisSection.append(pathOfPilotToRemove)
                }
                rowIndex += 1
            }
            
            if deletePathsThisSection.count == arrayOfPilotsWithSameFirstLetter.count
            {
                deleteSections.add(sectionIndex)
            }
                
            else
            {
                deletePaths += deletePathsThisSection
            }
            
            sectionIndex += 1
        }
        
        organizeStaffNamesAlphabeticalSectionsFromList(currentlyDisplayedPilots)
        
        var pilotsToAddToTable = Set(currentlyDisplayedPilots)
        pilotsToAddToTable.subtract(formerlyDisplayedPilots)
        
        sectionIndex = 0
        var insertPaths = [IndexPath]()
        let insertSections = NSMutableIndexSet()
        for array in pilotNamesGroupedAlphabeticallyByInitial
        {
            var j = 0
            var insertPathsThisSection = [IndexPath]()
            for pilot in array
            {
                guard pilotsToAddToTable.contains(pilot) else {j += 1; continue}
                
                let insertPath = IndexPath(row: j, section:sectionIndex)
                insertPathsThisSection.append(insertPath)

                j += 1
            }
            
            if insertPathsThisSection.count == array.count
            {
                insertSections.add(sectionIndex)
            }
                
            else
            {
                insertPaths += insertPathsThisSection
            }
            sectionIndex += 1
        }
        
        tableView.beginUpdates()
        tableView.insertSections(insertSections as IndexSet, with: .fade)
        tableView.insertRows(at: insertPaths, with: .automatic)
        tableView.deleteSections(deleteSections as IndexSet, with: .fade)
        tableView.deleteRows(at: deletePaths, with: .automatic)
        tableView.endUpdates()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        searchBar.resignFirstResponder()
    }
    
    @IBAction func toggleInactivePilots()
    {
        showInactivePilots = !showInactivePilots
        searchBar(pilotSearchBar, textDidChange:pilotSearchBar.text!)
    }
    
    //MARK: - TableView Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard observerMode == false else {tableView.deselectRow(at: indexPath, animated: true); return}
        
        let pilot = pilotNamesGroupedAlphabeticallyByInitial[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        
        if pilot.signedIn == true
        {
            if dataModel.viewPreviousRecords
            {
                delegate?.createAttendanceRecordForPerson(pilot)
            }
                
            else
            {
                delegate?.signOutPerson(pilot)
            }
        }
            
        else
        {
            if pilot.inactive
            {
                pilot.inactive = false
            }
            
            delegate?.createAttendanceRecordForPerson(pilot)
        }
        
        dataModel.saveContext()
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return pilotNamesGroupedAlphabeticallyByInitial.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return pilotNamesGroupedAlphabeticallyByInitial[section].count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        return pilotNamesSectionTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PilotNameCell", for: indexPath)
        let pilot = pilotNamesGroupedAlphabeticallyByInitial[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        cell.textLabel?.text = pilot.fullName
        cell.detailTextLabel?.text = pilot.glidingCentre?.name
        cell.textLabel?.font = pilot.inactive == true ? UIFont.italicSystemFont(ofSize: 18) : UIFont.systemFont(ofSize: 18)
        
        if dataModel.viewPreviousRecords == true
        {
            let request = AttendanceRecord.request
            let midnightOnDateToViewRecords = dataModel.dateToViewRecords.midnight
            let oneDayLater = midnightOnDateToViewRecords + (60*60*24)
            request.predicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND pilot == %@", argumentArray: [midnightOnDateToViewRecords, oneDayLater, pilot])
            let attendanceRecordsFound = try! dataModel.managedObjectContext.count(for: request)
            cell.accessoryType = attendanceRecordsFound > 0 ? .checkmark : .none
        }
            
        else
        {
            cell.accessoryType = pilot.signedIn == true ? .checkmark : .none
            cell.textLabel?.textColor = pilot.inactive == true ? UIColor.red : UIColor.label
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {return false}
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        var allowedActions = [UIContextualAction]()
        rowDisplayingMenu = indexPath
        let pilot = pilotNamesGroupedAlphabeticallyByInitial[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        let pilotHasFlown = ((pilot.dualFlights.count > 0) || (pilot.picFlights.count > 0)) ? true : false

        switch (pilot.signedIn, pilotHasFlown)
        {
        case (false, true):
            let archiveButton = UIContextualAction(style: .destructive, title: "Archive"){_,_,_  in
                pilot.inactive = true
                dataModel.saveContext()
                self.updateListAfterChangeToPilot(pilot, atIndexPath: indexPath)
            }
            allowedActions.append(archiveButton)

        case (false, false):
            let deleteButton = UIContextualAction(style: .destructive, title: "Delete"){_,_,_  in
                
                dataModel.managedObjectContext.delete(pilot)
                cloudKitController?.deletePilot(pilot)
                dataModel.saveContext()
                self.updateListAfterChangeToPilot(pilot, atIndexPath: indexPath)
            }
            allowedActions.append(deleteButton)
            
        default:
            break
        }
        
        let viewButton = UIContextualAction(style: .normal, title: "View Info"){_,_,_  in
            self.performSegue(withIdentifier: "ViewPilotInfoSegue", sender:nil)
        }
        allowedActions.append(viewButton)

        return UISwipeActionsConfiguration(actions: allowedActions)
    }
    
    func updateListAfterChangeToPilot(_ pilot: Pilot, atIndexPath indexPath: IndexPath)
    {
        currentlyDisplayedPilots = getPilotsToDisplay()
        if currentlyDisplayedPilots.contains(pilot)
        {
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
            
        else
        {
            var letterArray = pilotNamesGroupedAlphabeticallyByInitial[(indexPath as NSIndexPath).section]
            letterArray.remove(at: (indexPath as NSIndexPath).row)
            
            if letterArray.count == 0
            {
                pilotNamesGroupedAlphabeticallyByInitial.remove(at: (indexPath as NSIndexPath).section)
                tableView.deleteSections(IndexSet(integer: (indexPath as NSIndexPath).section), with: .automatic)
            }
                
            else
            {
                pilotNamesGroupedAlphabeticallyByInitial[(indexPath as NSIndexPath).section] = letterArray
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {return true}
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath){}
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]?
    {
        return pilotNamesSectionTitles
    }
    
    //MARK: - Utility
    func organizeStaffNamesAlphabeticalSectionsFromList(_ list: [Pilot])
    {
        pilotNamesGroupedAlphabeticallyByInitial.removeAll(keepingCapacity: true)
        pilotNamesSectionTitles.removeAll(keepingCapacity: true)
        var i = 0
        var startOfSection = 0
        var previousFirstLetter = ""
        
        
        for pilot in list
        {
            if pilot.name == ""
            {
                i += 1
                startOfSection += 1
                continue
            }
            
            let firstLetterOfPilotName = String(pilot.name.prefix(1))
            
            if firstLetterOfPilotName.caseInsensitiveCompare(previousFirstLetter) != .orderedSame
            {
                if i > startOfSection
                {
                    pilotNamesGroupedAlphabeticallyByInitial.append(Array(list[startOfSection ... (i-1)]))
                    pilotNamesSectionTitles.append(previousFirstLetter)
                }
                
                previousFirstLetter = firstLetterOfPilotName
                startOfSection = i
            }
            
            i += 1
        }
        
        if i > startOfSection
        {
            pilotNamesGroupedAlphabeticallyByInitial.append(Array(list[startOfSection ... (i-1)]))
            pilotNamesSectionTitles.append(previousFirstLetter)
        }
    }
    
    func getPilotsToDisplay() -> [Pilot]
    {
        let pilotRequest = Pilot.request
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.name), ascending:true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
        pilotRequest.sortDescriptors = [nameSortDescriptor]
        let text = pilotSearchBar.text ?? ""
        
            if  pilotSearchBar.text?.count == 0
        {
            if showInactivePilots
            {
                pilotRequest.predicate = NSPredicate(format: "typeOfParticipant != %@ AND typeOfParticipant != %@", "guest", "cadet")
            }
                
            else
            {
                pilotRequest.predicate = NSPredicate(format: "typeOfParticipant != %@ AND typeOfParticipant != %@ AND inactive == NO", "guest", "cadet")
            }
            
        }
            
        else
        {
            if showInactivePilots
            {
                pilotRequest.predicate = NSPredicate(format: "typeOfParticipant != %@ AND typeOfParticipant != %@ AND (name BEGINSWITH[cd] %@ OR firstName BEGINSWITH[cd] %@ OR glidingCentre.name BEGINSWITH[cd] %@)", "guest", "cadet", text, text, text)
            }
                
            else
            {
                pilotRequest.predicate = NSPredicate(format: "typeOfParticipant != %@ AND typeOfParticipant != %@ AND inactive == NO AND (name BEGINSWITH[cd] %@ OR firstName BEGINSWITH[cd] %@ OR glidingCentre.name BEGINSWITH[cd] %@)", "guest", "cadet", text, text, text)
            }
        }
        
        return try! dataModel.managedObjectContext.fetch(pilotRequest) 
    }
    
    //MARK: - View Lifecycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        showInactivePilots = false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        currentlyDisplayedPilots = getPilotsToDisplay()
//        assignPilotsToMostRecentSiteFlown()
        organizeStaffNamesAlphabeticalSectionsFromList(currentlyDisplayedPilots)
        tableView.reloadData()
    }
    
    func assignPilotsToMostRecentSiteFlown()
    {
        for pilot in currentlyDisplayedPilots
        {
            let flightRequest = FlightRecord.request
            flightRequest.predicate = NSPredicate(format: "pilot == %@ OR passenger = %@", argumentArray: [pilot, pilot])
            flightRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: false)]
            let results = try! dataModel.managedObjectContext.fetch(flightRequest)
            
            if let mostRecentRecord = results.first
            {
                pilot.glidingCentre = mostRecentRecord.timesheet.glidingCentre
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        preferredContentSize = CGSize(width: 320, height: tableView.contentSize.height)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        resignFirstResponder()
        pilotSearchBar.resignFirstResponder()
    }
    
    enum SegueIdentifiers: String
    {
        case NewPilotSegue = "NewPilotSegue"
        case ViewPilotInfoSegue = "ViewPilotInfoSegue"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .NewPilotSegue:
            let newPilot = segue.destination as? EditPilotPopover
            let pilot = Pilot(context: dataModel.managedObjectContext)
            pilot.glidingCentre = dataModel.glidingCentre
            pilot.signedIn = false
            pilot.highestGliderQual = Int16(GliderQuals.noGlider.rawValue)
            pilot.highestScoutQual = Int16(TowplaneQuals.noScout.rawValue)
            pilot.typeOfParticipant = "Staff Cadet"
            pilot.name = ""
            newPilot?.pilot = pilot

        case .ViewPilotInfoSegue:
            let editPilot = segue.destination as? EditPilotPopover
            let pilot = pilotNamesGroupedAlphabeticallyByInitial[rowDisplayingMenu!.section][rowDisplayingMenu!.row]
            editPilot?.pilot = pilot
        }
    }
}
