//
//  Airplanes.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-19.
//
//

import Foundation
import UIKit
import CoreData
import UserNotifications

final class Airplanes : UITableViewController, NSFetchedResultsControllerDelegate, iBeaconDelegate, UIPopoverPresentationControllerDelegate
{
    lazy var flyingAircraftBackground: UIImage = UIImage(assetIdentifier: .BlueCell)
    lazy var landedAircraftBackground: UIImage = UIImage(assetIdentifier: .GreenCell)
    lazy var warningBackground: UIImage = UIImage(assetIdentifier: .RedCell)
    lazy var scoutLanding: UIImage = UIImage(assetIdentifier: .ScoutLanding)
    lazy var scoutLandingFilled: UIImage = UIImage(assetIdentifier: .ScoutLandingFilled)
    lazy var scoutTakeoff: UIImage = UIImage(assetIdentifier: .ScoutTakeOff)
    lazy var gliderLanding: UIImage = UIImage(assetIdentifier: .GliderLanding)
    lazy var gliderLandingFilled: UIImage = UIImage(assetIdentifier: .GliderLandingFilled)
    lazy var gliderTakeoff: UIImage = UIImage(assetIdentifier: .GliderTakeoff)
    lazy var gliderTakeoffFilled: UIImage = UIImage(assetIdentifier: .GliderTakeoffFilled)
    var registeredAsObserver = false
    var fetchController: NSFetchedResultsController<AircraftEntity>!
    var pathsToUpdate = Set<AircraftEntity>()
    var deletedSections = Set<Int>()
    var insertedSections = Set<Int>()
    var observerReferences = [NSObjectProtocol]()
    
    enum SegueIdentifiers: String
    {
        case AddAircraftSegue = "AddAircraftSegue"
    }
    
    //MARK: - UIViewController Methods
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        let height = view.frame.size.height
        navigationController?.hidesBarsOnSwipe = height > 400 ? false : true
        
        
        navigationController?.navigationBar.tintColor = observerMode || trainingMode ? UIColor.red : nil
        
        if let parent = parent as? iPadRootViewController
        {
            parent.leftBar?.tintColor = observerMode || trainingMode ? UIColor.red : nil
            parent.rightBar?.tintColor = observerMode || trainingMode ? UIColor.red : nil
        }
        
        dataModel.aircraftAreaController = self
        dataModel.aircraftFetchedResults = fetchController
        dataModel.startTimer()
        dataModel.beaconManager.beginMonitoringForBeacons()
        
        if registeredAsObserver == false
        {
            observerReferences.append(NotificationCenter.default.addObserver(forName: aircraftChangedNotification, object: nil, queue: OperationQueue.main, using: {note in self.reloadAircraft(note)}))
            observerReferences.append(NotificationCenter.default.addObserver(forName: nameChangedNotification, object: nil, queue: OperationQueue.main, using: {note in self.reloadRecordsForPilot(note)}))
            observerReferences.append(NotificationCenter.default.addObserver(forName: recordsChangedNotification, object: nil, queue: OperationQueue.main, using: {note in self.reloadRecordsForPilot(note)}))
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: reloadPilotNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: glidingSiteSelectedNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: enterOrExitViewPreviousRecordsNotification, object: nil)

            registeredAsObserver = true
        }
        
        fetchController.delegate = self
        reloadData()
    }
    
    deinit
    {
        for ref in observerReferences
        {
            NotificationCenter.default.removeObserver(ref)
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return traitCollection.horizontalSizeClass == .compact ? .fullScreen : .none
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with:coordinator)
        
        if regularFormat == false
        {
            let backgroundImage = BackgroundImage()
            tableView.backgroundView = UIImageView(image: backgroundImage.getBackground(size))
        }
        
        navigationController?.hidesBarsOnSwipe = size.height > 400 ? false : true
        let numberOfSections = tableView.numberOfSections
        var reloadCellsIsNecessary = false
        
        if numberOfSections > 0
        {
            let path = IndexPath(row: 0, section: 0)
            let cell = tableView.cellForRow(at: path)
            let identifier = cell?.reuseIdentifier
            let appropriateIdentifer = appropriateReuseIdentifierForCellOfWidth(Double(size.width))
            
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
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if regularFormat
        {
            fetchController?.delegate = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        registeredAsObserver = false
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        accessibilityLabel = "Aircraft"
        tableView.accessibilityIdentifier = "Aircraft on Field"

        tableView.estimatedRowHeight = 75
        tableView.rowHeight = UITableView.automaticDimension
        dataModel.aircraftAreaController = self
        
        if regularFormat == false
        {
            let backgroundImage = BackgroundImage()
            let screenBound = UIScreen.main.bounds
            tableView.backgroundView = UIImageView(image: backgroundImage.getBackground(screenBound.size))
        }
        
        let request = AircraftEntity.request

        request.predicate = NSPredicate(format: "glidingCentre == %@", dataModel.glidingCentre!)
        let sectionIndexSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftEntity.sectionIndex), ascending: true)
        let vehicleTypeSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftEntity.gliderOrTowplane), ascending: true)
        request.sortDescriptors = [sectionIndexSortDescriptor, vehicleTypeSortDescriptor]
        fetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: #keyPath(AircraftEntity.sectionIndex), cacheName: nil)
        fetchController.delegate = self
        try! fetchController.performFetch()
        dataModel.aircraftFetchedResults = fetchController
        
//        mainQueue.asyncAfter(deadline: .now() + 3){self.updateFlightTimes()}
    }
    
    func reloadAircraft(_ note: Notification)
    {
        if let aircraft = note.object as? AircraftEntity
        {
            if let path = fetchController.indexPath(forObject: aircraft)
            {
                tableView.reloadRows(at: [path], with: .none)
            }
        }
    }
    
    @objc func updateFlightTimes()
    {
        guard dataModel.viewPreviousRecords == false else {return}
        
        for aircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
        {
            pathsToUpdate.insert(aircraft)
            
            if aircraft.status == .flying
            {
                guard let record = aircraft.currentRecord else {return}
                let comps = gregorian.dateComponents([.minute], from: record.timeUp, to: Date())
                if (comps.minute! > 1) && (record.flightLengthInMinutes != Int16(comps.minute!))
                {
                    record.flightLengthInMinutes = Int16(comps.minute!)
                }
                
                NotificationCenter.default.post(name: reloadPilotNotification, object: aircraft.pilot)
                
                if let passenger = aircraft.passenger
                {
                    NotificationCenter.default.post(name: reloadPilotNotification, object: passenger)

                }
            }
        }
        
        if pathsToUpdate.count > 0
        {
            for aircraft in pathsToUpdate
            {
                if let path = fetchController.indexPath(forObject: aircraft)
                {
                    tableView.reloadRows(at: [path], with: .none)
                }
            }
        }
        
        pathsToUpdate.removeAll()
    }
    
    @objc func reloadData()
    {
        if dataModel.glidingCentre == nil
        {
            return
        }
        
        fetchController.fetchRequest.predicate = NSPredicate(format: "glidingCentre == %@", dataModel.glidingCentre!)
        try! fetchController.performFetch()
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .AddAircraftSegue:
            let popoverPresentationController = segue.destination.popoverPresentationController
            popoverPresentationController?.delegate = self
        }
    }

    //MARK: - iBeaconManager Delegate
    func landAircraftWithBeacon(_ aircraftBeaconNumber: Int16)
    {
        print("land")

        var aircraftToLand = [UIButton]()
        
        for aircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
        {
            if aircraft.beaconNumber == aircraftBeaconNumber
            {
                if (aircraft.status == .flying) && (Date() - (aircraft.currentRecord?.timeUp ?? Date()) > 100)
                {
                    guard let pathForAircraft = fetchController.indexPath(forObject: aircraft), let cell = tableView.cellForRow(at: pathForAircraft) as? TableViewCellStyleAircraft else {return}
                    
                    if UIApplication.shared.applicationState != .active
                    {
                        aircraftToLand.append(cell.landButton)
                        let content = UNMutableNotificationContent()
                        content.title = "Aircraft Landed"
                        content.body = "\(aircraft.tailNumber) was marked landed at \(Date().hoursAndMinutes)."
                        content.sound = UNNotificationSound(named: convertToUNNotificationSoundName(aircraft.tailNumber + ".aiff"))
//                        content.sound = UNNotificationSound(named: aircraft.tailNumber)

                        content.categoryIdentifier = "Undo"
                        
                        var userInfo = Dictionary<String, String>()
                        userInfo["Type"] = "Landing Alert"
                        content.userInfo = userInfo
                        let requestIdentifier = "Landing Alert"
                        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: nil)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler:{(error) in print(error?.localizedDescription ?? "")})
                    }
                    
                    else
                    {
                        aircraftToLand.append(cell.landButton)
                        let title = "\(aircraft.tailNumber) Nearby"
                        let message = "\(aircraft.tailNumber) will be marked as landed."
                        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                        let okButton = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okButton)
                        let undoButton = UIAlertAction(title: "Undo Landing", style: .cancel){_ in self.undoLanding()}
                        alert.addAction(undoButton)
                        present(alert, animated:true, completion:nil)
                    }
                }
                    
                else
                {
                    NotificationCenter.default.post(name: aircraftChangedNotification, object:aircraft, userInfo:nil)
                }
            }
        }
        
        for button in aircraftToLand
        {
            LandAircraft(button)
        }
    }
    
    func updateAircraftWithBeacon(_ aircraftBeaconNumber: Int16)
    {
        for aircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
        {
            if aircraft.beaconNumber == aircraftBeaconNumber
            {
                NotificationCenter.default.post(name: aircraftChangedNotification, object:aircraft)
            }
        }
    }
    
    //MARK: - Taking Off and Landing
    @IBAction func TakeoffAircraft(_ sender: AnyObject)
    {
        let START = Date()
        
        guard let clickedCell = (sender as? UIView)?.tableViewCell, let path = tableView.indexPath(for: clickedCell) else {return}
        let aircraft = fetchController.object(at: path)
        
        let ENTITYFOUND = Date()
        
        guard verifyGliderIsTowedIfScoutSequenceIsTowing(aircraft) else {return}
        guard verifyThatPilotPassengerAndSequenceAreFilledInAsRequired(aircraft) else {return}
        guard verifyThatTheUpgradeSequenceIsUsedCorrectly(aircraft) else {return}
        guard verifyThatTheGICsequenceIsUsedCorrectly(aircraft) else {return}
        guard verifyThatTheStudentTrainingSequenceIsUsedCorrectly(aircraft) else {return}
        guard verifyThatTheFamilSequenceIsUsedCorrectly(aircraft) else {return}
        guard verifyThatTheConversionSequenceIsUsedCorrectly(aircraft) else {return}
        guard verifyThatFamFlightsAreMarkedCorrectly(aircraft) else {return}
        guard verifyThatStudentTrainingFlightsAreMarkedCorrectly(aircraft) else {return}
        
        let CHECKSCOMPLETED = Date()
        
        let record = FlightRecord(context: dataModel.managedObjectContext)
        
        var timesheet: AircraftTimesheet
                
        if aircraft.currentTimesheet == nil
        {
            dataModel.setCurrentTimesheetForAircraft(aircraft, possibleContext:nil)
        }
        
        timesheet = aircraft.currentTimesheet!
        
        if timesheet.date < Date().startOfDay
        {
            timesheet = aircraft.insertNewTimeSheetForAircraft()
        }
        
        if timesheet.glidingCentre !== dataModel.glidingCentre
        {
            timesheet = aircraft.insertNewTimeSheetForAircraft()
        }
        
        aircraft.currentRecord = record
        record.flightSequence = aircraft.flightSequence
        record.timeUp = Date().floorToMinute
        record.timeDown = Date.distantFuture
        record.pilot = aircraft.pilot
        record.picParticipantType = record.pilot.typeOfParticipant
        
        timesheet.mutableSetValue(forKey: "flightRecords").add(record)
        record.passenger = aircraft.passenger
        record.dualParticipantType = aircraft.passenger?.typeOfParticipant
        aircraft.inTheAir = true
        tableView.reloadRows(at: [path], with: .none)
        
        if record.flightSequence == "Transit"
        {
            dataModel.GPS.addXcountryStart(record)
        }
        
        if aircraft.hookupStatus == .hooked
        {
            guard let connectedAircraft = aircraft.connectedAircraft else {return}
            var connectedTimesheet: AircraftTimesheet
            
            if connectedAircraft.timesheets.count > 0
            {
                if connectedAircraft.currentTimesheet == nil
                {
                    dataModel.setCurrentTimesheetForAircraft(connectedAircraft, possibleContext:nil)
                }
                connectedTimesheet = connectedAircraft.currentTimesheet!
            }
                
            else
            {
                connectedTimesheet = connectedAircraft.insertNewTimeSheetForAircraft()
            }
            
            if connectedTimesheet.date < Date().startOfDay
            {
                if connectedTimesheet.aircraft.type == .winch
                {
                    if connectedTimesheet.winchFinalTTSNsetCorrectly == false
                    {
                        let errorMessage = "The TTSN on \(connectedTimesheet.aircraft.tailNumber) was not set at the end of the day the last time it was used (\(connectedTimesheet.date.militaryFormatShort))."
                        
                        let takeoffError = UIAlertController(title: "Winch TTSN Not Set", message: errorMessage, preferredStyle: .alert)
                        let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                        takeoffError.addAction(cancel)
                        present(takeoffError, animated:true, completion:nil)
                    }
                }
                
                connectedTimesheet = connectedAircraft.insertNewTimeSheetForAircraft()
            }
            
            if connectedTimesheet.glidingCentre !== dataModel.glidingCentre
            {
                connectedTimesheet = connectedAircraft.insertNewTimeSheetForAircraft()
            }
            
            let connectedRecord = FlightRecord(context: dataModel.managedObjectContext)
            guard let pilot = connectedAircraft.pilot else {return}
            connectedAircraft.currentRecord = connectedRecord
            connectedRecord.aircraft = aircraft.connectedAircraft
            connectedRecord.flightSequence = connectedAircraft.flightSequence
            connectedRecord.timeUp = record.timeUp
            connectedRecord.timeDown = record.timeDown
            connectedRecord.pilot = pilot
            connectedRecord.picParticipantType = pilot.typeOfParticipant
            connectedRecord.timesheet = connectedTimesheet
            connectedRecord.connectedAircraftRecord = aircraft.currentRecord
            connectedRecord.passenger = connectedAircraft.passenger
            connectedRecord.dualParticipantType = connectedAircraft.passenger?.typeOfParticipant
            connectedAircraft.inTheAir = true
            guard let connectedPath = fetchController.indexPath(forObject: connectedAircraft) else {return}
            connectedTimesheet.winchFinalTTSNsetCorrectly = false
            
            if connectedRecord.flightSequence == "Transit"
            {
                dataModel.GPS.addXcountryStart(connectedRecord)
            }
            
            dataModel.reloadAircraftAtIndexPath(connectedPath)
        }
        
        let TIMESHEETCONFIGURED = Date()
        
        let formerSectionIndex = aircraft.sectionIndex
        
        if formerSectionIndex > 0
        {
            let newSection = Int16(0)
            aircraft.sectionIndex = newSection
            
            if let connectedAircraft = aircraft.connectedAircraft
            {
                connectedAircraft.sectionIndex = newSection
            }
        }
        
        for someAircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
        {
            let index = someAircraft.sectionIndex
            if (someAircraft !== aircraft) && (someAircraft !== aircraft.connectedAircraft) && (index < formerSectionIndex)
            {
                someAircraft.sectionIndex = index + 1
            }
        }
        
        if aircraft.type == .glider
        {
            guard let connectedRecord = aircraft.currentRecord?.connectedAircraftRecord else {return}
            connectedRecord.timeDown = connectedRecord.timeUp
            connectedRecord.flightLengthInMinutes = 0
            aircraft.connectedAircraft?.inTheAir = false
            let numberOfSections = tableView.numberOfSections
            aircraft.connectedAircraft?.sectionIndex = Int16(numberOfSections)
            aircraft.connectedAircraft = nil
        }
        
        let SECTIONSADJUSTED = Date()
        var findEntity = ENTITYFOUND - START
        var completedChecks = CHECKSCOMPLETED - ENTITYFOUND
        var configureTimesheet = TIMESHEETCONFIGURED - CHECKSCOMPLETED
        var adjustSections = SECTIONSADJUSTED - TIMESHEETCONFIGURED
        
        findEntity *= 1000
        completedChecks *= 1000
        configureTimesheet *= 1000
        adjustSections *= 1000
        
//        print("It takes \(Int(findEntity)) milliseconds to find the entity, \(Int(completedChecks)) milliseconds to do checks, \(Int(configureTimesheet)) milliseconds to configure the timesheet, and \(Int(adjustSections)) milliseconds to adjust the sections.")
        
        dataModel.saveContext()
    }
    
    @IBAction func LandAircraft(_ sender: AnyObject)
    {
        guard let clickedCell = (sender as? UIView)?.tableViewCell, let path = tableView.indexPath(for: clickedCell) else {return}
        let aircraft = fetchController.object(at: path)
        guard let record = aircraft.currentRecord else {return}
        record.timeDown = Date().floorToMinute
        
        if record.flightSequence == "Transit"
        {
            dataModel.GPS.addXcountryEnd(record)
        }
        
        let comps = gregorian.dateComponents([.minute], from: record.timeUp, to: record.timeDown)
        if comps.minute! > 1
        {
            record.flightLengthInMinutes = Int16(comps.minute!)
        }
        
        if record.timeDown == record.timeUp
        {
            record.timeDown = Date(timeInterval: 60, since: record.timeUp)
        }
        
        aircraft.currentRecord = nil
        aircraft.updateTTSN()
        
        aircraft.inTheAir = false
        
        let formerSectionIndex = aircraft.sectionIndex
        
        if aircraft.hookupStatus == .unhooked
        {
            aircraft.sectionIndex = Int16(tableView.numberOfSections - 1)
            
            for someAircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
            {
                let index = someAircraft.sectionIndex
                if (someAircraft !== aircraft) && (index > formerSectionIndex)
                {
                    someAircraft.sectionIndex = index - 1
                }
            }
        }
            
        else
        {
            aircraft.sectionIndex = Int16(tableView.numberOfSections)
            aircraft.connectedAircraft = nil
        }
        
        dataModel.saveContext()
        becomeFirstResponder()
    }
    
    func checkSectionConsistency()
    {
        for aircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
        {
            let aircraftSection = aircraft.sectionIndex
            guard let path = fetchController.indexPath(forObject: aircraft) else {return}
            if aircraftSection != Int16((path as NSIndexPath).section)
            {
                aircraft.sectionIndex = Int16((path as NSIndexPath).section)
            }
        }
    }
    
    //MARK: - Take-off Errors
    
    func swapToGliderIfRequire(_ aircraft: inout AircraftEntity)
    {
        if aircraft.type != .glider
        {
            if aircraft.hookupStatus == .hooked
            {
                guard let connectedAircraft = aircraft.connectedAircraft else {return}
                aircraft = connectedAircraft
            }
                
            else
            {
                return
            }
        }
    }
    
    func verifyGliderIsTowedIfScoutSequenceIsTowing(_ aircraft: AircraftEntity) -> Bool
    {
        var returnValue = true
        
        if (aircraft.flightSequence == "Towing") && (aircraft.hookupStatus == .unhooked)
        {
            returnValue = false
            
            let errorTitle = "No Glider Attached"
            let errorMessage = "A scout cannot take-off on a towing sequence flight without a glider attached."
            
            let takeoffError = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: .alert)
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            takeoffError.addAction(cancel)
            present(takeoffError, animated:true, completion:nil)
        }
        
        return returnValue
    }
    
    func verifyThatPilotPassengerAndSequenceAreFilledInAsRequired(_ aircraft: AircraftEntity) -> Bool
    {
        var returnValue = true
        
        var errorMessage = "You are missing the following required information:\n"
        let errorTitle = "Missing Information"
        
        if aircraft.pilot == nil
        {
            returnValue = false
            errorMessage += "•Pilot Name\n"
        }
        
        if aircraft.flightSequence == ""
        {
            returnValue = false
            errorMessage += "•Sequence\n"
        }
        
        else
        {
            if aircraft.hookupStatus == .hooked
            {
                if ((aircraft.flightSequence == "Upgrade") || (aircraft.flightSequence == "Conversion")) && (aircraft.connectedAircraft!.type == .towplane)
                {
                    if aircraft.passenger == nil
                    {
                        returnValue = false
                        errorMessage += "•Student\n"
                    }
                }
            }
            
            if aircraft.flightSequence == "Famil"
            {
                if aircraft.passenger == nil
                {
                    returnValue = false
                    errorMessage += "•Passenger\n"
                }
            }
        }
        
        if aircraft.hookupStatus == .hooked
        {
            guard let otherAircraftToCheck = aircraft.connectedAircraft else {return false}
            
            if otherAircraftToCheck.pilot == nil
            {
                returnValue = false
                switch otherAircraftToCheck.type
                {
                case .auto:
                    errorMessage += "•Auto Driver Name\n"

                case .winch:
                    errorMessage += "•Winch Operator Name\n"

                default:
                    errorMessage += "•Glider Pilot Name\n"
                }
            }
            
            if (otherAircraftToCheck.flightSequence == "Upgrade") ||  (otherAircraftToCheck.flightSequence == "Conversion")
            {
                if otherAircraftToCheck.passenger == nil
                {
                    returnValue = false
                    errorMessage += "•Glider Student\n"
                }
            }
            
            if otherAircraftToCheck.flightSequence == "Famil"
            {
                if otherAircraftToCheck.passenger == nil
                {
                    returnValue = false
                    errorMessage += "•Glider Passenger\n"
                }
            }
        }
        
        if returnValue == false
        {
            let takeoffError = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: .alert)
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            takeoffError.addAction(cancel)
            present(takeoffError, animated:true, completion:nil)
        }
        
        return returnValue
    }
    
    func verifyThatTheUpgradeSequenceIsUsedCorrectly(_ aircraft: AircraftEntity) -> Bool
    {
        var returnValue = true
        var aircraftDoingUpgrade = aircraft
        
        if aircraftDoingUpgrade.type != .glider
        {
            if aircraftDoingUpgrade.hookupStatus == .hooked
            {
                guard let connectedAircraft = aircraftDoingUpgrade.connectedAircraft else {return false}
                if connectedAircraft.type == .glider
                {
                    aircraftDoingUpgrade = connectedAircraft
                }
                    
                else
                {
                    return returnValue
                }
            }
            
            else
            {
                return returnValue
            }
        }
        
        if aircraftDoingUpgrade.flightSequence == "Upgrade"
        {
            guard let pilot = aircraftDoingUpgrade.pilot else {return false}
            if (pilot.gliderQual < .instructor) && (aircraftDoingUpgrade.hookupStatus == .hooked) && (aircraftDoingUpgrade.connectedAircraft?.type == .towplane)
            {
                let messageTitle = "Incorrect Sequence"
                let messageText = "\(pilot.name) must be at least an instructor to carry out the 'Upgrade' sequence as PIC."
                returnValue = false
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    func verifyThatTheGICsequenceIsUsedCorrectly(_ vehicle: AircraftEntity) -> Bool
    {
        var returnValue = true
        var aircraft = vehicle
        swapToGliderIfRequire(&aircraft)
        
        if aircraft.flightSequence == "GIC"
        {
            guard let pilot = aircraft.pilot else {return false}

            if pilot.gliderQual < .standardsPilot
            {
                let messageTitle = "Incorrect Sequence"
                let messageText = "\(pilot.name) must be a Glider Standards Pilot to carry out the 'GIC' sequence as PIC."
                returnValue = false
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    func verifyThatTheFamilSequenceIsUsedCorrectly(_ vehicle: AircraftEntity) -> Bool
    {
        var returnValue = true
        var aircraft = vehicle
        swapToGliderIfRequire(&aircraft)
        
        if aircraft.flightSequence == "Famil"
        {
            guard let pilot = aircraft.pilot else {return false}

            if pilot.gliderQual < .frontSeatFamil
            {
                let messageTitle = "Incorrect Sequence"
                let messageText = "\(pilot.name) must be at least a Front Seat Famil Pilot to carry out famil flying."
                returnValue = false
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    func verifyThatTheConversionSequenceIsUsedCorrectly(_ vehicle: AircraftEntity) -> Bool
    {
        let returnValue = true
        var aircraft = vehicle
        swapToGliderIfRequire(&aircraft)
        
        if aircraft.flightSequence == "Conversion"
        {
            if let launcherType = aircraft.connectedAircraft?.type, launcherType == .winch
            {
                aircraft.flightSequence = "Upgrade"
                let messageTitle = "Incorrect Sequence"
                let messageText = "The Conversion sequence is only for the soaring to glider and power to glider conversion courses. Winch upgrades should be marked as upgrades. This flight has been changed to upgrade."
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    func verifyThatTheStudentTrainingSequenceIsUsedCorrectly(_ vehicle: AircraftEntity) -> Bool
    {
        var returnValue = true
        var aircraft = vehicle

        swapToGliderIfRequire(&aircraft)
        
        if aircraft.flightSequence == "Student Trg"
        {
            var messageTitle = ""
            var messageText = ""
            
            guard let pilot = aircraft.pilot else {return false}
            
            if let _ = aircraft.passenger
            {
                if pilot.gliderQual < .instructor
                {
                    messageTitle = "Incorrect Sequence"
                    messageText = "Only instructors and above may act as PIC on dual student training flights."
                    returnValue = false
                }
                    
                else
                {
                    if aircraft.passenger?.gliderQual != .student
                    {
                        messageTitle = "Incorrect Sequence"
                        messageText = "On dual student training flights the passenger must always be a student."
                        returnValue = false
                    }
                }
            }
                
            else
            {
                if pilot.gliderQual != .student
                {
                    messageTitle = "Incorrect Sequence"
                    messageText = "Only students may carry out student training flights solo."
                    returnValue = false
                }
            }
            
            if returnValue == false
            {
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    func verifyThatFamFlightsAreMarkedCorrectly(_ vehicle: AircraftEntity) -> Bool
    {
        let returnValue = true
        var aircraft = vehicle
        swapToGliderIfRequire(&aircraft)
        
        if let passenger = aircraft.passenger
        {
            if (passenger.gliderQual < .noGlider) && (aircraft.flightSequence != "Famil")
            {
                let messageTitle = "Incorrect Sequence"
                let messageText = "All flights involving squadron cadets must be marked as famil flights. This has been corrected automatically."
                aircraft.flightSequence = aircraft.type == .glider ? "Famil" : "Fam / PR / Wx"
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    func verifyThatStudentTrainingFlightsAreMarkedCorrectly(_ vehicle: AircraftEntity) -> Bool
    {
        let returnValue = true
        var aircraft = vehicle
        swapToGliderIfRequire(&aircraft)
        
        if let passenger = aircraft.passenger
        {
            if (passenger.gliderQual == .student) && (aircraft.flightSequence != "Student Trg")
            {
                let messageTitle = "Incorrect Sequence"
                let messageText = "Training flights involving student pilots must be marked as Student Trg. This has been corrected automatically. If this flight is not a training flight for \(passenger.name), you may manually reverse this change."
                aircraft.flightSequence = "Student Trg"
                
                let takeoffError = UIAlertController(title: messageTitle, message: messageText, preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                takeoffError.addAction(cancel)
                present(takeoffError, animated:true, completion:nil)
            }
        }
        
        return returnValue
    }
    
    //MARK: - UITableView Methods
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        if dataModel.glidingCentre == nil
        {
            return 0
        }
        
        return ((dataModel.viewPreviousRecords == false) || regularFormat) ? (fetchController.sections?.count ?? 0) : 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        return ""
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let aircraft = fetchController.object(at: indexPath)
        guard let currentCell = cell as? TableViewCellStyleAircraft else {return}
        let backgroundColor = aircraft.status == .flying ? (TableCellColor.defaultColor, flyingAircraftBackground) : (TableCellColor.green, landedAircraftBackground)
        currentCell.setBackgroundToColor(backgroundColor.0, withImage: backgroundColor.1)

        if dataModel.beaconManager.indicesOfNearbyAircraft.contains(aircraft.beaconNumber)
        {
            currentCell.beaconStatusImageView?.isHidden = false
            let range = dataModel.beaconManager.rangesOfNearbyAircraft[aircraft.beaconNumber]
            
            if aircraft.status != .landed
            {
                currentCell.setBackgroundToColor(.red, withImage: warningBackground)
            }
            
            if let range = range
            {
                switch range
                {
                case .immediate:
                    currentCell.beaconStatusImageView?.image = UIImage(assetIdentifier: .FullBeacon)
                    
                case .near:
                    currentCell.beaconStatusImageView?.image = UIImage(assetIdentifier: .IntermediateBeacon)
                    
                default:
                    currentCell.beaconStatusImageView?.image = UIImage(assetIdentifier: .LowBeacon)
                }
            }
        }
            
        else
        {
            currentCell.beaconStatusImageView?.isHidden = true
            
            if (aircraft.status != .flying) && (dataModel.beaconManager.iBeaconAssistance) && (aircraft.type > .winch)
            {
                currentCell.setBackgroundToColor(.red, withImage: warningBackground)
            }
        }
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath:IndexPath)
    {
        let aircraft = fetchController.object(at: indexPath)
        guard let aircraftCell = cell as? TableViewCellStyleAircraft else {return}
        
        aircraftCell.accessibilityIdentifier = aircraft.tailNumber
        aircraftCell.aircraftName.text = aircraft.tailNumber
        aircraftCell.pilotName.text = aircraft.pilot?.fullName
        aircraftCell.passengerName.text = aircraft.passenger?.fullName
        aircraftCell.flightSequenceType.text = aircraft.flightSequence
        
        let cockpitTime: Int
        if let pilot = aircraft.pilot
        {
            cockpitTime = cockpitTimeForPilot(pilot)
        }
        
        else
        {
            cockpitTime = 0
        }
        
        aircraftCell.pilotCockpitTime.text = aircraft.pilot == nil ? nil : String(fromSeconds: Double(cockpitTime))
        aircraftCell.pilotCockpitTime.font = UIFont.systemFont(ofSize: 12)
        
        switch cockpitTime
        {
        case let x where x >= (120*60):
            aircraftCell.pilotCockpitTime.textColor = UIColor.red

        case (90*60)..<(120*60):
            aircraftCell.pilotCockpitTime.textColor = UIColor.orange

        default:
            aircraftCell.pilotCockpitTime.textColor = UIColor.black
        }
        
        if aircraft.status == .flying
        {
            guard let currentRecord = aircraft.currentRecord else {return}
            aircraftCell.takeOffButton.isHidden = true
            aircraftCell.landButton.isHidden = false
            
            if aircraft.type == .towplane
            {
                aircraftCell.landButton.setImage(scoutLanding, for: UIControl.State())
                aircraftCell.landButton.setImage(scoutLandingFilled, for: .highlighted)
            }
                
            else
            {
                aircraftCell.landButton.setImage(gliderLanding, for: UIControl.State())
                aircraftCell.landButton.setImage(gliderLandingFilled, for: .highlighted)
            }
            
            var flightTimeInMinutes = Double(currentRecord.flightLengthInMinutes)
            flightTimeInMinutes *= 60
            aircraftCell.flightTimeCounter.text = String(fromSeconds: flightTimeInMinutes)
        }
            
        else
        {
            aircraftCell.flightTimeCounter.text = ""
            aircraftCell.landButton.isHidden = true
            aircraftCell.takeOffButton.isHidden = false

            if aircraft.type < .towplane
            {
                aircraftCell.takeOffButton.isHidden = true
            }
            
            if (aircraft.type == .glider) && (aircraft.hookupStatus == .hooked)
            {
                if aircraft.connectedAircraft?.type ?? .winch < .towplane
                {
                    aircraftCell.takeOffButton.setImage(gliderTakeoff, for: UIControl.State())
                    aircraftCell.takeOffButton.setImage(gliderTakeoffFilled, for: .highlighted)
                }
                
                else
                {
                    aircraftCell.takeOffButton.isHidden = true
                }
            }
            
            if (aircraft.type == .glider) && (aircraft.hookupStatus == .unhooked)
            {
                aircraftCell.takeOffButton.isHidden = true
            }
            
            if aircraft.type == .towplane
            {
                aircraftCell.takeOffButton.setImage(scoutTakeoff, for: UIControl.State())
            }
        }
        
        aircraftCell.cockpitTimeLabel.text = (aircraft.type > .winch) ? "Cockpit Time:" : "Operator Time:"
        aircraftCell.TNIvalue.isHidden = (aircraft.type > .auto) ? false : true
        
        if aircraftCell.TNIvalue.isHidden == false
        {
            aircraftCell.TNIvalue.text = calculateTNIforAircraft(aircraft).stringWithDecimal
            aircraftCell.TNIvalue.font = UIFont.systemFont(ofSize: 12)
                        
            switch aircraftCell.TNIvalue.text?.intValueWithNegatives ?? 0
            {
            case Int.min..<5:
                aircraftCell.TNIvalue.textColor = UIColor.red

            case 5..<10:
                aircraftCell.TNIvalue.textColor = UIColor.orange

            default:
                aircraftCell.TNIvalue.textColor = UIColor.black
            }
            
            if aircraft.type < .towplane
            {
                aircraftCell.TNIvalue.text = "<" + (aircraftCell.TNIvalue?.text ?? "")
            }
        }
            
        else
        {
            aircraftCell.TNIlabel.isHidden = true
        }
    }
    
    func appropriateReuseIdentifierForCellOfWidth(_ width: Double)  -> String
    {
        var cellIdentifier: String
        
        switch width
        {
        case 0..<400:
            cellIdentifier = "AircraftCellNarrow"

        case 400..<600:
            cellIdentifier = "AircraftCellRegular"

        default:
            cellIdentifier = "AircraftCellWide"
        }
        
        return cellIdentifier
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let width = Double(tableView.frame.size.width)
        let cellIdentifier = appropriateReuseIdentifierForCellOfWidth(width)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        configureCell(cell, atIndexPath:indexPath)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String?
    {
        return "Remove"
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        let aircraft = fetchController.object(at: indexPath)
        
        switch aircraft.status
        {
        case .flying:
            return false
            
        case .landed:
            if let _ = aircraft.connectedAircraft
            {
                return false
            }
            return true
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard observerMode == false else {tableView.deselectRow(at: indexPath, animated: true); return}

        if let _ = presentedViewController
        {
            dismiss(animated: false, completion:nil)
        }
        
        var editGliderNavController: UINavigationController
        let aircraftBeingEdited = fetchController.object(at: indexPath)
        let flightStatus = aircraftBeingEdited.status
        let hookedUp = aircraftBeingEdited.hookupStatus
        
        switch (flightStatus, hookedUp, aircraftBeingEdited.type)
        {
        case (.landed, .unhooked, .glider):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "GliderOnGroundUnhooked") as? UINavigationController else {return}
            editGliderNavController = controller
          
        case (.landed, .hooked, .glider):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "GliderOnGroundHooked") as? UINavigationController else {return}
            editGliderNavController = controller

        case (.flying, _, .glider):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "GliderInAir") as? UINavigationController else {return}
            editGliderNavController = controller

        case (.landed, .unhooked, .towplane):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "TowplaneOnGroundUnhooked") as? UINavigationController else {return}
            editGliderNavController = controller

        case (.landed, .hooked, .towplane):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "TowplaneOnGroundHooked") as? UINavigationController else {return}
            editGliderNavController = controller

        case (.flying, _, .towplane):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "TowplaneInAir") as? UINavigationController else {return}
            editGliderNavController = controller

        case (_, .unhooked, .winch):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "WinchOnGroundUnhooked") as? UINavigationController else {return}
            editGliderNavController = controller

        case (_, .hooked, .winch):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "WinchOnGroundHooked") as? UINavigationController else {return}
            editGliderNavController = controller

        case (_, .unhooked, .auto):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "AutoOnGroundUnhooked") as? UINavigationController else {return}
            editGliderNavController = controller

        case (_, .hooked, .auto):
            guard let controller = storyboard?.instantiateViewController(withIdentifier: "AutoOnGroundHooked") as? UINavigationController else {return}
            editGliderNavController = controller
        }
        
        guard let editAircraft = editGliderNavController.topViewController as? EditVehicle else {return}
        editAircraft.indexPath = indexPath
        editAircraft.aircraftBeingEdited = aircraftBeingEdited
        editGliderNavController.modalPresentationStyle = .popover
        let presentationController = editGliderNavController.popoverPresentationController
        presentationController?.delegate = self
        present(editGliderNavController, animated:true, completion:nil)

        presentationController?.permittedArrowDirections = .right
        var selectedAircraftRect = tableView.rectForRow(at: indexPath)
        let screenWidth = UIScreen.main.bounds.size.width
        if screenWidth == selectedAircraftRect.size.width
        {
            selectedAircraftRect = CGRect(x: selectedAircraftRect.origin.x, y: selectedAircraftRect.origin.y, width: (selectedAircraftRect.size.width - 350), height: selectedAircraftRect.size.height)
            presentationController?.permittedArrowDirections = .left
        }
        
        var passThroughViews = tableView.visibleCells
        let cellBeingEdited = tableView.cellForRow(at: indexPath)
        passThroughViews = passThroughViews.filter{$0 != cellBeingEdited}
        presentationController?.passthroughViews = passThroughViews
        presentationController?.sourceView = tableView
        presentationController?.sourceRect = selectedAircraftRect
        tableView.deselectRow(at: indexPath, animated:true)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            if presentedViewController != nil
            {
                dismiss(animated: true, completion:nil)
            }
            
            let aircraft = fetchController.object(at: indexPath)
            let formerSectionIndex = aircraft.sectionIndex
            
            for someAircraft in fetchController.fetchedObjects ?? [AircraftEntity]()
            {
                let index = someAircraft.sectionIndex
                if index > formerSectionIndex
                {
                    someAircraft.sectionIndex = index - 1
                }
            }
            
            aircraft.glidingCentre = nil
            aircraft.pilot = nil
            aircraft.passenger = nil
            dataModel.saveContext()
            dataModel.beaconManager.beginMonitoringForBeacons()
        }
    }
    
    //MARK: - Fetched Results Controller
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        deletedSections.removeAll()
        insertedSections.removeAll()
        guard dataModel.viewPreviousRecords == false else {return}
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        guard dataModel.viewPreviousRecords == false && controller == fetchController else {return}
        
        switch type
        {
        case .insert:
            guard let path = indexPath ?? newIndexPath else {return}
            tableView.insertRows(at: [path], with: .fade)
            
        case .delete:
            guard let path = indexPath ?? newIndexPath else {return}
            tableView.deleteRows(at: [path], with: .fade)
            
        case .update:
            guard let object = anObject as? AircraftEntity, object.changedValues().count > 0 else {return}
            pathsToUpdate.insert(object)
            fallthrough
            
        case .move:
            guard let newPath = newIndexPath, let oldPath = indexPath, newPath != oldPath, let object = anObject as? AircraftEntity else {return}
            pathsToUpdate.insert(object)

            if !deletedSections.contains(oldPath.section) && !insertedSections.contains(newPath.section)
            {
                tableView.moveRow(at: oldPath, to:newPath)
            }
                
            else
            {
                if deletedSections.contains(oldPath.section)
                {
                    tableView.insertRows(at: [newPath], with: .fade)
                }
            
                else
                {
                    tableView.deleteRows(at: [oldPath], with: .fade)
                }
            }
        }
    }
    
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType)
    {
        guard dataModel.viewPreviousRecords == false else {return}
        
        switch type
        {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            insertedSections.insert(sectionIndex)
            
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            deletedSections.insert(sectionIndex)
            
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        guard dataModel.viewPreviousRecords == false else {return}
        tableView.endUpdates()
        
        for aircraft in pathsToUpdate
        {
            if let path = fetchController.indexPath(forObject: aircraft)
            {
                tableView.reloadRows(at: [path], with: .none)
            }
        }
        
        pathsToUpdate.removeAll()
    }
    
    //MARK: - Utility
    func reloadRecordsForPilot(_ note: Notification)
    {
        if let pilot = note.object as? Pilot
        {
            let visibleRows = tableView.indexPathsForVisibleRows ?? [IndexPath]()
            
            for path in visibleRows
            {
                let aircraft = fetchController.object(at: path)
                
                switch (aircraft.pilot, aircraft.passenger)
                {
                case let (.some(PIC) , _):
                    if PIC == pilot
                    {
                        tableView.reloadRows(at: [path], with: .none)
                    }
                    
                case let (_ , .some(pax)):
                    if (pax) == pilot
                    {
                        tableView.reloadRows(at: [path], with: .none)
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    func calculateTNIforAircraft(_ aircraft: AircraftEntity)  -> Decimal
    {
        if aircraft.status == .flying
        {
            if aircraft.type > .winch
            {
                aircraft.updateTTSN()
            }
        }
        
        if aircraft.currentTimesheet == nil
        {
            dataModel.setCurrentTimesheetForAircraft(aircraft, possibleContext:nil)
        }
        
        guard let timesheet = aircraft.currentTimesheet else {return 0}
        var TTSN = timesheet.TTSNfinal
        let TTNI = aircraft.TTNI
        
        if TTSN == .nan
        {
            timesheet.TTSNfinal = 0
            TTSN = timesheet.TTSNfinal
        }
        
        return TTNI - TTSN
    }
    
    func cockpitTimeForPilot(_ pilot: Pilot)  -> Int
    {
        var shiftStart = Date()
        
        let request = FlightRecord.request
        request.predicate = NSPredicate(format: "timeUp > %@ AND pilot == %@", argumentArray: [Date().startOfDay, pilot])
        let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: false)
        request.sortDescriptors = [timeUpSortDescriptor]
        
        do
        {
            let records = try dataModel.managedObjectContext.fetch(request)
            for record in records
            {
                if shiftStart - record.timeDown < LENGTH_OF_MIN_REST_PERIOD
                {
                    shiftStart = record.timeUp
                }
            }
        }
            
        catch let error as NSError
        {
            print("\(error.localizedDescription)")
        }
        
        return Int(abs(shiftStart.timeIntervalSinceNow))
    }
    
    override var canBecomeFirstResponder: Bool
    {
        return true
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?)
    {
        if event?.subtype == .motionShake
        {
            undoLanding()
        }
    }
    
    func undoLanding()
    {
        let numberOfVehiclesInLastSection = fetchController.sections?.last?.numberOfObjects ?? 0
        
        if numberOfVehiclesInLastSection == 1
        {
            let aircraftBeingExamined = fetchController.fetchedObjects!.last!
            var mostRecentLanding = Date.distantPast
            var currentRecord: FlightRecord?
            
            for record in aircraftBeingExamined.currentTimesheet?.flightRecords ?? Set<FlightRecord>()
            {
                if record.timeDown > mostRecentLanding
                {
                    mostRecentLanding = record.timeDown
                    currentRecord = record
                }
            }
            
            let timeElapsed = Date() - mostRecentLanding
            
            if (timeElapsed < 300) && (aircraftBeingExamined.status == .landed) && (aircraftBeingExamined.type > .winch)
            {
                let title = "Undo Landing of \(aircraftBeingExamined.tailNumber)"
                let message = "\(aircraftBeingExamined.tailNumber) will be returned to the air."
                let shakeAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                guard let currentRecord = currentRecord else {return}
                let proceedButton = UIAlertAction(title: "Proceed", style: UIAlertAction.Style.default){_ in
                    currentRecord.timeDown = Date.distantFuture
                    aircraftBeingExamined.inTheAir = true
                    aircraftBeingExamined.currentRecord = currentRecord
                    
                    for someAircraft in self.fetchController.fetchedObjects!
                    {
                        let index = someAircraft.sectionIndex
                        someAircraft.sectionIndex = index + 1
                    }
                    
                    aircraftBeingExamined.sectionIndex = 0
                    
                    dataModel.saveContext()
                }
                shakeAlert.addAction(proceedButton)
                shakeAlert.addAction(cancelButton)
                
                present(shakeAlert, animated:true, completion:nil)
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
	return UNNotificationSoundName(rawValue: input)
}
