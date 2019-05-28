//
//  Records.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-20.
//
//

import Foundation
import UIKit
import CoreData

final class Records: UITableViewController, NSFetchedResultsControllerDelegate, UIPopoverPresentationControllerDelegate
{
    @IBOutlet var sortButton: UIBarButtonItem?
    var sortMethod: UISegmentedControl?
    var fetchController: NSFetchedResultsController<FlightRecord>!
    lazy var gliderRecordBackground: UIImage = UIImage(assetIdentifier: .YellowCell)
    lazy var scoutRecordBackground: UIImage = UIImage(assetIdentifier: .BlueCell)
    lazy var winchRecordBackground: UIImage = UIImage(assetIdentifier: .GreenCell)
    lazy var autoRecordBackground: UIImage = UIImage(assetIdentifier: .RedCell)
    
    var positionedAtBottom = false
    var shouldScrollToBottom = false
    var previousRecordsViewer = false
    var recordEdited: IndexPath!
    var sortDescriptorArray = [NSSortDescriptor]()
    var pathsToUpdate = Set<IndexPath>()
    var mainSortMethod = RecordSortAttribute.timeUp
    let deletedSections = NSMutableIndexSet()
    let insertedSections = NSMutableIndexSet()
    var selfReference: NSObjectProtocol?
    
    enum SegueIdentifiers: String
    {
        case EditRecordSegue = "EditRecordSegue"
        case EditOldRecordSegue = "EditOldRecordSegue"
        case RecordOptionsSegue = "RecordOptionsSegue"
    }
    
    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        selfReference = NotificationCenter.default.addObserver(forName: nameChangedNotification, object: nil, queue: OperationQueue.main, using: {note in self.reloadRecordsForPilot(note)})
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: refreshEverythingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: glidingSiteSelectedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: enterOrExitViewPreviousRecordsNotification, object: nil)

        self.tableView.rowHeight = UITableView.automaticDimension
        previousRecordsViewer = (regularFormat && (navigationController != nil)) ? true : false
        
        if !regularFormat
        {
            let backgroundImage = BackgroundImage()
            let screenBound = UIScreen.main.bounds
            tableView.backgroundView = UIImageView(image: backgroundImage.getBackground(screenBound.size))
        }
        
        if previousRecordsViewer
        {
            dataModel.previousRecordsGlidingCentre = dataModel.glidingCentre
        }
            
        else
        {
            dataModel.recordAreaController = self
        }
        
        let request = FlightRecord.request
        var predicate: NSPredicate
        
        if ((dataModel.viewPreviousRecords == true) && !regularFormat) || previousRecordsViewer
        {
            let midnightOnTargetDate = dataModel.dateToViewRecords.startOfDay
            let oneDayLater = midnightOnTargetDate + (60*60*24)
            predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.glidingCentre == %@", argumentArray: [midnightOnTargetDate, oneDayLater, dataModel.previousRecordsGlidingCentre!])
        }
            
        else
        {
            predicate = NSPredicate(format: "timeUp > %@ AND timesheet.glidingCentre == %@", argumentArray: [Date().startOfDay, dataModel.glidingCentre!])
        }
        
        request.predicate = predicate
        configureSortDescriptorArray()
        request.sortDescriptors = sortDescriptorArray
        
        var sectionNameKeyPath: String?
        
        switch mainSortMethod
        {
        case .tailNumber, .pilot, .sequence:
            sectionNameKeyPath = request.sortDescriptors![0].key

        case .passenger:
            sectionNameKeyPath = #keyPath(FlightRecord.sectionTitleWhenSortedByPassenger)

        case .connectedAircraft:
            sectionNameKeyPath = #keyPath(FlightRecord.sectionTitleWhenSortedByConnectedAircraft)
            
        default:
            break
        }
        
        self.fetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with:coordinator)
        
        if !regularFormat
        {
            let backgroundImage = BackgroundImage()
            tableView.backgroundView = UIImageView(image: backgroundImage.getBackground(size))
        }
        
        navigationController?.hidesBarsOnSwipe = size.height > 400 ? false : true
        tableView.estimatedRowHeight = size.width < 500 ? 46 : 33
        tableView.reloadData()
    }

    deinit
    {
        guard let reference = selfReference else {return}
        NotificationCenter.default.removeObserver(reference)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        let height = Double(view.frame.size.height)
        navigationController?.hidesBarsOnSwipe = height > 400 ? false : true
        tableView.estimatedRowHeight = view.frame.size.width < 500 ? 46 : 33
        
        navigationController?.navigationBar.tintColor = observerMode || trainingMode ? UIColor.red : nil
        sortMethod?.tintColor = observerMode || trainingMode ? UIColor.red : nil
        fetchController.delegate = self
        
        if previousRecordsViewer
        {
            parent?.title = dataModel.dateToViewRecords.militaryFormatLong
            dataModel.previousRecordsController = self
        }
            
        else
        {
            dataModel.recordAreaController = self
        }
        
        configureSortDescriptorArray()
        sortMethod?.selectedSegmentIndex = mainSortMethod.rawValue
        sortRecords(mainSortMethod.rawValue)
        tableView.reloadData()
    }
    
    func sortRecords(_ selectedSegment: Int)
    {
        mainSortMethod = RecordSortAttribute(rawValue: selectedSegment) ?? RecordSortAttribute.timeUp
        
        let request = fetchController.fetchRequest
        var newSortDescriptors = request.sortDescriptors ?? [NSSortDescriptor]()
        var key: String
        
        switch mainSortMethod
        {
        case .tailNumber:
            key = #keyPath(FlightRecord.timesheet.aircraft.tailNumber)
            
        case .pilot:
            key = #keyPath(FlightRecord.pilot.fullName)
            
        case .passenger:
            key = #keyPath(FlightRecord.passenger.fullName)
            
        case .connectedAircraft:
            key = #keyPath(FlightRecord.connectedAircraftRecord.timesheet.aircraft.tailNumber)
            
        case .sequence:
            key = #keyPath(FlightRecord.flightSequence)
            
        case .timeUp:
            key = #keyPath(FlightRecord.timeUp)
            
        case .timeDown:
            key = #keyPath(FlightRecord.timeDown)
            
        case .flightTime:
            key = #keyPath(FlightRecord.flightLengthInMinutes)
        }
        
        var index = 0
        for descriptor in newSortDescriptors
        {
            if descriptor.key == key
            {
                break
            }
            index += 1
        }
        
        let primarySortDescriptor = newSortDescriptors[index]
        newSortDescriptors.remove(at: index)
        newSortDescriptors.insert(primarySortDescriptor, at: 0)
        request.sortDescriptors = newSortDescriptors
        var sectionNameKeyPath: String?
        
        switch mainSortMethod
        {
        case .tailNumber, .pilot, .sequence:
            sectionNameKeyPath = request.sortDescriptors![0].key
            
        case .passenger:
            sectionNameKeyPath = "sectionTitleWhenSortedByPassenger"
            
        case .connectedAircraft:
            sectionNameKeyPath = "sectionTitleWhenSortedByConnectedAircraft"
            
        default:
            break
        }
        
        fetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        
        fetchController.delegate = self
        try! fetchController.performFetch()
        tableView.reloadData()
        
        if previousRecordsViewer
        {
            sortDescriptorArray = newSortDescriptors
        }
            
        else
        {
            var savedSortDescriptorKeys = [String]()
            for descriptor in newSortDescriptors
            {
                savedSortDescriptorKeys.append(descriptor.key!)
            }
            
            dataModel.preferences["sortDescriptorArray"] = savedSortDescriptorKeys as NSArray
            dataModel.preferences["selectedSortMethod"] = selectedSegment as NSNumber
            dataModel.save()
            configureSortDescriptorArray()
        }
        
        self.fetchController.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        fetchController.delegate = nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        let popoverPresentationController = segue.destination.popoverPresentationController
        popoverPresentationController?.delegate = self
        
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .EditRecordSegue, .EditOldRecordSegue:
            let recordEditor = segue.destination as? EditRecordPopover
            if let path = tableView.indexPathForSelectedRow
            {
                let record = fetchController.object(at: path)
                recordEditor?.record = record
                recordEditor?.indexPathBeingEdited = path
            }
            
        case .RecordOptionsSegue:
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
        return self.fetchController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        
        
        
        
        
        
        
//        #warning("Delete this!")
//
//
//
//
//        func createRandomFlightForType(_ type: VehicleType, record: FlightRecord? = nil)
//        {
//            let pilots = dataModel.glidingCentre.pilots
//
//            func newTimeSheetForAircraft(_ ac: AircraftEntity) -> AircraftTimesheet
//            {
//                let newTimesheet = AircraftTimesheet(context: dataModel.managedObjectContext)
//                newTimesheet.date = dataModel.dateToViewRecords.startOfDay + 60*60*23
//                newTimesheet.aircraft = ac
//                newTimesheet.glidingCentre = dataModel.previousRecordsGlidingCentre
//                newTimesheet.setTTSN()
//
//                return newTimesheet
//            }
//
//            func randomTowplane() -> AircraftEntity?
//            {
//                for aircraft in dataModel.glidingCentre.aircraft
//                {
//                    if aircraft.type == .towplane
//                    {
//                        return aircraft
//                    }
//                }
//
//                return nil
//            }
//
//            func randomGlider() -> AircraftEntity?
//            {
//                for aircraft in dataModel.glidingCentre.aircraft
//                {
//                    if aircraft.type == .glider
//                    {
//                        return aircraft
//                    }
//                }
//
//                return nil
//            }
//
//            func randomWinch() -> AircraftEntity?
//            {
//                for aircraft in dataModel.glidingCentre.aircraft
//                {
//                    if aircraft.type == .winch
//                    {
//                        return aircraft
//                    }
//                }
//
//                return nil
//            }
//
//            func randomAuto() -> AircraftEntity?
//            {
//                for aircraft in dataModel.glidingCentre.aircraft
//                {
//                    if aircraft.type == .auto
//                    {
//                        return aircraft
//                    }
//                }
//
//                return nil
//            }
//
//            func throwAlert(forType type: VehicleType)
//            {
//                let alert = UIAlertController(title:"No Vehicle Available", message:"You must have at least one \(type) signed in to \(dataModel.previousRecordsGlidingCentre?.name ?? dataModel.glidingCentre.name) before you can add a \(type) flight.", preferredStyle:.alert)
//                let done = UIAlertAction(title: "OK", style: .default, handler:nil)
//                alert.addAction(done)
//                self.present(alert, animated:true, completion:nil)
//            }
//
//            func throwAlertForMissingPilot()
//            {
//                let alert = UIAlertController(title:"No Pilot Available", message:"You must have at least one pilot signed in to \(dataModel.previousRecordsGlidingCentre?.name ?? dataModel.glidingCentre.name) before you can add flight.", preferredStyle:.alert)
//                let done = UIAlertAction(title: "OK", style: .default, handler:nil)
//                alert.addAction(done)
//                self.present(alert, animated:true, completion:nil)
//            }
//
//            guard let randomPilot = pilots.first else {throwAlertForMissingPilot(); return}
//
//            switch type
//            {
//            case .towplane:
//                guard let aircraft = randomTowplane() else {throwAlert(forType: .towplane); return}
//                let timesheet = newTimeSheetForAircraft(aircraft)
//                let record = FlightRecord(context: dataModel.managedObjectContext)
//                record.flightSequence = aircraft.flightSequence
//                record.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
//                record.timeDown = record.timeUp + 60
//                record.pilot = randomPilot
//                record.picParticipantType = record.pilot.typeOfParticipant
//                record.timesheet = timesheet
//                timesheet.logInsertionOf(record: record)
//
//            case .glider:
//                guard let towaircraft = randomTowplane() else {throwAlert(forType: .towplane); return}
//                let towTimesheet = newTimeSheetForAircraft(towaircraft)
//
//                guard let glider = randomGlider() else {throwAlert(forType: .glider); return}
//                let gliderTimesheet = newTimeSheetForAircraft(glider)
//                let towRecord = FlightRecord(context: dataModel.managedObjectContext)
//
//                towRecord.flightSequence = "Towing"
//                towRecord.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
//                towRecord.timeDown = towRecord.timeUp + 60
//                towRecord.pilot = randomPilot
//                towRecord.picParticipantType = towRecord.pilot.typeOfParticipant
//                towRecord.timesheet = towTimesheet
//                towTimesheet.logInsertionOf(record: towRecord)
//
//                if let gliderRecord = record
//                {
//                    towRecord.timeUp = gliderRecord.timeUp
//                    towRecord.timeDown = gliderRecord.timeUp + 7
//                    towRecord.flightLengthInMinutes = 7
//                    gliderRecord.connectedAircraftRecord = towRecord
//                }
//
//                else
//                {
//                    let gliderRecord = FlightRecord(context: dataModel.managedObjectContext)
//                    gliderRecord.aircraft = glider
//                    gliderRecord.flightSequence = glider.flightSequence
//                    gliderRecord.timeUp = towRecord.timeUp
//                    gliderRecord.timeDown = towRecord.timeDown
//                    gliderRecord.pilot = randomPilot
//                    gliderRecord.picParticipantType = randomPilot.typeOfParticipant
//                    gliderRecord.timesheet = gliderTimesheet
//                    gliderRecord.connectedAircraftRecord = towRecord
//                    gliderTimesheet.logInsertionOf(record: gliderRecord)
//                }
//
//            case .auto:
//                guard let auto = randomAuto()  else {throwAlert(forType: .auto); return}
//                let autoTimesheet = newTimeSheetForAircraft(auto)
//
//                guard let glider = randomGlider()  else {throwAlert(forType: .glider); return}
//                let gliderTimesheet = newTimeSheetForAircraft(glider)
//
//                let towRecord = FlightRecord(context: dataModel.managedObjectContext)
//                towRecord.flightSequence = "Towing"
//                towRecord.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
//                towRecord.timeDown = towRecord.timeUp + 60
//                towRecord.pilot = randomPilot
//                towRecord.picParticipantType = towRecord.pilot.typeOfParticipant
//                towRecord.timesheet = autoTimesheet
//                autoTimesheet.logInsertionOf(record: towRecord)
//
//                let gliderRecord = FlightRecord(context: dataModel.managedObjectContext)
//                gliderRecord.aircraft = glider
//                gliderRecord.flightSequence = glider.flightSequence
//                gliderRecord.timeUp = towRecord.timeUp
//                gliderRecord.timeDown = towRecord.timeDown
//                gliderRecord.pilot = randomPilot
//                gliderRecord.picParticipantType = randomPilot.typeOfParticipant
//                gliderRecord.timesheet = gliderTimesheet
//                gliderRecord.connectedAircraftRecord = towRecord
//                gliderTimesheet.logInsertionOf(record: gliderRecord)
//
//            case .winch:
//                guard let winch = randomWinch()  else {throwAlert(forType: .winch); return}
//                let winchTimesheet = newTimeSheetForAircraft(winch)
//
//                guard let glider = randomGlider()  else {throwAlert(forType: .glider); return}
//                let gliderTimesheet = newTimeSheetForAircraft(glider)
//
//                let towRecord = FlightRecord(context: dataModel.managedObjectContext)
//                towRecord.flightSequence = "Towing"
//                towRecord.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
//                towRecord.timeDown = towRecord.timeUp + 60
//                towRecord.pilot = randomPilot
//                towRecord.picParticipantType = towRecord.pilot.typeOfParticipant
//                towRecord.timesheet = winchTimesheet
//                winchTimesheet.logInsertionOf(record: towRecord)
//
//                let gliderRecord = FlightRecord(context: dataModel.managedObjectContext)
//                gliderRecord.aircraft = glider
//                gliderRecord.flightSequence = glider.flightSequence
//                gliderRecord.timeUp = towRecord.timeUp
//                gliderRecord.timeDown = towRecord.timeDown
//                gliderRecord.pilot = randomPilot
//                gliderRecord.picParticipantType = randomPilot.typeOfParticipant
//                gliderRecord.timesheet = gliderTimesheet
//                gliderRecord.connectedAircraftRecord = towRecord
//                gliderTimesheet.logInsertionOf(record: gliderRecord)
//            }
//
//            dataModel.saveContext()
//        }
//
//
        
        
        
        
        
        
        
        
        
        
        
        
        
        guard observerMode == false else {tableView.deselectRow(at: indexPath, animated: true); return}
        
        let record = fetchController.object(at: indexPath)
        
//        #warning("Delete this")
//        if record.timesheet.aircraft.type == .glider
//        {
//            if record.connectedAircraftRecord == nil
//            {
//                createRandomFlightForType(.glider, record: record)
//            }
//        }
        
        
        let editAllowed = record.timeDown == Date.distantFuture ? false : true
        guard editAllowed else {return}
        
        let editRecordNavController = storyboard?.instantiateViewController(withIdentifier: "EditRecordNavigationController") as? UINavigationController
        let recordEditor = editRecordNavController?.topViewController as? EditRecordPopover
        
        recordEdited = indexPath
        recordEditor?.record = record
        recordEditor?.indexPathBeingEdited = recordEdited
        
        var selectedRecordRect = tableView.rectForRow(at: indexPath)
        let screenWidth = UIScreen.main.bounds.size.width
        if screenWidth == selectedRecordRect.size.width
        {
            selectedRecordRect = CGRect(x: selectedRecordRect.origin.x, y: selectedRecordRect.origin.y, width: (selectedRecordRect.size.width - 350), height: selectedRecordRect.size.height)
        }
        
        editRecordNavController?.modalPresentationStyle = .popover
        let presentationController = editRecordNavController?.popoverPresentationController
        presentationController?.delegate = self

        present(editRecordNavController!, animated:true, completion:nil)
        if let presentationController = editRecordNavController?.popoverPresentationController
        {
            presentationController.sourceView = tableView
            presentationController.sourceRect = selectedRecordRect
            presentationController.permittedArrowDirections = .left
        }
        tableView.deselectRow(at: indexPath, animated:true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let record = fetchController.object(at: indexPath)
        guard let recordCell = cell as? TableViewCellStyleRecord else {return}

        switch record.timesheet.aircraft.type
        {
        case .glider:
            recordCell.setBackgroundToColor(.yellow, withImage: gliderRecordBackground)

        case .towplane:
            recordCell.setBackgroundToColor(.defaultColor, withImage: scoutRecordBackground)

        case .winch:
            recordCell.setBackgroundToColor(.green, withImage: winchRecordBackground)

        case .auto:
            recordCell.setBackgroundToColor(.red, withImage: autoRecordBackground)
        }
    }
    
    func appropriateReuseIdentifierForCellOfWidth(_ width: Double) -> String
    {
        var cellIdentifier: String
        
        switch width
        {
        case Double(Int.min) ..< 500:
            cellIdentifier = "RecordCellNarrow"
            
        case 500 ..< 700:
            cellIdentifier = "RecordCellRegular"
            
        default:
            cellIdentifier = "RecordCellWide"
        }
        
        return cellIdentifier
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cellIdentifier = appropriateReuseIdentifierForCellOfWidth(Double(tableView.frame.size.width))
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        configureCell(cell, atIndexPath:indexPath)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
//        #warning("Delete This")
//        return true
        
        
        guard observerMode == false else {return false}
        
        let record = fetchController.object(at: indexPath)
        var editAllowed = record.timeDown == Date.distantFuture ? false : true
        
        if editAllowed
        {
            if let connectedAircraftRecord = record.connectedAircraftRecord
            {
                editAllowed = connectedAircraftRecord.timeDown == Date.distantFuture ? false : true
            }
        }
        
        if (dataModel.viewPreviousRecords == true) && (Date() - record.timeDown > 60*60*24*360)
        {
            editAllowed = false
        }
        
        if record.timeDown == Date.distantFuture && record.aircraft == nil
        {
            editAllowed = true
        }
        
        return editAllowed
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            let record = fetchController.object(at: indexPath)
            
            if record.timeUp < Date().midnight && dataModel.editorSignInTime < Date() - 30*60
            {
                let title = "Sign In"
                let message = "You must sign in to edit records from prior days. Your license number will be logged on all edits taking place in the next half hour."
                let signInAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                signInAlert.addAction(cancelAction)
                
                let proceedAction = UIAlertAction(title: "Login", style: .default){_ in
                    guard let name = signInAlert.textFields?.first?.text, name.count > 0 else {return}
                    guard let license = signInAlert.textFields?.last?.text, license.count > 3 else {return}
                    dataModel.editorName = name
                    dataModel.editorLicense = license
                    dataModel.editorSignInTime = Date()
                    self.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
                }
                
                signInAlert.addAction(proceedAction)
                signInAlert.addTextField(){textField in textField.placeholder = "Name"}
                signInAlert.addTextField(){textField in textField.placeholder = "License Number"}
                
                present(signInAlert, animated: true)
                return
            }
            
            if let connectedAircraftRecord = record.connectedAircraftRecord
            {
                recordEdited = indexPath
                var message: String
                let aircraftName = record.timesheet.aircraft.tailNumber
                let connectedAircraftName = connectedAircraftRecord.timesheet.aircraft.tailNumber
                
                if record.timesheet.aircraft.type == .glider
                {
                    message = "Deleting this record for \(aircraftName) will also delete the record that shows \(connectedAircraftName) launching \(aircraftName)."
                }
                    
                else
                {
                    message = "Deleting this record for \(aircraftName) will also delete the record that shows \(connectedAircraftName) being launched by \(aircraftName)."
                }
                
                let deleteWarning = UIAlertController(title: "Warning!", message: message, preferredStyle: .alert)
                let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                let deleteButton = UIAlertAction(title: "Delete Both", style: .destructive) {_ in
                    let record = self.fetchController.object(at: self.recordEdited)
                    let recordsAircraft = record.timesheet.aircraft!
                    let recordsConnectedAircraft = connectedAircraftRecord.timesheet.aircraft!
                    record.timesheet.logDeletionOf(record: record)
                    connectedAircraftRecord.timesheet.logDeletionOf(record: connectedAircraftRecord)
                    cloudKitController?.deleteFlightRecord(connectedAircraftRecord)
                    dataModel.managedObjectContext.delete(connectedAircraftRecord)
                    cloudKitController?.deleteFlightRecord(record)
                    dataModel.managedObjectContext.delete(record)

                    if recordsConnectedAircraft.type != .winch
                    {
                        recordsAircraft.updateTTSN()
                    }
                    
                    if recordsAircraft.type != .winch
                    {
                        recordsAircraft.updateTTSN()
                    }
                    
                    dataModel.saveContext()
                    
                    NotificationCenter.default.post(name: aircraftChangedNotification, object:recordsConnectedAircraft, userInfo:nil)
                    NotificationCenter.default.post(name: aircraftChangedNotification, object:recordsAircraft, userInfo:nil)
                }
                
                deleteWarning.addAction(deleteButton)
                deleteWarning.addAction(cancelButton)
                
                present(deleteWarning, animated:true, completion:nil)
            }
                
            else
            {
                let recordsAircraft = record.timesheet.aircraft!

                record.timesheet.logDeletionOf(record: record)
                cloudKitController?.deleteFlightRecord(record)
                dataModel.managedObjectContext.delete(record)
                
                if recordsAircraft.type != .winch
                {
                    recordsAircraft.updateTTSN()
                }
                
                dataModel.saveContext()
                NotificationCenter.default.post(name: aircraftChangedNotification, object:recordsAircraft, userInfo:nil)
                return
            }
        }
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath)
    {
        let record = fetchController.object(at: indexPath)
        
        let editAllowed = record.timeDown == Date.distantFuture ? false : true
        cell.selectionStyle = editAllowed ? .default : .none
        guard let recordCell = cell as? TableViewCellStyleRecord else {return}
        
        recordCell.aircraftName?.text = record.timesheet.aircraft.tailNumber
        let width = tableView.frame.size.width
        recordCell.PICname.text = width > 370 ? record.pilot?.fullName : record.pilot?.uniqueName
        recordCell.passengerName.text = width > 370 ? record.passenger?.fullName : record.passenger?.uniqueName
        recordCell.connectedAircraftName?.text = record.connectedAircraftRecord?.timesheet?.aircraft?.tailNumber
        
        recordCell.sequenceName.text = record.flightSequence
        if record.flightSequence == "Transit"
        {
            recordCell.sequenceName.text = record.transitRoute
        }
        
        let upTime = record.timeUp.hoursAndMinutes
        if record.timesheet.aircraft.type > .winch
        {
            let downTime = record.timeDown == Date.distantFuture ? " ?" : record.timeDown.hoursAndMinutes
            let upAndDownTimes = upTime + "-" + downTime
            recordCell.upAndDownTimes.text = upAndDownTimes
        }
            
        else
        {
            recordCell.upAndDownTimes.text = upTime
        }
        
        recordCell.flightLength.isHidden = false
        
        if record.timesheet.aircraft.type > .winch
        {
            let flightTimeInMinutes = Double(record.flightLengthInMinutes)
            recordCell.flightLength.text = String(fromMinutes: flightTimeInMinutes)
        }
            
        else
        {
            recordCell.flightLength.text = "Launch @"
            recordCell.flightLength.isHidden = cell.reuseIdentifier == "RecordCellNarrow" ? false : true
        }
        
        switch record.timesheet.aircraft.type
        {
        case .winch:
            recordCell.connectedAircraftLabel?.text = "Launched:"
            
        case .glider:
            recordCell.connectedAircraftLabel?.text = "Launched by:"
            
        case .towplane:
            recordCell.connectedAircraftLabel?.text = record.connectedAircraftRecord == nil ? "No Glider" : "Towed:"
            
        case .auto:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        var sectionName = ""
        
        if mainSortMethod < .timeUp
        {
            sectionName = fetchController.sections?[section].name ?? ""
        }
        
        return sectionName
    }
    
    //MARK: - Fetched Results Controller
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        deletedSections.removeAllIndexes()
        insertedSections.removeAllIndexes()
        tableView.beginUpdates()
        
        let sortDescripotors = controller.fetchRequest.sortDescriptors ?? [NSSortDescriptor]()
        let primarySortDescriptor = sortDescripotors[0]
        positionedAtBottom = false
        
        if primarySortDescriptor.key == "timeUp"
        {
            let lastRow = fetchController.sections![0].numberOfObjects - 1
            let pathOfBottomRecord = IndexPath(row: lastRow, section: 0)
            
            for path in tableView.indexPathsForVisibleRows ?? [IndexPath]()
            {
                if (path as NSIndexPath).compare(pathOfBottomRecord) == .orderedSame
                {
                    positionedAtBottom = true
                    break
                }
            }
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        switch type
        {
        case .insert:
            guard let newIndexPath = newIndexPath else {break}
            tableView.insertRows(at: [newIndexPath], with: .fade)
            if positionedAtBottom
            {
                shouldScrollToBottom = true
            }
            
        case .delete:
            guard let indexPath = indexPath else {break}
            tableView.deleteRows(at: [indexPath], with: .fade)
            
        case .update:
            guard let indexPath = indexPath else {break}
            if let path = newIndexPath
            {
                pathsToUpdate.insert(path)
            }
            
            else
            {
                pathsToUpdate.insert(indexPath)
            }
            
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else {break}
            if !deletedSections.contains((indexPath as NSIndexPath).section) && !insertedSections.contains((newIndexPath as NSIndexPath).section)
            {
                tableView.moveRow(at: indexPath, to:newIndexPath)
                pathsToUpdate.insert(newIndexPath)
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
        @unknown default:
            fatalError()
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType)
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
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        tableView.endUpdates()
        
        for path in pathsToUpdate
        {
            if let cell = tableView.cellForRow(at: path)
            {
                configureCell(cell, atIndexPath:path)
            }
        }
        
        if shouldScrollToBottom
        {
            shouldScrollToBottom = false
            let lastRow = fetchController.sections![0].numberOfObjects - 1
            tableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .none, animated:true)
        }
        
        pathsToUpdate.removeAll()
    }
    
    //MARK: - Utility Methods
    func reloadRecordsForPilot(_ note: Notification)
    {
        if let pilot = note.object as? Pilot
        {
            guard let visibleRows = tableView.indexPathsForVisibleRows else {return}
            for path in visibleRows
            {
                let record = fetchController.object(at: path)
                guard (record.pilot === pilot) || (record.passenger === pilot), let cell = tableView.cellForRow(at: path) else {return}
                configureCell(cell, atIndexPath:path)
            }
        }
    }
    
    func reloadRecord(_ note: Notification)
    {
        if let record = note.object as? FlightRecord
        {
            guard let path = fetchController.indexPath(forObject: record) else {return}
            tableView.reloadRows(at: [path], with: .fade)
        }
    }
    
    @IBAction func sortButtonPushed()
    {
        let chooseSortSheet = UIAlertController(title: nil, message: "Sort According To", preferredStyle: .actionSheet)
        let sortPossibilities = ["Aircraft", "Pilot in Command", "Passenger", "Tow/Towing", "Sequence", "Up Time", "Down Time", "Flight Time"]
        for (index, sortCriteria) in sortPossibilities.enumerated()
        {
            let sortAction = UIAlertAction(title: sortCriteria, style: .default){_ in
                self.sortMethod?.selectedSegmentIndex = index
                self.sortRecords(index)
                }
            chooseSortSheet.addAction(sortAction)
        }
        
        let popoverPresentationController = chooseSortSheet.popoverPresentationController
        popoverPresentationController?.barButtonItem = sortButton

        present(chooseSortSheet, animated:true, completion:nil)
    }
    
    func configureSortDescriptorArray()
    {
        var savedSortDescriptorKeys = dataModel.preferences["sortDescriptorArray"] as? [String]
        
        if savedSortDescriptorKeys == nil
        {
            savedSortDescriptorKeys = [String]()
            
            let sortDescriptor1 = NSSortDescriptor(key: #keyPath(FlightRecord.timesheet.aircraft.tailNumber), ascending: true)
            let sortDescriptor2 = NSSortDescriptor(key: #keyPath(FlightRecord.pilot.fullName), ascending: true)
            let sortDescriptor3 = NSSortDescriptor(key: #keyPath(FlightRecord.passenger.fullName), ascending: true)
            let sortDescriptor4 = NSSortDescriptor(key: #keyPath(FlightRecord.connectedAircraftRecord.timesheet.aircraft.tailNumber), ascending: true)
            let sortDescriptor5 = NSSortDescriptor(key: #keyPath(FlightRecord.flightSequence), ascending: true)
            let sortDescriptor6 = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
            let sortDescriptor7 = NSSortDescriptor(key: #keyPath(FlightRecord.timeDown), ascending: true)
            let sortDescriptor8 = NSSortDescriptor(key: #keyPath(FlightRecord.flightLengthInMinutes), ascending: true)
            
            sortDescriptorArray = [sortDescriptor1, sortDescriptor2, sortDescriptor3, sortDescriptor4, sortDescriptor5, sortDescriptor6, sortDescriptor7, sortDescriptor8]
            
            for descriptor in sortDescriptorArray
            {
                savedSortDescriptorKeys!.append(descriptor.key!)
            }
            
            dataModel.preferences["sortDescriptorArray"] = savedSortDescriptorKeys! as NSArray
            dataModel.preferences["selectedSortMethod"] = RecordSortAttribute.tailNumber.rawValue as NSNumber
            mainSortMethod = RecordSortAttribute.tailNumber
            dataModel.save()
        }
            
        else
        {
            sortDescriptorArray.removeAll(keepingCapacity: true)
            
            for key in savedSortDescriptorKeys ?? [String]()
            {
                var descriptor: NSSortDescriptor
                
                switch key
                {
                case "pilot.name":
                    descriptor = NSSortDescriptor(key: #keyPath(FlightRecord.pilot.fullName), ascending: true)

                case "passenger.name":
                    descriptor = NSSortDescriptor(key: #keyPath(FlightRecord.passenger.fullName), ascending: true)

                default:
                    descriptor = NSSortDescriptor(key: key, ascending: true)
                }
                
                sortDescriptorArray.append(descriptor)
            }
            
            if let segment = dataModel.preferences["selectedSortMethod"] as? Int
            {
                mainSortMethod = RecordSortAttribute(rawValue: segment)!
            }
        }
    }
    
    @objc func reloadData()
    {
        guard let glidingCentre = dataModel.glidingCentre else {return}
        
        let request = fetchController.fetchRequest
        var predicate: NSPredicate
        
        if ((dataModel.viewPreviousRecords == true) && !regularFormat) || previousRecordsViewer
        {
            if !regularFormat
            {
                dataModel.previousRecordsGlidingCentre = glidingCentre
            }
            
            let midnightOnTargetDate = dataModel.dateToViewRecords.startOfDay
            let oneDayLater = midnightOnTargetDate + 60*60*24
            predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.glidingCentre == %@", argumentArray: [midnightOnTargetDate, oneDayLater, dataModel.previousRecordsGlidingCentre!])
            
            if regularFormat
            {
                parent?.title = dataModel.dateToViewRecords.militaryFormatLong
            }
        }
            
        else
        {
            predicate = NSPredicate(format: "timeUp > %@ AND timesheet.glidingCentre == %@", argumentArray: [Date().startOfDay, glidingCentre])
        }
        
        request.predicate = predicate
        request.sortDescriptors = sortDescriptorArray
        
        try! fetchController.performFetch()
        tableView.reloadData()
    }
}
