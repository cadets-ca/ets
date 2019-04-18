//
//  ChangeGlidingCentreForTimesheet.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-07.
//
//

import Foundation
import UIKit
import CoreData

final class ChangeGlidingCentreForTimesheet : UITableViewController
{
    var timesheet: AircraftTimesheet!
    var glidingCentreCoordinates = [String: GlidingCentreInfo]()
    var glidingCentreNames = [String]()

    //MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        glidingCentreCoordinates = GlidingCentreInfo.initalizeGCInfoList()
        glidingCentreCoordinates = GlidingCentreInfo.filterToCurrentRegion(glidingCentreCoordinates)
        
        glidingCentreNames = Array(glidingCentreCoordinates.keys)
        glidingCentreNames.sort(by: <)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return glidingCentreNames.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let GCname = glidingCentreNames[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = GCname
        cell.detailTextLabel?.text = glidingCentreCoordinates[GCname]?.fullName
        cell.accessoryType = timesheet.glidingCentre?.name == GCname ? .checkmark : .none
        
        let GCImage = UIImage(named: GCname)
        cell.imageView?.image = GCImage
        
        return cell
    }
    
    //MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let unit = glidingCentreNames[(indexPath as NSIndexPath).row]
        
        let GCRequest = GlidingCentre.request
        GCRequest.predicate = NSPredicate(format: "name == %@", unit)
        guard let availableGCs = try? dataModel.managedObjectContext.fetch(GCRequest) else {return}
        
        if let gcFound = availableGCs.first
        {
            timesheet.glidingCentre = gcFound
        }
            
        else
        {
            let glidingCentre = GlidingCentre(context: dataModel.managedObjectContext)
            glidingCentre.name = unit
            timesheet.glidingCentre = glidingCentre
        }
        
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        dataModel.saveContext()
        let _ = navigationController?.popViewController(animated: true)
    }
}
