//
//  PilotsController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-21.
//
//

import Foundation
import UIKit
import CoreData

final class PilotsController : UITableViewController, NSFetchedResultsControllerDelegate, UIPopoverPresentationControllerDelegate
{
    lazy var backgroundImage: UIImage = UIImage(assetIdentifier: .BlueCell)

    var addPilotButton: UIBarButtonItem?
    var previousRecordsViewer = false
    var gliderFetchController: NSFetchedResultsController<AttendanceRecord>!
    var towplaneFetchController: NSFetchedResultsController<AttendanceRecord>!
    var deletedSections = NSMutableIndexSet()
    var insertedSections = NSMutableIndexSet()
    var observerReferences = [NSObjectProtocol]()

    let gliderSectionHeaders = ["Level 4+ Cadet", "Level 3 Cadet", "Level 2 Cadet", "Level 1 Cadet", "Guest", "Student",  "Basic Glider Pilot",  "Front Seat Famil",  "Rear seat Famil", "Glider Instructor", "Glider Check Pilot", "Glider Standards Pilot"]
    let towplaneSectionHeaders = ["None", "Tow Pilot", "Tow Check Pilot", "Tow Standards Pilot"]

    enum SegueIdentifiers: String
    {
        case EditPilotSegue = "EditPilotSegue"
        case EditCadetNavigationControllerSegue = "EditCadetNavigationControllerSegue"
        case EditGuestNavigationControllerSegue = "EditGuestNavigationControllerSegue"
        case EditPersonNavigationControllerSegue = "EditPersonNavigationControllerSegue"
        case PilotActionSegue = "PilotActionSegue"
    }
    
    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        previousRecordsViewer = regularFormat && (navigationController != nil) && (self.tabBarController == nil) ? true : false
        
        observerReferences.append(NotificationCenter.default.addObserver(forName: reloadPilotNotification, object: nil, queue: OperationQueue.main, using: {note in self.updatePilot(note)}))
        observerReferences.append(NotificationCenter.default.addObserver(forName: recordsChangedNotification, object: nil, queue: OperationQueue.main, using: {note in self.updatePilot(note)}))
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadEverything), name: glidingSiteSelectedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadEverything), name: highestQualChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadEverything), name: nameChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadEverything), name: enterOrExitViewPreviousRecordsNotification, object: nil)

        
        if !previousRecordsViewer
        {
            dataModel.pilotAreaController = self
        }
        
        if self.tabBarController == nil
        {
            self.tableView.frame = CGRect(x: 0, y: 0, width: 544, height: 704)
        }
                
        if regularFormat == false
        {
            let tableBackgroundManager = BackgroundImage()
            let screenBound = UIScreen.main.bounds
            tableView.backgroundView = UIImageView(image: tableBackgroundManager.getBackground(screenBound.size))
        }
        
        self.configureFetchControllers()
    }
    
    deinit
    {
        for ref in observerReferences
        {
            NotificationCenter.default.removeObserver(ref)
        }
    }
    
    func configureFetchControllers()
    {
        let request = AttendanceRecord.request
        var predicate: NSPredicate
        
        if ((dataModel.viewPreviousRecords == true) && !regularFormat) || previousRecordsViewer
        {
            let midnightOnTargetDate = dataModel.dateToViewRecords.startOfDay
            let oneDayLater = midnightOnTargetDate + (60*60*24)
            predicate = NSPredicate(format: "timeIn >= %@ AND timeIn < %@ AND glidingCentre == %@ AND (pilot.highestScoutQual == 0 OR pilot.highestGliderQual > 0)", argumentArray: [midnightOnTargetDate, oneDayLater, dataModel.previousRecordsGlidingCentre ?? dataModel.glidingCentre!])
        }
            
        else
        {
            predicate = NSPredicate(format: "timeIn >= %@ AND timeOut == %@ AND glidingCentre == %@ AND (pilot.highestScoutQual == 0 OR pilot.highestGliderQual > 0)", argumentArray: [Date().startOfDay, Date.distantFuture, dataModel.glidingCentre])
        }
        
        request.predicate = predicate
        let gliderQualSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.highestGliderQual), ascending: false)
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.fullName), ascending: true)
        request.sortDescriptors = [gliderQualSortDescriptor, nameSortDescriptor]
        gliderFetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: "pilot.highestGliderQual", cacheName: nil)
        
        let request2 = AttendanceRecord.request
        var predicate2: NSPredicate
        
        if ((dataModel.viewPreviousRecords == true) && !regularFormat) || previousRecordsViewer
        {
            let midnightOnTargetDate = dataModel.dateToViewRecords.startOfDay
            let oneDayLater = midnightOnTargetDate + (60*60*24)
            predicate2 = NSPredicate(format: "timeIn >= %@ AND timeIn < %@ AND glidingCentre == %@ AND pilot.highestScoutQual > 0", argumentArray: [midnightOnTargetDate, oneDayLater, dataModel.previousRecordsGlidingCentre ?? dataModel.glidingCentre!])
        }
            
        else
        {
            predicate2 = NSPredicate(format: "timeIn >= %@ AND timeOut == %@ AND glidingCentre == %@ AND pilot.highestScoutQual > 0", argumentArray: [Date().startOfDay, Date.distantFuture, dataModel.glidingCentre])
        }
        
        request2.predicate = predicate2
        let scoutQualSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.highestScoutQual), ascending: false)
        request2.sortDescriptors = [scoutQualSortDescriptor, nameSortDescriptor]
        towplaneFetchController = NSFetchedResultsController(fetchRequest: request2, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: "pilot.highestScoutQual", cacheName: nil)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        let height = view.frame.size.height
        navigationController?.hidesBarsOnSwipe = height > 400 ? false : true
        navigationController?.navigationBar.tintColor = observerMode || trainingMode ? UIColor.red : nil
        
        navigationController?.tabBarItem.image = UIImage(assetIdentifier: .PersonOutline)
        navigationController?.tabBarItem.selectedImage = UIImage(assetIdentifier: .Person)
        
        gliderFetchController.delegate = self
        towplaneFetchController.delegate = self
        
        if previousRecordsViewer
        {
            dataModel.previousRecordsPilotsController = self
        }
            
        else
        {
            dataModel.pilotAreaController = self
        }
        
        let reloadNotification = Notification(name: highestQualChangedNotification, object: nil)
        NotificationQueue.default.enqueue(reloadNotification, postingStyle: .whenIdle)
        
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        gliderFetchController?.delegate = nil
        towplaneFetchController?.delegate = nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        let popoverPresentationController = segue.destination.popoverPresentationController
        popoverPresentationController?.delegate = self
        
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .EditPilotSegue:
            let record = getAttendanceRecordBasedOnIndexPath(tableView.indexPathForSelectedRow!)
            let pilot = record.pilot
            let editPilot = segue.destination as? EditPilotPopover
            editPilot?.pilot = pilot

        case .EditCadetNavigationControllerSegue, .EditGuestNavigationControllerSegue, .EditPersonNavigationControllerSegue:
            let editPilot = segue.destination as? EditPilotPopover
            editPilot?.pilot = sender as? Pilot
            
        case .PilotActionSegue:
            break
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return traitCollection.horizontalSizeClass == .compact ? .fullScreen : .none
    }
    
    //MARK: - UITableView Methods
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        guard let gliderSectionCount = gliderFetchController.sections?.count, let towplaneSectionCount = towplaneFetchController.sections?.count else {return 0}

        return gliderSectionCount + towplaneSectionCount
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        guard let gliderSectionCount = gliderFetchController.sections?.count else {return 0}

        if section < (gliderFetchController.sections?.count ?? 0)
        {
            return gliderFetchController.sections![section].numberOfObjects

        }
            
        else
        {
            let relativeSection = section - gliderSectionCount
            return towplaneFetchController.sections![relativeSection].numberOfObjects
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard let gliderSectionCount = gliderFetchController.sections?.count else {return nil}

        if section < gliderSectionCount
        {
            let indexOfTitle = gliderFetchController.sections![section].name.intValueWithNegatives + 4
            return gliderSectionHeaders[indexOfTitle]
        }
            
        else
        {
            let relativeSection = section - gliderSectionCount
            let indexOfTitle = towplaneFetchController.sections![relativeSection].name.intValueWithNegatives
            return towplaneSectionHeaders[indexOfTitle]
        }
    }
    
    func appropriateReuseIdentifierForCellOfWidth(_ width: Double, forGuest yesIfGuestNoIfPilot: Bool) -> String
    {
        var cellIdentifier: String
        
        switch (width, yesIfGuestNoIfPilot)
        {
        case (500...Double(Int.max), true):
            cellIdentifier = "GuestCellRegular"
            
        case (Double(Int.min)..<500, true):
            cellIdentifier = "GuestCellNarrow"
            
        case (Double(Int.min)..<500, false):
            cellIdentifier = "PilotCellNarrow"
            
        case (500..<700, false):
            cellIdentifier = "PilotCellRegular"
            
        case (700...Double(Int.max), false):
            cellIdentifier = "PilotCellWide"
            
        default:
            cellIdentifier = "PilotCellWide"
        }
        
        return cellIdentifier
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with:coordinator)
        
        if !regularFormat
        {
            let tableBackgroundManager = BackgroundImage()
            tableView.backgroundView = UIImageView(image: tableBackgroundManager.getBackground(size))
        }
        
        navigationController?.hidesBarsOnSwipe = size.height > 400 ? false : true
        var reloadCellsIsNecessary = false
        
        if tableView.numberOfSections > 0
        {
            guard let path = tableView.indexPathsForVisibleRows?[0] else {return}
            guard let cell = tableView.cellForRow(at: path) as? TableViewCellStylePilot else {return}
            let identifier = cell.reuseIdentifier
            let cadetOrGuest = cell.reuseIdentifier == "Guest" ? true : false
            let appropriateIdentifer = appropriateReuseIdentifierForCellOfWidth(Double(size.width), forGuest:cadetOrGuest)
            
            if appropriateIdentifer != identifier
            {
                reloadCellsIsNecessary = true
            }
        }
        
        if reloadCellsIsNecessary
        {
            tableView.reloadData()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let record = getAttendanceRecordBasedOnIndexPath(indexPath)
        let type: VehicleType = (indexPath as NSIndexPath).section < gliderFetchController.sections!.count ? .glider : .towplane
        let pilot = record.pilot!
        let picFlightsArray = pilot.sortedPICflights
        let dualFlightsArray = pilot.sortedDualFlights
        
        var midnightOnTargetDate: Date
        
        if ((dataModel.viewPreviousRecords == true) && !regularFormat) || previousRecordsViewer
        {
            midnightOnTargetDate = dataModel.dateToViewRecords.startOfDay as Date
        }
            
        else
        {
            midnightOnTargetDate = Date().startOfDay
        }
        
        let targetDatePicFlightsArray = pilot.sortedPICflightsForDate(midnightOnTargetDate)
        let targetDateDualFlightsArray = pilot.sortedDualFlightsForDate(midnightOnTargetDate)
        
        let cadetOrGuest = pilot.typeOfParticipant == "cadet" || pilot.typeOfParticipant == "guest" ? true : false
        let width = Double(tableView.frame.size.width)
        let cellIdentifier = appropriateReuseIdentifierForCellOfWidth(width, forGuest: cadetOrGuest)
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TableViewCellStylePilot else {return tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)}
        cell.accessoryType = .none
        if cell.backgroundView == nil
        {
            cell.backgroundView = UIImageView(image: backgroundImage)
        }
        
        cell.pilotName.text = width > 370 ? pilot.fullName : pilot.uniqueName
        cell.setPhoto(pilot.photoThumbnailImage as? UIImage)
        
        let bornToday = gregorian.isDateInToday(pilot.birthday)
        if bornToday
        {
            cell.setPhoto(UIImage(assetIdentifier: .Candles))
        }
        
        if cadetOrGuest
        {
            cell.squadronLabel?.isHidden = pilot.typeOfParticipant == "cadet" ? false : true
            cell.squadronNumber?.isHidden = pilot.typeOfParticipant == "cadet" ? false : true
            cell.squadronNumber?.text = String(Int((pilot.squadron)))
            cell.lifetimeFlightsLabel?.isHidden = pilot.typeOfParticipant == "cadet" ? false : true
            cell.lifetimeFlightsNumber?.isHidden = pilot.typeOfParticipant == "cadet" ? false : true
            cell.lifetimeFlightsNumber?.text = "\(pilot.dualFlights.count)"
        }
            
        else
        {
            let pilotIsInstructor = pilot.gliderQual > .rearSeatFamil ? true : false
            let medicalExpiry = type == .glider ? pilot.medical : pilot.powerMedicalExpiryDate
            
            cell.aviationMedicalValidity?.text = medicalExpiry.timeIntervalSinceNow < 0 ? "No" : "Yes"
            cell.aviationMedicalValidity?.textColor = medicalExpiry.timeIntervalSinceNow < 0 ? UIColor.red : UIColor.black
            cell.flightIsntructorRatingLabel?.isHidden = pilotIsInstructor && ((indexPath as NSIndexPath).section < gliderFetchController.sections!.count)  ? false : true
            cell.flightIsntructorRatingValidity?.isHidden = pilotIsInstructor && ((indexPath as NSIndexPath).section < gliderFetchController.sections!.count) ? false : true
            cell.flightIsntructorRatingValidity?.text = (pilot.fiExpiry.timeIntervalSinceNow < 0) ? "No" : "Yes"
            cell.flightIsntructorRatingValidity?.textColor = (pilot.fiExpiry.timeIntervalSinceNow < 0) ? UIColor.red : UIColor.black
            
            var picFlights = 0
            var picMinutes = 0.0
            
            for flightRecord in Array(targetDatePicFlightsArray.reversed())
            {
                if (flightRecord.timesheet == nil) || (flightRecord.timesheet.aircraft.type != type)
                {
                    continue
                }
                    
                else
                {
                    picFlights += 1
                    picMinutes += Double(flightRecord.flightLengthInMinutes)
                }
            }
            
            cell.PICflights?.text = picFlights == 1 ? "1 flight" : "\(picFlights) flights"
            let hourString = String(fromSeconds: picMinutes*60)
            cell.PIChours?.text = hourString == "1:00" ? "1:00 hour" : "\(hourString) hours"
            
            let currencyCalculationResults = pilot.calculateCurrencyDateOnType(type, withSortedPICflights:picFlightsArray, andDualFlights:dualFlightsArray)
            let currencyDate = currencyCalculationResults.canFlyUntilDate
            let APCexpiresBeforeCurrency = currencyCalculationResults.APCexpiresBeforeCurrency
            
            cell.currentUntilDate?.text = APCexpiresBeforeCurrency ? "\(currencyDate.militaryFormatShort) (APC)" : currencyDate.militaryFormatShort
            let tomorrow = Date(timeIntervalSinceNow: (24*60*60))
            cell.currentUntilDate?.textColor = UIColor.black
            if currencyDate.timeIntervalSince(tomorrow) < 0
            {
                cell.currentUntilDate?.textColor = UIColor.orange
            }
            
            if currencyDate.timeIntervalSince(Date()) < 0
            {
                cell.currentUntilDate?.textColor = UIColor.red
                cell.currentUntilDate?.text = APCexpiresBeforeCurrency ? "Expired APC" : "Expired"
            }
            
            if picFlights > 0
            {
                cell.accessoryType = .checkmark
            }
        }
        
        var dualFlights = 0
        var dualMinutes = 0.0
        
        for flightRecord in Array(targetDateDualFlightsArray.reversed())
        {
            if (flightRecord.timesheet == nil) || ((flightRecord.timesheet!.aircraft!.type != type) && (!cadetOrGuest))
            {
                continue
            }
                
            else
            {
                dualFlights += 1
                dualMinutes += Double(flightRecord.flightLengthInMinutes)
            }
        }
        
        cell.dualFlights?.text = dualFlights == 1 ? "1 flight" : "\(dualFlights) flights"
        let hourString = String(fromSeconds: dualMinutes*60)
        cell.dualHours?.text = hourString == "1:00" ? "1:00 hour" : "\(hourString) hours"
        
        if dualFlights > 0
        {
            cell.accessoryType = .checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let record = getAttendanceRecordBasedOnIndexPath(indexPath)
        let pilot = record.pilot!
        
        var editPersonNavController: UINavigationController
        switch pilot.typeOfParticipant
        {
        case "cadet":
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "EditCadetNavigationController") as? UINavigationController else {return}
            editPersonNavController = controller
        
        case "guest":
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "EditGuestNavigationController") as? UINavigationController else {return}
            editPersonNavController = controller

        default:
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "EditPersonNavigationController") as? UINavigationController else {return}
            editPersonNavController = controller
        }
        
        let editPilot = editPersonNavController.topViewController as? EditPilotPopover
        editPilot?.pilot = pilot
        
        var selectedPilotRect = tableView.rectForRow(at: indexPath)
        let screenWidth = UIScreen.main.bounds.size.width
        if screenWidth == selectedPilotRect.size.width
        {
            selectedPilotRect = CGRect(x: selectedPilotRect.origin.x, y: selectedPilotRect.origin.y, width: (selectedPilotRect.size.width - 350), height: selectedPilotRect.size.height)
        }
        
        editPersonNavController.modalPresentationStyle = .popover
        let presentationController = editPersonNavController.popoverPresentationController
        presentationController?.delegate = self
        present(editPersonNavController, animated:true, completion:nil)
        presentationController?.sourceView = tableView
        presentationController?.sourceRect = selectedPilotRect
        presentationController?.permittedArrowDirections = .left
        tableView.deselectRow(at: indexPath, animated:true)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        guard observerMode == false else {return false}
        
        switch (dataModel.viewPreviousRecords, regularFormat, previousRecordsViewer, dataModel.dateToViewRecords.isDateInToday)
        {
        case (true, false, _, false), (_, _, true, false):
            return true
            
        case (true, false, _, true), (_, _, true, true):
            return false
            
        default:
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        var allowedActions = [UITableViewRowAction]()
        let record = getAttendanceRecordBasedOnIndexPath(indexPath)
        let pilot = record.pilot!
        
        if dataModel.viewPreviousRecords
        {
            let beginningOfRecordDate = record.timeIn.startOfDay
            let picFlightsOnRecordDate = pilot.sortedPICflightsForDate(beginningOfRecordDate)
            let dualFlightsOnRecordDate = pilot.sortedDualFlightsForDate(beginningOfRecordDate)
            
            if picFlightsOnRecordDate.count > 0 || dualFlightsOnRecordDate.count > 0
            {
                let deleteButton = UITableViewRowAction(style: .default, title: "Delete"){_,_  in
                    let alertText = "\(pilot.name) flew on \(record.timeIn.militaryFormatShort) so the attendance record for that date cannot be deleted."
                    let cantDeleteRecordAlert = UIAlertController(title: "Unable to Delete Record", message: alertText, preferredStyle: .alert)
                    
                    let cancelButton = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                    cantDeleteRecordAlert.addAction(cancelButton)
                    self.present(cantDeleteRecordAlert, animated:true, completion:nil)
                }
                allowedActions.append(deleteButton)
            }
                
            else
            {
                let deleteButton = UITableViewRowAction(style: .default, title: "Delete"){_,_  in
                    cloudKitController?.deleteAttendanceRecord(record)
                    dataModel.managedObjectContext.delete(record)
                    dataModel.saveContext()
                }
                
                allowedActions.append(deleteButton)
            }
        }
            
        else
        {
            let cell = tableView.cellForRow(at: indexPath)!
            if (pilot.typeOfParticipant == "cadet") && (cell.accessoryType == .none)
            {
                let signOutButton = UITableViewRowAction(style: .normal, title: "Sign Out"){_,_  in
                    let title = "Sign Out \(pilot.fullName)?"
                    let message = "If you sign out squadron cadets their attendance and flights will still be reflected in the stats, but you cannot sign them back in. Are you sure this cadet is done flying?"
                    
                    let cadetDeleteAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    
                    let signOutButton = UIAlertAction(title: "Sign Out", style: .destructive){_ in
                        dataModel.signOutPerson(pilot)
                        dataModel.saveContext()
                    }
                    
                    cadetDeleteAlert.addAction(signOutButton)
                    cadetDeleteAlert.addAction(cancelButton)
                    self.present(cadetDeleteAlert, animated:true, completion:nil)
                }
                
                allowedActions.append(signOutButton)
                
                let deleteButton = UITableViewRowAction(style: .default, title: "Delete"){_,_  in
                    let title = "Delete \(pilot.fullName)?"
                    let message = "This will permanently delete \(pilot.name) as if they were never here. If you want \(pilot.name) to remain on the stats, cancel and use the Sign Out command instead."
                
                    let cadetDeleteAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    let deleteButton = UIAlertAction(title: "Delete", style: .destructive){_ in
                        if pilot.attendanceRecords.count > 1
                        {
                            cloudKitController?.deleteAttendanceRecord(record)
                            dataModel.managedObjectContext.delete(record)
                            dataModel.saveContext()
                        }
                        
                        else
                        {
                            cloudKitController?.deletePilot(pilot)
                            dataModel.managedObjectContext.delete(pilot)
                        }
                        
                        dataModel.saveContext()
                    }
                        
                    cadetDeleteAlert.addAction(deleteButton)
                    cadetDeleteAlert.addAction(cancelButton)
                
                    self.present(cadetDeleteAlert, animated:true, completion:nil)
                }
                allowedActions.append(deleteButton)
            }
            
            else
            {
                let signOutButton = UITableViewRowAction(style: .normal, title: "Sign Out"){_,_  in
                    dataModel.signOutPerson(pilot)
                    dataModel.saveContext()
                }
                allowedActions.append(signOutButton)
            }
        }
        
        return allowedActions
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath){}
    
    //MARK: - Fetched Results Controller
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        deletedSections.removeAllIndexes()
        insertedSections.removeAllIndexes()
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        if controller === gliderFetchController
        {
            switch type
            {
            case .insert:
                guard let newIndexPath = newIndexPath else {return}
                tableView.insertRows(at: [newIndexPath], with: .fade)
                
            case .delete:
                guard let indexPath = indexPath else {return}
                tableView.deleteRows(at: [indexPath], with: .fade)
                
            case .update:
                break
                
            case .move:
                guard let indexPath = indexPath, let newIndexPath = newIndexPath else {return}
                if !deletedSections.contains((indexPath as NSIndexPath).section) && !insertedSections.contains((newIndexPath as NSIndexPath).section)
                {
                    tableView.moveRow(at: indexPath, to:newIndexPath)
                }
                    
                else
                {
                    if deletedSections.contains((indexPath as NSIndexPath).section)
                    {
                        tableView.insertRows(at: [newIndexPath], with: .fade)
                    }
                        
                    else
                    {
                        tableView.deleteRows(at: [indexPath], with: .fade)
                    }
                }
            }
        }
            
        else
        {
            var relativeIndexPath: IndexPath?
            if let indexPath = indexPath
            {
                relativeIndexPath = IndexPath(row: (indexPath as NSIndexPath).row, section: ((indexPath as NSIndexPath).section + gliderFetchController.sections!.count))
            }
            
            var relativeNewIndexPath: IndexPath?
            if let newIndexPath = newIndexPath
            {
                relativeNewIndexPath = IndexPath(row: (newIndexPath as NSIndexPath).row, section: ((newIndexPath as NSIndexPath).section + gliderFetchController.sections!.count))
            }
            
            switch type
            {
            case .insert:
                guard let relativeNewIndexPath = relativeNewIndexPath else {return}
                tableView.insertRows(at: [relativeNewIndexPath], with: .fade)
                
            case .delete:
                guard let relativeIndexPath = relativeIndexPath else {return}
                tableView.deleteRows(at: [relativeIndexPath], with: .fade)
                
            case .update:
                break
                
            case .move:
                guard let relativeIndexPath = relativeIndexPath, let relativeNewIndexPath = relativeNewIndexPath else {return}

                if !deletedSections.contains((relativeIndexPath as NSIndexPath).section) && !insertedSections.contains((relativeNewIndexPath as NSIndexPath).section)
                {
                    tableView.moveRow(at: relativeIndexPath, to: relativeNewIndexPath)
                }
                    
                else
                {
                    if deletedSections.contains((relativeIndexPath as NSIndexPath).section)
                    {
                        tableView.insertRows(at: [relativeNewIndexPath], with: .fade)
                    }
                        
                    else
                    {
                        tableView.deleteRows(at: [relativeIndexPath], with: .fade)
                    }
                }
            }
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType)
    {
        if controller === gliderFetchController
        {
            switch type
            {
            case .insert:
                tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
                insertedSections.add(sectionIndex)
                
            case .delete:
                tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
                deletedSections.add(sectionIndex)
                
            default:
                break
            }
        }
            
        else
        {
            let relativeSectionIndex = gliderFetchController.sections!.count + sectionIndex
            
            switch type
            {
            case .insert:
                tableView.insertSections(IndexSet(integer: relativeSectionIndex), with: .fade)
                insertedSections.add(relativeSectionIndex)
                
            case .delete:
                tableView.deleteSections(IndexSet(integer: relativeSectionIndex), with: .fade)
                deletedSections.add(relativeSectionIndex)
                
            default:
                break
            }
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        tableView.endUpdates()
    }
    
    //MARK: - Utility
    
    func getAttendanceRecordBasedOnIndexPath(_ path: IndexPath) -> AttendanceRecord
    {
        var record: AttendanceRecord
        let section = (path as NSIndexPath).section
        let row = (path as NSIndexPath).row
        
        if section < (gliderFetchController.sections?.count)!
        {
            record = gliderFetchController.object(at: path) 
        }
            
        else
        {
            let relativeSection = section - (gliderFetchController.sections?.count ?? 0)
            let path = IndexPath(row: row, section: relativeSection)
            record = towplaneFetchController.object(at: path)
        }
        
        return record
    }
    
    func updatePilot(_ note: Notification)
    {
        if let pilot = note.object as? Pilot
        {
            var gliderIndexPath: IndexPath?
            var towplaneIndexPath: IndexPath?
            
            for record in gliderFetchController.fetchedObjects ?? [AttendanceRecord]()
            {
                if record.pilot === pilot
                {
                    gliderIndexPath = gliderFetchController.indexPath(forObject: record)
                    break
                }
            }
            
            for record in towplaneFetchController.fetchedObjects ?? [AttendanceRecord]()
            {
                if record.pilot === pilot
                {
                    if let path = towplaneFetchController.indexPath(forObject: record)
                    {
                        towplaneIndexPath = IndexPath(row: (path as NSIndexPath).row, section: (path as NSIndexPath).section + (gliderFetchController.sections?.count ?? 0))
                        break
                    }
                }
            }
            
            var pathsToReload = [IndexPath]()
            
            if gliderIndexPath != nil
            {
                pathsToReload.append(gliderIndexPath!)
            }
            
            if towplaneIndexPath != nil
            {
                pathsToReload.append(towplaneIndexPath!)
            }
            
            tableView.reloadRows(at: pathsToReload, with: .none)
        }
    }
    
    func signOutFlight(_ flight: String)
    {
        var pilotsToSignOut = Set<Pilot>()
        
        for record in gliderFetchController.fetchedObjects ?? [AttendanceRecord]()
        {
            if let summerFlight = record.pilot.summerUnit
            {
                if summerFlight.name == flight
                {
                    pilotsToSignOut.insert(record.pilot)
                }
            }
        }
        
        for record in towplaneFetchController.fetchedObjects ?? [AttendanceRecord]()
        {
            if let summerFlight = record.pilot.summerUnit
            {
                if summerFlight.name == flight
                {
                    pilotsToSignOut.insert(record.pilot)
                }
            }
        }
        
        for pilot in pilotsToSignOut
        {
            dataModel.signOutPerson(pilot)
        }
        
        dataModel.saveContext()
    }
    
    func signOutSquadronCadets()
    {
        var cadetsToSignOut = Set<Pilot>()

        for record in gliderFetchController.fetchedObjects ?? [AttendanceRecord]()
        {
            if record.pilot.typeOfParticipant == "cadet"
            {
                cadetsToSignOut.insert(record.pilot)
            }
        }
        
        for cadet in cadetsToSignOut
        {
            dataModel.signOutPerson(cadet)
        }
        
        dataModel.saveContext()
    }
    
    //MARK: - Responding to Buttons
    @objc func reloadEverything()
    {
        if previousRecordsViewer
        {
            parent?.title = dataModel.dateToViewRecords.militaryFormatLong
        }
        
        guard let _ = dataModel.glidingCentre else {return}
        
        configureFetchControllers()
        gliderFetchController.delegate = self
        towplaneFetchController.delegate = self
        
        try! gliderFetchController.performFetch()
        try! towplaneFetchController.performFetch()
        
        tableView.reloadData()
    }
}
