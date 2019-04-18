//
//  Leaderboards.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2018-06-05.
//

import UIKit
import CloudKit

class Leaderboards: UITableViewController
{
    var cloudKitController: CloudKitControllerTV!
    var siteData = [String: SiteInfo]()
    
    class SiteInfo
    {
        var minutes = 0
        var seasonFlights = 0
        var todayFlights = 0
        var weekendFlights = 0
        var incompleteFlights = 0
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
//        title = "Leaderboards"
        cloudKitController = (UIApplication.shared.delegate as! AppDelegate).cloudKitController
        NotificationCenter.default.addObserver(self, selector: #selector(self.prepareRecords), name: newDataNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        if siteData.count == 0
        {
            prepareRecords()
        }
    }
    
    @objc func prepareRecords()
    {
        let fiveDaysAgo = (Date() - 60*60*24*5).midnight
        
        for record in cloudKitController.allRecordsThisSeason
        {
            let data = record.data
            let gc = data.glidingCenter
            let gcData = siteData[gc] ?? SiteInfo()
                
            if siteData[gc] == nil
            {
                siteData[gc] = gcData
            }
            
            if data.timeDown > Date()
            {
                gcData.incompleteFlights += 1
            }
            
            if data.gliderOrTowplane == .glider
            {
                gcData.seasonFlights += 1
                gcData.minutes += data.flightLengthInMinutes
                
                if data.timeUp > fiveDaysAgo
                {
                    gcData.weekendFlights += 1
                }
                
                if data.timeUp > Date().midnight
                {
                    gcData.todayFlights += 1
                }
            }
        }
        
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return siteData.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var siteDataKeys = Array(siteData.keys)
        
        switch indexPath.section
        {
        case 0:
            siteDataKeys.sort(by: {siteData[$0]!.seasonFlights > siteData[$1]!.seasonFlights})

        case 1:
            siteDataKeys.sort(by: {siteData[$0]!.minutes > siteData[$1]!.minutes})

        default:
            siteDataKeys.sort(by: {siteData[$0]!.weekendFlights > siteData[$1]!.weekendFlights})
        }
        
        let siteName = siteDataKeys[indexPath.row]
        guard let data = siteData[siteName] else {return cell}
        
        switch indexPath.section
        {
        case 0:
            cell.textLabel?.text = siteName
            var detailText = "\(data.seasonFlights)"
            if data.incompleteFlights > 0
            {
                detailText += " (\(data.incompleteFlights) Incomplete)"
            }
            cell.detailTextLabel?.text = detailText
            
            let GCImage = UIImage(named: siteName)
            cell.imageView?.image = GCImage

        case 1:
            cell.textLabel?.text = siteName
            cell.detailTextLabel?.text = String(fromMinutes: Double(data.minutes))
            let GCImage = UIImage(named: siteName)
            cell.imageView?.image = GCImage

        default:
            let fiveDaysAgo = (Date() - 60*60*24*5).midnight
            cell.textLabel?.text = siteName
            cell.detailTextLabel?.text = "\(data.todayFlights) (\(data.weekendFlights) Since \(fiveDaysAgo.militaryFormatLong))"
            let GCImage = UIImage(named: siteName)
            cell.imageView?.image = GCImage
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch section
        {
        case 0:
            return "Flight this Season"
        case 1:
            return "Hours this Season"
        case 2:
            return "Today's Flying"
            
        default:
            return nil
        }
    }
}

