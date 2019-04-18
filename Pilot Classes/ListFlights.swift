//
//  ListFlights.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-22.
//
//

import Foundation
import UIKit

final class ListFlights : UITableViewController
{
    var pilot: Pilot!
    lazy var gliderRecordBackground: UIImage = {UIImage(assetIdentifier: .YellowCell)}()
    lazy var scoutRecordBackground: UIImage = {UIImage(assetIdentifier: .BlueCell)}()
    lazy var winchRecordBackground: UIImage = {UIImage(assetIdentifier: .GreenCell)}()
    lazy var autoRecordBackground: UIImage = {UIImage(assetIdentifier: .RedCell)}()
    var records = [FlightRecord]()

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        for record in pilot.picFlights
        {
            records.append(record)
        }
        
        for record in pilot.dualFlights
        {
            records.append(record)
        }
        records.sort {$0.timeUp > $1.timeUp}
        tableView.allowsSelection = false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return records.count
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let record = records[(indexPath as NSIndexPath).row]
        guard let type = record.timesheet?.aircraft?.type else {return}
        
        switch type
        {
        case .glider:
            cell.backgroundView = UIImageView(image: gliderRecordBackground)
            
        case .towplane:
            cell.backgroundView = UIImageView(image: scoutRecordBackground)
            
        case .winch:
            cell.backgroundView = UIImageView(image: winchRecordBackground)
            
        case .auto:
            cell.backgroundView = UIImageView(image: autoRecordBackground)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let record = records[(indexPath as NSIndexPath).row]
        
        var label = cell.viewWithTag(1) as? UILabel
        label?.text = record.timesheet?.aircraft?.tailNumber
        
        label = cell.viewWithTag(2) as? UILabel
        label?.text = record.pilot?.uniqueName
        
        label = cell.viewWithTag(3) as? UILabel
        label?.text = record.passenger?.uniqueName

        label = cell.viewWithTag(5) as? UILabel
        label?.text = record.flightSequence == "Transit" ? record.transitRoute : record.flightSequence
        
        label = cell.viewWithTag(6) as? UILabel
        let upTime = record.timeUp.hoursAndMinutes
        let downTime = record.timeDown == Date.distantFuture ? " ?" : record.timeDown.hoursAndMinutes
        let upAndDownTimes = upTime + "-" + downTime
        label?.text = upAndDownTimes
        
        label = cell.viewWithTag(7) as? UILabel
        let flightTimeInMinutes = Double(record.flightLengthInMinutes)
        label?.text = String(fromMinutes: flightTimeInMinutes)
        
        label = cell.viewWithTag(10) as? UILabel
        label?.text = record.timeUp.militaryFormatShort
        
        return cell
    }
}
