//
//  ChangeAttachedVehicle.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-02.
//
//

import Foundation
import UIKit

final class ChangeAttachedVehicle: UITableViewController
{
    var aircraftBeingEdited: AircraftEntity!
    var aircraftList = [AircraftEntity]()

    override func viewDidLoad()
    {
        let aircraftType = aircraftBeingEdited.type
        let aircraftArray = dataModel.aircraftFetchedResults!.fetchedObjects!
        for aircraft in aircraftArray
        {
            let secondAircraftType = aircraft.type
            
            switch (aircraftType, secondAircraftType, aircraft.connectedAircraft, aircraft.status)
            {
            case (.glider, _, .none, .landed) where secondAircraftType != .glider:
                aircraftList.append(aircraft)
                
            case (_, .glider, .none, .landed) where aircraftType != .glider:
                aircraftList.append(aircraft)
                
            default:
                break
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return aircraftList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let aircraft = aircraftList[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = aircraft.tailNumber
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        presentingViewController?.dismiss(animated: true)
        {
            let aircraft = self.aircraftList[(indexPath as NSIndexPath).row]
            aircraft.connectedAircraft = self.aircraftBeingEdited
            let formerSectionIndex = aircraft.sectionIndex
            aircraft.sectionIndex = self.aircraftBeingEdited.sectionIndex
            
            let aircraftArray = dataModel.aircraftFetchedResults!.fetchedObjects!
            for someAircraft in aircraftArray
            {
                let index = someAircraft.sectionIndex
                if index > formerSectionIndex
                {
                    someAircraft.sectionIndex = index - 1
                }
            }
            
            if let selectedRow = dataModel.aircraftAreaController?.tableView.indexPathForSelectedRow
            {
                dataModel.aircraftAreaController?.tableView.deselectRow(at: selectedRow, animated: true)
            }
            
            switch aircraft.type
            {
            case .towplane:
                aircraft.flightSequence = "Towing"

            case .winch:
                aircraft.flightSequence = "Winching"

            case .glider:
                if aircraft.connectedAircraft?.type == .towplane
                {
                    aircraft.connectedAircraft?.flightSequence = "Towing"
                }
                    
                else
                {
                    aircraft.connectedAircraft?.flightSequence = (aircraft.connectedAircraft?.type == .winch) ? "Winching" : "Auto"
                }
            
            case .auto:
                aircraft.flightSequence = "Auto"
            }

            
            dataModel.saveContext()
        }
    }
}
