//
//  ChangeVehicle.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-31.
//
//

import Foundation
import UIKit
import CoreData

final class ChangeVehicle: UITableViewController
{
    var vehicleList = [AircraftEntity]()
    var record: FlightRecord!
    
    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        let request = AircraftEntity.request
        request.predicate = NSPredicate(format: "gliderOrTowplane == %d", record.timesheet.aircraft.type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(AircraftEntity.tailNumber), ascending: true)]
        vehicleList = try! dataModel.managedObjectContext.fetch(request)
        vehicleList.sort(by: numericSearch)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        addOrRemoveDoneButtonGivenTraitCollection(presentingViewController?.traitCollection, controller: self, withDoneButtonAction: "addAircraftDone")
        tableView.layoutIfNeeded()
        preferredContentSize = CGSize(width: 320, height: self.tableView.contentSize.height)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(previousTraitCollection, controller: self, withDoneButtonAction: "addAircraftDone")
    }
    
    //MARK: - Utility Methods
    @objc func addAircraftDone()
    {
        self.dismiss(animated: true, completion:nil)
    }
    
    //MARK: - UITableView Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if let cell = tableView.cellForRow(at: indexPath), cell.accessoryType == .none
        {
            let vehicle = vehicleList[(indexPath as NSIndexPath).row]
            let glidingCentre = dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre
            
            let request = AircraftTimesheet.request
            request.predicate = NSPredicate(format: "aircraft == %@ AND date > %@ AND date < %@ AND glidingCentre.name == %@", argumentArray: [vehicle, Date().startOfDay, Date().startOfDay + 24*60*60, glidingCentre!.name])
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: true)]
            guard let timesheets = try? dataModel.managedObjectContext.fetch(request) else {return}
            
            if let timesheet = timesheets.last
            {
                record.timesheet = timesheet
            }
            
            else
            {
                let newTimesheet = AircraftTimesheet(context: dataModel.managedObjectContext)
                newTimesheet.aircraft = vehicle
                newTimesheet.date = record.timeUp
                newTimesheet.glidingCentre = glidingCentre
                newTimesheet.setTTSN()

                if newTimesheet.date.isDateInToday
                {
                    newTimesheet.currentAircraft = vehicle
                }
                
                record.timesheet = newTimesheet
            }
            
            dataModel.saveContext()
            presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return vehicleList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let vehicle = vehicleList[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = vehicle.tailNumber
        cell.accessoryType = vehicle === record.timesheet?.aircraft ? .checkmark : .none
        return cell
    }
}
