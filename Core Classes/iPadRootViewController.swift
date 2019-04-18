//
//  iPadRootViewController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-01.
//
//

import Foundation
import UIKit
import CoreData

final class iPadRootViewController : UIViewController, UINavigationBarDelegate
{
    @IBOutlet var leftView: UIView?
    @IBOutlet var recordArea: UIView!
    @IBOutlet var leftSideContentView: UIView!
    @IBOutlet var pilotContainerView: UIView?
    @IBOutlet var attendanceOrTimesheets: UISegmentedControl!
    @IBOutlet var banditTally: UILabel?
    @IBOutlet var apacheTally: UILabel?
    @IBOutlet var totalTally: UILabel?
    @IBOutlet var uploadsInProgress: UILabel?
    @IBOutlet var downloadsInProgress: UILabel?
    @IBOutlet var unflownCadetsTally: UILabel?
    @IBOutlet var leftBarItems: UINavigationItem?
    @IBOutlet var rightBarItems: UINavigationItem?
    @IBOutlet var actionButton: UIBarButtonItem?
    @IBOutlet var date: UIBarButtonItem?
    @IBOutlet var sortMethod: UISegmentedControl?
    @IBOutlet var leftNavBar: UINavigationBar?
    @IBOutlet var airViewWidthConstraint: NSLayoutConstraint?
    @IBOutlet var background: UIImageView?
    @IBOutlet var glidingUnit: UIBarButtonItem?
    @IBOutlet var leftBar: UINavigationBar?
    @IBOutlet var rightBar: UINavigationBar?
    
    var pilotAreaController: PilotsController?
    var previousRecordsViewer = false
    var todayBanditTally: UILabel?
    var todayApacheTally: UILabel?
    var todayTotalTally: UILabel?
    var todayUnflownCadetsTally: UILabel?
    var pilotLayoutConstraints = [NSLayoutConstraint]()
    var recordLayoutConstraints = [NSLayoutConstraint]()
    
    enum SegueIdentifiers: String
    {
        case ChangeUnitiPadSegue = "ChangeUnitiPadSegue"
        case EmbedRecordsSegue = "EmbedRecordsSegue"
        case EmbedPilotsSegue = "EmbedPilotsSegue"
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        recordArea.isHidden = true
        previousRecordsViewer = navigationController == nil ? false : true
        
        if previousRecordsViewer
        {
            NotificationCenter.default.addObserver(self, selector: #selector(self.upDateButton), name: enterOrExitViewPreviousRecordsNotification, object: nil)
        }
        
        for constraint in leftSideContentView.constraints as [NSLayoutConstraint]
        {
            if (constraint.firstItem === recordArea) || (constraint.secondItem === recordArea)
            {
                recordLayoutConstraints.append(constraint)
            }
            
            if (constraint.firstItem === pilotContainerView) || (constraint.secondItem === pilotContainerView)
            {
                pilotLayoutConstraints.append(constraint)
            }
        }
    }

    func position(for bar: UIBarPositioning) -> UIBarPosition
    {
        return .topAttached
    }
    
    @objc func upDateButton()
    {
        date?.title = dataModel.dateToViewRecords.militaryFormatShort
    }
    
//    override func encodeRestorableStateWithCoder(coder: NSCoder)
//    {
//        coder.encodeBool(Bool(attendanceOrTimesheets.selectedSegmentIndex), forKey: "SwitchLeftView")
//    }
//    
//    override func decodeRestorableStateWithCoder(coder: NSCoder)
//    {
//        if coder.decodeBoolForKey("SwitchLeftView") == false
//        {
//            switchLeftView()
//        }
//    }
    
    @IBAction func switchLeftView()
    {
        dataModel.currentlySelectedCell = nil
        
        if let _ = presentedViewController
        {
            dismiss(animated: true, completion:nil)
        }
        
        if attendanceOrTimesheets.selectedSegmentIndex == ATTENDANCE
        {
            UIView.transition(with: leftSideContentView, duration: 0.5, options: UIView.AnimationOptions.transitionFlipFromRight, animations:
                {
                    self.recordArea.removeFromSuperview()
                    guard let pilotContainerView = self.pilotContainerView else {return}
                    self.leftSideContentView.addSubview(pilotContainerView)
                    if self.pilotLayoutConstraints.count > 0
                    {
                        self.leftSideContentView.removeConstraints(self.leftSideContentView.constraints)
                        self.leftSideContentView.addConstraints(self.pilotLayoutConstraints)
                    }
                }, completion: nil)
        }
            
        else
        {
            UIView.transition(with: leftSideContentView, duration:0.5, options:UIView.AnimationOptions.transitionFlipFromLeft, animations:
                {
                    self.pilotContainerView?.removeFromSuperview()
                    self.leftSideContentView.addSubview(self.recordArea)
                    if self.recordLayoutConstraints.count > 0
                    {
                        self.leftSideContentView.removeConstraints(self.leftSideContentView.constraints)
                        self.leftSideContentView.addConstraints(self.recordLayoutConstraints)
                    }
                }, completion: nil)
            
            recordArea.isHidden = false
        }
        
        dataModel.save()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        if dataModel.viewPreviousRecords
        {
            dataModel.viewPreviousRecords = false
        }
        
        super.viewWillDisappear(animated)
    }
    
    override func size(forChildContentContainer container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize
    {
        let landscapeOrientation = parentSize.width > parentSize.height
        let aircraftWidth = landscapeOrientation ? 460 as CGFloat : 320 as CGFloat
        let recordWidth = parentSize.width - aircraftWidth
        let height = parentSize.height
        let newSize = container is Airplanes ? CGSize(width: aircraftWidth, height: height) : CGSize(width: recordWidth, height: height)
        
        return newSize
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        airViewWidthConstraint?.constant = size.width >= 1024 ? 460 : 320
        
        let backgroundImage = BackgroundImage()
        background?.image = backgroundImage.getBackground(size)
        
        super.viewWillTransition(to: size, with:coordinator)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        if previousRecordsViewer
        {
            dataModel.viewPreviousRecords = true
        }
            
        else
        {
            let backgroundImage = BackgroundImage()
            let screenBound = UIScreen.main.bounds
            background?.image = backgroundImage.getBackground(screenBound.size)
        }
        
        airViewWidthConstraint?.constant = view.frame.size.width >= 1024 ? 460 : 320
        
        todayBanditTally = dataModel.banditTally
        todayApacheTally = dataModel.apacheTally
        todayTotalTally = dataModel.totalTally
        todayUnflownCadetsTally = dataModel.todayUnflownCadetsTally
        
        dataModel.apacheTally = apacheTally
        dataModel.banditTally = banditTally
        dataModel.totalTally = totalTally
        dataModel.uploadsInProgress = uploadsInProgress
        dataModel.downloadsInProgress = downloadsInProgress
        dataModel.todayUnflownCadetsTally = unflownCadetsTally
        
        NotificationQueue.default.enqueue(Notification(name: updateFlightCountersNotification), postingStyle: .whenIdle, coalesceMask: [.onName], forModes: nil)
        
        dataModel.pilotAreaController?.tableView.reloadData()
        
        pilotContainerView?.removeFromSuperview()
        leftSideContentView.addSubview(recordArea)
        recordArea.isHidden = false
        attendanceOrTimesheets.selectedSegmentIndex = TIMESHEETS
        
        if previousRecordsViewer
        {
            date?.title = dataModel.dateToViewRecords.militaryFormatShort
            dataModel.previousRecordsGlidingUnit = glidingUnit
            glidingUnit?.title = dataModel.previousRecordsGlidingCentre?.name
        }
            
        else
        {
            dataModel.glidingUnit = glidingUnit
            glidingUnit?.title = dataModel.glidingCentre?.name
        }
        
        super.viewWillAppear(animated)

    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if previousRecordsViewer
        {
            performSegue(withIdentifier: "changePreviousRecordsDateSegue", sender:self)
        }
    }
    
    @IBAction func sortRecords()
    {
        if previousRecordsViewer
        {
            dataModel.previousRecordsController?.sortRecords(sortMethod?.selectedSegmentIndex ?? 0)
        }
            
        else
        {
            dataModel.recordAreaController?.sortRecords(sortMethod?.selectedSegmentIndex ?? 0)
        }
    }
    
    @IBAction func previousFlightsActionButtonPressed()
    {
        if attendanceOrTimesheets.selectedSegmentIndex == ATTENDANCE
        {
            if shouldPerformSegue(withIdentifier: "PilotOptionsSegue", sender:self)
            {
                performSegue(withIdentifier: "PilotOptionsSegue", sender:self)
            }
        }
            
        else
        {
            if shouldPerformSegue(withIdentifier: "RecordOptionsSegue", sender:self)
            {
                performSegue(withIdentifier: "RecordOptionsSegue", sender:self)
            }
        }
    }
    
    @objc func presentPilotOptions()
    {
        if attendanceOrTimesheets.selectedSegmentIndex == ATTENDANCE
        {
            if let _ = presentedViewController
            {
                dismiss(animated: true, completion:nil)
            }
                
            else
            {
                guard let pilotOptionsNavController = storyboard?.instantiateViewController(withIdentifier: "PilotOptionsNavController") else {return}
                pilotOptionsNavController.modalPresentationStyle = .popover
                
                present(pilotOptionsNavController, animated:true, completion:nil)
                let presentationController = pilotOptionsNavController.popoverPresentationController
                
                guard let frame = leftView?.frame else {return}
                let targetFrame = CGRect(x: frame.width - 52, y: 0, width: 44, height: 44)
                presentationController?.sourceView = leftNavBar
                presentationController?.sourceRect = targetFrame
                presentationController?.permittedArrowDirections = .up
            }
        }
            
        else
        {
            if let _ = presentedViewController
            {
                dismiss(animated: true, completion:nil)
            }
                
            else
            {
                guard let recordOptionsNavController = storyboard?.instantiateViewController(withIdentifier: "RecordOptionsNavController") as? UINavigationController else {return}
                recordOptionsNavController.modalPresentationStyle = .popover
                
                present(recordOptionsNavController, animated:true, completion:nil)
                let presentationController = recordOptionsNavController.popoverPresentationController
                
                guard let frame = leftView?.frame else {return}
                let targetFrame = CGRect(x: frame.width - 52, y: 0, width: 44, height: 44)
                presentationController?.sourceView = leftNavBar
                presentationController?.sourceRect = targetFrame
                presentationController?.permittedArrowDirections = .up
            }
        }
    }
    
    @IBAction func dismissPopover(_ segue: UIStoryboardSegue)
    {
        if let _ = presentedViewController
        {
            dismiss(animated: true, completion:nil)
        }
    }
    
    @IBAction func addFlight(_ segue: UIStoryboardSegue)
    {
        if dataModel.editorSignInTime < Date() - 30*60
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
                self.addFlight(segue)
            }
            
            signInAlert.addAction(proceedAction)
            signInAlert.addTextField(){textField in textField.placeholder = "Name"}
            signInAlert.addTextField(){textField in textField.placeholder = "License Number"}
            
            present(signInAlert, animated: true)
            return
        }
        
        let messageTitle = observerMode ? "Cannot Add Flight" : "Add Flight?"
        let messageString = observerMode ? "You cannot add flights as an observer of a remote database." : "This will add a one minute flight to the desired day at 2300 with a random crew. You will be responsible for adjusting the aircraft, crew, times, sequence, and journey log times to the desired values. This is not recommended and will require extreme care."
        let alert = UIAlertController(title: messageTitle, message: messageString, preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                
        alert.addAction(cancelButton)
        
        if observerMode == false
        {
            let towButton = UIAlertAction(title: "Add Tow Aircraft Flight", style: .destructive){_ in self.createRandomFlightForType(.towplane)}
            let airTowFlight = UIAlertAction(title: "Add Air Tow Flight", style: .destructive){_ in self.createRandomFlightForType(.glider)}
            let winchFlight = UIAlertAction(title: "Add Winch Flight", style: .destructive){_ in self.createRandomFlightForType(.winch)}
            let autoTowFlight = UIAlertAction(title: "Add Auto Tow Flight", style: .destructive){_ in self.createRandomFlightForType(.auto)}

            alert.addAction(towButton)
            alert.addAction(airTowFlight)
            alert.addAction(winchFlight)
            alert.addAction(autoTowFlight)
        }

        present(alert, animated:true, completion:nil)
    }
    
    func createRandomFlightForType(_ type: VehicleType)
    {
        let pilots = dataModel.glidingCentre.pilots
        
        func newTimeSheetForAircraft(_ ac: AircraftEntity) -> AircraftTimesheet
        {
            let newTimesheet = AircraftTimesheet(context: dataModel.managedObjectContext)
            newTimesheet.date = dataModel.dateToViewRecords.startOfDay + 60*60*23
            newTimesheet.aircraft = ac
            newTimesheet.glidingCentre = dataModel.previousRecordsGlidingCentre
            newTimesheet.setTTSN()
            
            return newTimesheet
        }
        
        func randomTowplane() -> AircraftEntity?
        {
            for aircraft in dataModel.glidingCentre.aircraft
            {
                if aircraft.type == .towplane
                {
                    return aircraft
                }
            }
            
            return nil
        }
        
        func randomGlider() -> AircraftEntity?
        {
            for aircraft in dataModel.glidingCentre.aircraft
            {
                if aircraft.type == .glider
                {
                    return aircraft
                }
            }
            
            return nil
        }
        
        func randomWinch() -> AircraftEntity?
        {
            for aircraft in dataModel.glidingCentre.aircraft
            {
                if aircraft.type == .winch
                {
                    return aircraft
                }
            }
            
            return nil
        }
        
        func randomAuto() -> AircraftEntity?
        {
            for aircraft in dataModel.glidingCentre.aircraft
            {
                if aircraft.type == .auto
                {
                    return aircraft
                }
            }
            
            return nil
        }
        
        func throwAlert(forType type: VehicleType)
        {
            let alert = UIAlertController(title:"No Vehicle Available", message:"You must have at least one \(type) signed in to \(dataModel.previousRecordsGlidingCentre?.name ?? dataModel.glidingCentre.name) before you can add a \(type) flight.", preferredStyle:.alert)
            let done = UIAlertAction(title: "OK", style: .default, handler:nil)
            alert.addAction(done)
            self.present(alert, animated:true, completion:nil)
        }
        
        func throwAlertForMissingPilot()
        {
            let alert = UIAlertController(title:"No Pilot Available", message:"You must have at least one pilot signed in to \(dataModel.previousRecordsGlidingCentre?.name ?? dataModel.glidingCentre.name) before you can add flight.", preferredStyle:.alert)
            let done = UIAlertAction(title: "OK", style: .default, handler:nil)
            alert.addAction(done)
            self.present(alert, animated:true, completion:nil)
        }
        
        guard let randomPilot = pilots.first else {throwAlertForMissingPilot(); return}
        
        switch type
        {
        case .towplane:
            guard let aircraft = randomTowplane() else {throwAlert(forType: .towplane); return}
            let timesheet = newTimeSheetForAircraft(aircraft)
            let record = FlightRecord(context: dataModel.managedObjectContext)
            record.flightSequence = aircraft.flightSequence
            record.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
            record.timeDown = record.timeUp + 60
            record.pilot = randomPilot
            record.picParticipantType = record.pilot.typeOfParticipant
            record.timesheet = timesheet
            timesheet.logInsertionOf(record: record)

        case .glider:
            guard let towaircraft = randomTowplane() else {throwAlert(forType: .towplane); return}
            let towTimesheet = newTimeSheetForAircraft(towaircraft)
            
            guard let glider = randomGlider() else {throwAlert(forType: .glider); return}
            let gliderTimesheet = newTimeSheetForAircraft(glider)
            let towRecord = FlightRecord(context: dataModel.managedObjectContext)
            
            towRecord.flightSequence = "Towing"
            towRecord.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
            towRecord.timeDown = towRecord.timeUp + 60
            towRecord.pilot = randomPilot
            towRecord.picParticipantType = towRecord.pilot.typeOfParticipant
            towRecord.timesheet = towTimesheet
            towTimesheet.logInsertionOf(record: towRecord)

            let gliderRecord = FlightRecord(context: dataModel.managedObjectContext)
            gliderRecord.aircraft = glider
            gliderRecord.flightSequence = glider.flightSequence
            gliderRecord.timeUp = towRecord.timeUp
            gliderRecord.timeDown = towRecord.timeDown
            gliderRecord.pilot = randomPilot
            gliderRecord.picParticipantType = randomPilot.typeOfParticipant
            gliderRecord.timesheet = gliderTimesheet
            gliderRecord.connectedAircraftRecord = towRecord
            gliderTimesheet.logInsertionOf(record: gliderRecord)

            
        case .auto:
            guard let auto = randomAuto()  else {throwAlert(forType: .auto); return}
            let autoTimesheet = newTimeSheetForAircraft(auto)
            
            guard let glider = randomGlider()  else {throwAlert(forType: .glider); return}
            let gliderTimesheet = newTimeSheetForAircraft(glider)
            
            let towRecord = FlightRecord(context: dataModel.managedObjectContext)
            towRecord.flightSequence = "Towing"
            towRecord.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
            towRecord.timeDown = towRecord.timeUp + 60
            towRecord.pilot = randomPilot
            towRecord.picParticipantType = towRecord.pilot.typeOfParticipant
            towRecord.timesheet = autoTimesheet
            autoTimesheet.logInsertionOf(record: towRecord)

            let gliderRecord = FlightRecord(context: dataModel.managedObjectContext)
            gliderRecord.aircraft = glider
            gliderRecord.flightSequence = glider.flightSequence
            gliderRecord.timeUp = towRecord.timeUp
            gliderRecord.timeDown = towRecord.timeDown
            gliderRecord.pilot = randomPilot
            gliderRecord.picParticipantType = randomPilot.typeOfParticipant
            gliderRecord.timesheet = gliderTimesheet
            gliderRecord.connectedAircraftRecord = towRecord
            gliderTimesheet.logInsertionOf(record: gliderRecord)
            
        case .winch:
            guard let winch = randomWinch()  else {throwAlert(forType: .winch); return}
            let winchTimesheet = newTimeSheetForAircraft(winch)
            
            guard let glider = randomGlider()  else {throwAlert(forType: .glider); return}
            let gliderTimesheet = newTimeSheetForAircraft(glider)
            
            let towRecord = FlightRecord(context: dataModel.managedObjectContext)
            towRecord.flightSequence = "Towing"
            towRecord.timeUp = dataModel.dateToViewRecords.startOfDay + 60*60*23
            towRecord.timeDown = towRecord.timeUp + 60
            towRecord.pilot = randomPilot
            towRecord.picParticipantType = towRecord.pilot.typeOfParticipant
            towRecord.timesheet = winchTimesheet
            winchTimesheet.logInsertionOf(record: towRecord)

            let gliderRecord = FlightRecord(context: dataModel.managedObjectContext)
            gliderRecord.aircraft = glider
            gliderRecord.flightSequence = glider.flightSequence
            gliderRecord.timeUp = towRecord.timeUp
            gliderRecord.timeDown = towRecord.timeDown
            gliderRecord.pilot = randomPilot
            gliderRecord.picParticipantType = randomPilot.typeOfParticipant
            gliderRecord.timesheet = gliderTimesheet
            gliderRecord.connectedAircraftRecord = towRecord
            gliderTimesheet.logInsertionOf(record: gliderRecord)
        }
        
        dataModel.saveContext()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool
    {
        if identifier == "changePreviousRecordsDateSegue"
        {
            return true
        }
        
        if let _ = presentedViewController
        {
            dismiss(animated: true, completion:nil)
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {return}
        
        switch segueIdentifer
        {
            case .ChangeUnitiPadSegue:
                let navController = segue.destination as? UINavigationController
                let changeGC = navController?.topViewController as? SelectGlidingCentre
                changeGC?.currentGlidingCentre = previousRecordsViewer ? dataModel.previousRecordsGlidingCentre!.name : dataModel.glidingCentre.name

            case .EmbedRecordsSegue:
                guard let recordAreaController =  segue.destination as? Records else {return}
                addChild(recordAreaController)
                recordAreaController.sortMethod = sortMethod
                actionButton?.action = #selector(iPadRootViewController.presentPilotOptions)

            case .EmbedPilotsSegue:
                guard let pilotAreaController = segue.destination as? PilotsController else {return}
                addChild(pilotAreaController)
        }
    }
    
    deinit
    {
        dataModel.apacheTally = todayApacheTally
        dataModel.banditTally = todayBanditTally
        dataModel.totalTally = todayTotalTally
        dataModel.todayUnflownCadetsTally = todayUnflownCadetsTally
        dataModel.configureFlightCounters()
    }
}
