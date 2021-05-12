//
//  AddAircraftPopover.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-16.
//
//

import Foundation
import UIKit
import CoreData

final class AddAircraftPopover: UITableViewController
{
    var gliderList = [[String: String]]()
    var towplaneList = [[String: String]]()
    var winchList = [[String: String]]()
    var autoList = [[String: String]]()
    var allInfo = [[[String: String]]]()
    
    //MARK: - UIViewController Methods
    
    override func viewDidLoad()
    {
        accessibilityLabel = "Add Aircraft"
        tableView.accessibilityIdentifier = "List of Vehicles"
        let defaults = UserDefaults.standard
        let region = defaults.string(forKey: "Region") ?? "Prairie"
        let myfile = Bundle.main.path(forResource: "GliderList", ofType:"plist")!
        var bothAircraftList = NSArray(contentsOfFile: myfile) as! [Dictionary<String, String>]
        bothAircraftList = bothAircraftList.filter{$0["Region"] == region ? true : false}
        
        for info in bothAircraftList
        {
            let aircraftType = info["Type"] ?? ""
            
            switch aircraftType
            {
            case "Glider":
                gliderList.append(info)
                
            case "Towplane":
                towplaneList.append(info)
                
            case "Winch":
                winchList.append(info)
                
            case "Auto":
                autoList.append(info)
                
            default:
                break
            }
        }
        
        allInfo = [gliderList, towplaneList, winchList, autoList]
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        addOrRemoveDoneButtonGivenTraitCollection(presentingViewController?.traitCollection, controller: self, withDoneButtonAction: "addAircraftDone")
        tableView.layoutIfNeeded()
        preferredContentSize = CGSize(width: 320, height: tableView.contentSize.height)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "addAircraftDone")
    }
    
    //MARK: - Utility Methods
    @objc func addAircraftDone()
    {
        dismiss(animated: true, completion:nil)
    }
    
    //MARK: - UITableView Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let selectedVehicleInfo = allInfo[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        tableView.reloadRows(at: [indexPath], with: .fade)
        
        let aircraftRequest = AircraftEntity.request
        aircraftRequest.predicate = NSPredicate(format: "registration == %@", selectedVehicleInfo["Registration"] ?? "")
        guard let aircraftFound = try? dataModel.managedObjectContext.fetch(aircraftRequest) else {return}
        
        var aircraft = aircraftFound.first
        if aircraft == nil
        {
            let newAircraft = AircraftEntity(context: dataModel.managedObjectContext)
            newAircraft.registration = selectedVehicleInfo["Registration"] ?? "?"
            newAircraft.tailNumber = selectedVehicleInfo["Tail Number"] ?? "?"
            newAircraft.glidingCentre = dataModel.glidingCentre
            let type: VehicleType
            newAircraft.TTNI = 100
            
            switch selectedVehicleInfo["Type"] ?? ""
            {
            case "Towplane":
                type = .towplane
                newAircraft.TTNI = 50
                
            case "Winch":
                type = .winch
                newAircraft.flightSequence = "Winching"
                
            case "Auto":
                type = .auto
                newAircraft.flightSequence = "Auto"
                
            default:
                type = .glider
            }
            
            newAircraft.gliderOrTowplane = Int16(type.rawValue)
            aircraft = newAircraft

        }
        
        aircraft?.glidingCentre = dataModel.glidingCentre
        aircraft?.sectionIndex = Int16(dataModel.aircraftFetchedResults?.sections?.count ?? 0)
        aircraft?.tailNumber = selectedVehicleInfo["Tail Number"] ?? "?"
        
        dataModel.saveContext()
        dataModel.beaconManager.beginMonitoringForBeacons()
        tableView.reloadRows(at: [indexPath], with: .fade)
    }


    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return allInfo.count
    }
    

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return allInfo[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let registration = allInfo[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]["Registration"] ?? "?"
        let tailNumber = allInfo[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]["Tail Number"] ?? "?"
        let cell = registration == tailNumber ? tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath) : tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        cell.accessibilityIdentifier = registration
        cell.accessibilityLabel = registration
        cell.textLabel?.text = registration
        cell.detailTextLabel?.text = tailNumber
        cell.accessoryType = .none
        
        let aircraftRequest = AircraftEntity.request
        aircraftRequest.predicate = NSPredicate(format: "registration == %@",cell.textLabel!.text!)
        let aircraftUsed = try! dataModel.managedObjectContext.fetch(aircraftRequest)
        
        if let aircraft = aircraftUsed.first
        {
            if aircraft.glidingCentre != nil
            {
                cell.accessoryType = .checkmark
                cell.selectionStyle = .none
                
                if registration != tailNumber
                {
                    let oldTextLabel = cell.detailTextLabel?.text ?? ""
                    cell.detailTextLabel?.text = "\(oldTextLabel) (\(aircraft.glidingCentre!.name))"
                }
                    
                else
                {
                    let oldTextLabel = cell.textLabel?.text ?? ""
                    cell.textLabel?.text = "\(oldTextLabel) (\(aircraft.glidingCentre!.name))"
                }
            }
                
            else
            {
                cell.accessoryType = .none
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        var header: String?
        
        switch section
        {
        case 0:
            header = "Gliders"
        case 1:
            header = "Tow Aircraft"
        case 2:
            header = "Winches"
        case 3:
            header = "Auto Tow Sites"
        default:
            break
        }
        
        return header
    }
}
