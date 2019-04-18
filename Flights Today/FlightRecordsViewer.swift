//
//  FlightRecordsViewer.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-18.
//

import UIKit
import CloudKit

class FlightRecordsViewer: UIViewController, UITableViewDelegate, UITableViewDataSource, siteSelectionDelegate
{
    var cloudKitController: CloudKitControllerTV!
    var siteSelector: SiteSelection!
    @IBOutlet var tableView: UITableView!
    var records = [CKRecord]()
    lazy var gliderRecordBackground: UIImage = UIImage(assetIdentifier: .YellowCell)
    lazy var scoutRecordBackground: UIImage = UIImage(assetIdentifier: .BlueCell)
    lazy var winchRecordBackground: UIImage = UIImage(assetIdentifier: .GreenCell)
    lazy var autoRecordBackground: UIImage = UIImage(assetIdentifier: .RedCell)
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        parent?.parent?.title = "Flight Records"
        cloudKitController = (UIApplication.shared.delegate as! AppDelegate).cloudKitController
        NotificationCenter.default.addObserver(self, selector: #selector(self.prepareRecords), name: newDataNotification, object: nil)

    }
    
    @objc func prepareRecords()
    {
        if siteSelector.selectedRow != cloudKitController?.recordsSortedBySite.count
        {
            let data = cloudKitController!.recordsSortedBySite[siteSelector.selectedRow]
            records = data.gliderRecords + data.launcherRecords
            records.sort(by: {
                if $1["timeUp"] as! Date == $0["timeUp"] as! Date
                {
                    return $1["gliderOrTowplane"] as! Int > $0["gliderOrTowplane"] as! Int
                }
                
                else
                {
                    return $1["timeUp"] as! Date > $0["timeUp"] as! Date
                }
            })
        }
        
        else
        {
            records = Array(cloudKitController!.allRecordsToday)
            records.sort(by: {
                if $1["timeUp"] as! Date == $0["timeUp"] as! Date
                {
                    return $1["gliderOrTowplane"] as! Int > $0["gliderOrTowplane"] as! Int
                }
                    
                else
                {
                    return $1["timeUp"] as! Date > $0["timeUp"] as! Date
                }
            })
        }
        
        tableView.reloadData()
        
        let numberOfRows = tableView(tableView, numberOfRowsInSection: 0)
        if numberOfRows > 0
        {
            let path = IndexPath(row: numberOfRows - 1, section: 0)
            tableView.scrollToRow(at: path, at: .none, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        siteSelector = (parent! as! RecordsTabRootViewController).siteSelector
        siteSelector.delegate = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! FlightRecordCell
        let recordData = records[indexPath.row].data

        cell.PICname.text = recordData.pilot
        cell.passengerName.text = recordData.passenger
        cell.aircraftName.text = recordData.aircraft
        
        if recordData.flightSequence == "Towing"
        {
            cell.sequenceName.text = "Towing" + " " + recordData.connectedAircraft
        }
        
        else
        {
            cell.sequenceName.text = recordData.flightSequence
        }
        
        if siteSelector.selectedRow == siteSelector.tableView.numberOfRows(inSection: 0) - 1
        {
            let GCImage = UIImage(named: recordData.glidingCenter)
            cell.glidingCenter.image = GCImage
        }
        
        else
        {
            cell.glidingCenter.image = nil
        }
        
        let upTime = recordData.timeUp.hoursAndMinutes
        if recordData.gliderOrTowplane > .winch
        {
            let downTime = recordData.timeDown == Date.distantFuture ? " ?" : recordData.timeDown.hoursAndMinutes
            let upAndDownTimes = upTime + "-" + downTime
            cell.upAndDownTimes.text = upAndDownTimes
        }
            
        else
        {
            cell.upAndDownTimes.text = upTime
        }
        
        switch recordData.gliderOrTowplane
        {
        case .glider:
            cell.setBackgroundToColor(.yellow, withImage: gliderRecordBackground)
            
        case .towplane:
            cell.setBackgroundToColor(.defaultColor, withImage: scoutRecordBackground)
            
        case .winch:
            cell.setBackgroundToColor(.green, withImage: winchRecordBackground)
            
        case .auto:
            cell.setBackgroundToColor(.red, withImage: autoRecordBackground)
        }
        
        cell.flightLength.isHidden = false
        
        if recordData.gliderOrTowplane > .winch
        {
            let flightTimeInMinutes = Double(recordData.flightLengthInMinutes)
            cell.flightLength.text = String(fromMinutes: flightTimeInMinutes)
        }
            
        else
        {
            cell.flightLength.isHidden = true
        }

        
        return cell
    }
}
