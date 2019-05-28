//
//  TodayViewController.swift
//  Hours This Season
//
//  Created by Paul Kirvan on 2016-09-27.
//
//

import UIKit
import NotificationCenter

import UIKit
import NotificationCenter

final class HoursThisSeason: UITableViewController, NCWidgetProviding
{
    let keyValueStore = NSUbiquitousKeyValueStore.default
    var activeGlidingCentres = [GlidingCentreData]()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        tableView.estimatedRowHeight = 44
        extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInfo), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)

    }
    
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void)
    {
        updateInfo()
        completionHandler(NCUpdateResult.newData)
    }
    
    @objc func updateInfo()
    {
        activeGlidingCentres.removeAll(keepingCapacity: true)
        let keyValueStoreData = keyValueStore.dictionaryRepresentation
        
        for gcName in keyValueStoreData.keys
        {
            let gcDataDictionary = keyValueStoreData[gcName] as! [String: AnyObject]
            let processedData = GlidingCentreData(name: gcName, gcData: gcDataDictionary)
            print("\(processedData)")
            
            if processedData.activeInLast100Days == true
            {
                activeGlidingCentres.append(processedData)
                print("The GC name \(processedData.gcName)")
            }
        }
        
        activeGlidingCentres.sort(by: {$0.minutesThisSeason > $1.minutesThisSeason})
        preferredContentSize = CGSize(width: 0, height: tableView.contentSize.height)
        
        let controller = NCWidgetController()
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {return}
        
        controller.setHasContent(true, forWidgetWithBundleIdentifier: bundleIdentifier)
        tableView.reloadData()
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize)
    {
        switch activeDisplayMode
        {
        case NCWidgetDisplayMode.compact:
            preferredContentSize = maxSize
            
        case NCWidgetDisplayMode.expanded:
            preferredContentSize = CGSize(width: 0, height: tableView.contentSize.height)
        @unknown default:
            fatalError()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StandardCell", for: indexPath)
        
        let nameOfGC = activeGlidingCentres[indexPath.row].gcName
        let numberOfMinutesFlownForGC = activeGlidingCentres[indexPath.row].minutesThisSeason
        let hourString = String(fromMinutes: Double(numberOfMinutesFlownForGC))
        cell.textLabel?.text = nameOfGC
        cell.detailTextLabel?.text = hourString + " Hours"
        let GCImage = UIImage(named: nameOfGC)
        cell.imageView?.image = GCImage

        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return activeGlidingCentres.count
    }
}
