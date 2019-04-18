//
//  ChangeSequence.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-09.
//
//

import Foundation
import UIKit

final class ChangeSequence: UITableViewController
{
    private var possibleSequences = [String]()
    private var yesMeansRecord = false
    var aircraftBeingEdited: AircraftEntity!
    var flightRecord: FlightRecord!

    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        yesMeansRecord = (aircraftBeingEdited == nil) ? true : false
        
        let vehicleValue: Int = yesMeansRecord ? Int(flightRecord.timesheet.aircraft.gliderOrTowplane) : Int(aircraftBeingEdited.gliderOrTowplane)
        
        if let type = VehicleType(rawValue: vehicleValue)
        {
            if type == .towplane
            {
                if let towSequenceFilePath = Bundle.main.path(forResource: "TowplaneSequences", ofType:"plist")
                {
                    possibleSequences = NSArray(contentsOfFile: towSequenceFilePath) as? [String] ?? [String]()
                }
            }
                
            else
            {
                if let gliderSequenceFilePath = Bundle.main.path(forResource: "GliderSequences", ofType:"plist")
                {
                    possibleSequences = NSArray(contentsOfFile: gliderSequenceFilePath) as? [String] ?? [String]()
                }
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableViewController Methods
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return possibleSequences.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        
        
        let cell = tableView.cellForRow(at: indexPath)
        if cell?.accessoryType == .checkmark
        {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if yesMeansRecord
        {
            flightRecord.flightSequence = cell?.textLabel?.text ?? ""
        }
            
        else
        {
            aircraftBeingEdited.flightSequence = cell?.textLabel?.text ?? ""
            
            if aircraftBeingEdited.inTheAir
            {
                aircraftBeingEdited.currentRecord?.flightSequence = cell?.textLabel?.text ?? ""
                NotificationCenter.default.post(name: flightRecordsChangedNotification, object: aircraftBeingEdited.currentRecord, userInfo: nil)
            }
        }
        
        dataModel.saveContext()
        let _ = navigationController?.popViewController(animated: true)
        NotificationCenter.default.post(name: aircraftChangedNotification, object:aircraftBeingEdited, userInfo:nil)

    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = possibleSequences[(indexPath as NSIndexPath).row]
        let currentSequence = yesMeansRecord ? flightRecord.flightSequence : aircraftBeingEdited.flightSequence
        cell.accessoryType = currentSequence != possibleSequences[(indexPath as NSIndexPath).row] ? .none : .checkmark
        return cell
    }
}
