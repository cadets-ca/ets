//
//  ChangeRGSFlight.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-22.
//
//

import Foundation
import UIKit
import CoreData

final class ChangeRGSflight : UITableViewController
{
    var pilot: Pilot!
    var flightNames: [String] = [String]()
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        var flightInfo = CampFlightInfo.initalizeFlightInfoList()
        flightInfo = CampFlightInfo.filterToCurrentRegion(flightInfo)
        flightNames = Array(flightInfo.keys)
        flightNames.sort(by: <)
        flightNames.insert("None", at: 0)
    }
        
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
  
    //MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return flightNames.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let flightName = flightNames[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = flightName
        
        switch pilot.summerUnit
        {
        case .none:
            cell.accessoryType = (indexPath as NSIndexPath).row > 0 ? .none : .checkmark

        case .some(let unit) where unit.name == flightName:
            cell.accessoryType = .checkmark
            
        default:
            cell.accessoryType = .none
        }
        
        let GCImage = UIImage(named: flightName)
        cell.imageView?.image = GCImage
        
        return cell
    }
    
    //MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let unit = flightNames[(indexPath as NSIndexPath).row]
        
        if unit == "None"
        {
            pilot.summerUnit = nil
        }
        
        else
        {
            let flightRequest = SummerUnit.request
            flightRequest.predicate = NSPredicate(format: "name == %@", unit)
            let availableflights = try! dataModel.managedObjectContext.fetch(flightRequest) 
            
            if availableflights.count > 0
            {
                pilot.summerUnit = availableflights.first
            }
                
            else
            {
                let newUnit = SummerUnit(context: dataModel.managedObjectContext)
                newUnit.name = unit
                pilot.summerUnit = newUnit
            }
        }
        
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        let _ = navigationController?.popViewController(animated: true)
    }
}
