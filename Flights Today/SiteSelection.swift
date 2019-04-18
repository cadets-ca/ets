//
//  SiteSelection.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-15.
//

import UIKit
import CloudKit

protocol siteSelectionDelegate
{
    func prepareRecords()
}

class SiteSelection: UITableViewController
{
    var cloudKitController: CloudKitControllerTV!
    var delegate: siteSelectionDelegate?
    var selectedRow: Int = 0
    var selectedSite = ""
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        cloudKitController = (UIApplication.shared.delegate as! AppDelegate).cloudKitController
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: newDataNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.noContentWarning), name: noDataNotification, object: nil)
    }
    
    @objc func reloadData()
    {
        self.tableView.reloadData()
    }
    
    @objc func noContentWarning()
    {
        let message = "There is no content available. You create content by creating flight records on your iPhone or iPad using the same AppleID as this AppleTV. Content is synced to this TV for display. Ensure that CloudKit Sync is turned on in the Timesheets pane of the Settings app."
        let alert = UIAlertController(title: "No Content", message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alert.addAction(cancel)
        present(alert, animated: true, completion: {})
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let numberOfSites = cloudKitController?.recordsSortedBySite.count ?? 0
        return numberOfSites + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if indexPath.row == tableView.numberOfRows(inSection: 0) - 1
        {
            cell.textLabel?.text = "All"
            cell.imageView?.image = nil
        }
        
        else
        {
            let data = cloudKitController.recordsSortedBySite[indexPath.row]
            let cellText = data.siteName + " (\(data.gliderRecords.count))"
            cell.textLabel?.text = cellText
            let GCImage = UIImage(named: data.siteName)
            cell.imageView?.image = GCImage
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if indexPath.row == tableView.numberOfRows(inSection: 0) - 1
        {
            selectedSite = "All"
        }
        
        else
        {
            let data = cloudKitController.recordsSortedBySite[indexPath.row]
            selectedSite = data.siteName
        }

        selectedRow = indexPath.row
        delegate?.prepareRecords()
    }
}

