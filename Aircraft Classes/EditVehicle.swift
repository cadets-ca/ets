//
//  EditVehicle.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-11.
//
//

import Foundation
import UIKit

final class EditVehicle: UITableViewController, ChangeSignificantDateDelegate
{
    var indexPath: IndexPath?
    var aircraftBeingEdited: AircraftEntity!
    @IBOutlet var pilot: UITableViewCell!
    @IBOutlet var passenger: UITableViewCell!
    @IBOutlet var sequence: UITableViewCell?
    @IBOutlet var connectedAircraft: UITableViewCell?
    @IBOutlet var TNI: UITableViewCell?
    @IBOutlet var upTime: TableViewCellStylePicker?
    @IBOutlet var maintenanceIssues: UITableViewCell?
    @IBOutlet var beaconNumber: BeaconNumberCell?
    private var customDatePicker: ChangeSignificantDate?

    enum SegueIdentifiers: String
    {
        case ChangePilotForAircraftSegue = "ChangePilotForAircraftSegue"
        case ChangePassengerForAircraftSegue = "ChangePassengerForAircraftSegue"
        case ChangeSequenceForAircraftSegue = "ChangeSequenceForAircraftSegue"
        case MaintenanceSegue = "MaintenanceSegue"
        case ChangeTowplaneOrGliderForAircraftSegue = "ChangeTowplaneOrGliderForAircraftSegue"
        case ChangeWinchOperatorForAircraftSegue = "ChangeWinchOperatorForAircraftSegue"
        case ChangeAutoOperatorForAircraftSegue = "ChangeAutoOperatorForAircraftSegue"
        case ListMaintenanceIssuesSegue = "ListMaintenanceIssuesSegue"
        case ViewJourneyLogEntrieSegue = "ViewJourneyLogEntrieSegue"
    }
    
    //MARK: - UIViewController Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .ChangePilotForAircraftSegue:
            let changePilot = segue.destination as? ChangePilotPopover
            changePilot?.indexPathBeingEdited = indexPath
            changePilot?.yesMeansRecord = false
            changePilot?.aircraftBeingEdited = aircraftBeingEdited

        case .ChangePassengerForAircraftSegue:
            let changePassenger = segue.destination as? ChangePassengerPopover
            changePassenger?.indexPathBeingEdited = indexPath
            changePassenger?.yesMeansRecord = false
            changePassenger?.aircraftBeingEdited = aircraftBeingEdited
        
        case .ChangeSequenceForAircraftSegue:
            let changeSequence = segue.destination as? ChangeSequence
            changeSequence?.aircraftBeingEdited = aircraftBeingEdited

        case .MaintenanceSegue:
            let options = segue.destination as? MaintenanceOptions
            options?.aircraftBeingEdited = aircraftBeingEdited
        
        case .ChangeTowplaneOrGliderForAircraftSegue:
            let changeTowplaneOrGlider = segue.destination as? ChangeAttachedVehicle
            changeTowplaneOrGlider?.aircraftBeingEdited = aircraftBeingEdited
            let type = aircraftBeingEdited.type
            changeTowplaneOrGlider?.title = type == .glider ? "Launch Method" : "Glider"

        case .ChangeWinchOperatorForAircraftSegue, .ChangeAutoOperatorForAircraftSegue:
            let changeOperator = segue.destination as? ChangeOperator
            changeOperator?.indexPathBeingEdited = indexPath
            changeOperator?.yesMeansRecord = false
            changeOperator?.aircraftBeingEdited = aircraftBeingEdited

        case .ListMaintenanceIssuesSegue:
            let list = segue.destination as? ListMaintenanceIssues
            list?.aircraftBeingEdited = aircraftBeingEdited

        case .ViewJourneyLogEntrieSegue:
            let list = segue.destination as? ViewJourneyLogEntries
            list?.aircraftBeingEdited = aircraftBeingEdited
        }
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        addOrRemoveDoneButtonGivenTraitCollection(presentingViewController?.traitCollection, controller: self, withDoneButtonAction: "done")

        pilot.textLabel?.text = aircraftBeingEdited.pilot?.fullName
        passenger.textLabel?.text = aircraftBeingEdited.passenger?.fullName
        sequence?.textLabel?.text = aircraftBeingEdited.flightSequence
        upTime?.label.text = aircraftBeingEdited.currentRecord?.timeUp.hoursAndMinutes
        TNI?.detailTextLabel?.text = "Next inspection \(dataModel.aircraftAreaController!.calculateTNIforAircraft(aircraftBeingEdited)) hours"
        let numberOfIssues = aircraftBeingEdited.maintenanceItems.count
        let issuesString = (numberOfIssues == 1) ? "1 Issue" : "\(numberOfIssues) Issues"
        maintenanceIssues?.detailTextLabel?.text = issuesString
        beaconNumber?.beaconNumber?.text = "\(aircraftBeingEdited.beaconNumber)"
        beaconNumber?.stepper.value = Double(aircraftBeingEdited.beaconNumber)
        
        self.tableView.reloadData()
    }
    
    @IBAction func beaconNumberChanged()
    {
        aircraftBeingEdited.beaconNumber = Int16(beaconNumber!.stepper.value)
        dataModel.saveContext()
        dataModel.beaconManager.beginMonitoringForBeacons()
        beaconNumber?.beaconNumber?.text = "\(aircraftBeingEdited.beaconNumber)"
        beaconNumber?.stepper.value = Double(aircraftBeingEdited.beaconNumber)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(previousTraitCollection, controller: self, withDoneButtonAction: "done")
    }
    
    @objc func done()
    {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad()
    {
        if let _ = aircraftBeingEdited.connectedAircraft, aircraftBeingEdited.status == .landed
        {
            let unhookButton = UIBarButtonItem(title: "Unhook", style: .done, target: self, action: #selector(EditVehicle.unhook))
            navigationItem.leftBarButtonItem = unhookButton
        }
    }
    
    //MARK: - UITableViewController Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cell = tableView.cellForRow(at: indexPath)
        var cellCanAccomodateDatePicker = false
        
        if cell == upTime
        {
            cellCanAccomodateDatePicker = true
        }
        
        if cellCanAccomodateDatePicker
        {
            if let picker = customDatePicker
            {
                let previouslySelectedCell = picker.tableViewCell as? TableViewCellStylePicker
                
                previouslySelectedCell?.removePickerFromStackView()
                customDatePicker = nil

                if previouslySelectedCell !== cell
                {
                    self.addPickerToCell(cell, atIndexPath:indexPath)
                }
                
                tableView.beginUpdates()
                tableView.endUpdates()
            }
            
            else
            {
                addPickerToCell(cell, atIndexPath: indexPath)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated:true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    //MARK: - Custom Methods
    private func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        guard let cell = cell as? TableViewCellStylePicker, let indexPath = indexPath else {return}
        
        switch (indexPath as NSIndexPath).section
        {
            case 0:
                customDatePicker =  ChangeTime(record: aircraftBeingEdited.currentRecord!, upOrDown: .uptime, aircraftIsFlying: true)
            
        default:
            break
        }
        
        cell.addPickerToStackView(customDatePicker!)
        customDatePicker?.delegate = self
        
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func dateChanged()
    {
        self.viewWillAppear(false)
    }
    
    @objc func unhook()
    {
        presentingViewController?.dismiss(animated: true){
            self.aircraftBeingEdited.connectedAircraft = nil
            dataModel.currentlySelectedCell = nil
            self.aircraftBeingEdited.sectionIndex = Int16(dataModel.aircraftFetchedResults?.sections?.count ?? 0)
            dataModel.saveContext()
            }
    }
}
