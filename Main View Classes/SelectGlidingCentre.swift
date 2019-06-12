
//  SelectGlidingCentre.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-01.
//
//

import Foundation
import UIKit

protocol SelectGlidingCentreDelegate
{
    func glidingCentreSelected(_ glidingCentreName: String) -> Void
}

final class SelectGlidingCentre: UITableViewController
{
    var currentGlidingCentre: String!
    private var glidingCentreNames = [String]()
    private var glidingCentreCoordinates = GlidingCentreInfo.initalizeGCInfoList()
    var delegate: SelectGlidingCentreDelegate?

    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(self.regionChangeHandler), name: regionChangedNotification, object: nil)

//        if !regularFormat
//        {
            tableView.backgroundColor = #colorLiteral(red: 0.4196078431, green: 0.7098039216, blue: 0.8196078431, alpha: 1)
//        }
        
        configure()
    }
    
    @objc func regionChangeHandler()
    {
        currentGlidingCentre = nil
        configure()
    }
    
    func configure()
    {
        if currentGlidingCentre == nil
        {
            currentGlidingCentre = dataModel.glidingCentre?.name
            
            if currentGlidingCentre == nil
            {
                dataModel.updateGlidingCentreButton("Gimli")
                currentGlidingCentre = dataModel.glidingCentre?.name
            }
        }
        
        glidingCentreNames.removeAll(keepingCapacity: true)
        delegate = dataModel
        navigationController?.tabBarItem.title = currentGlidingCentre ?? "Site"
        glidingCentreCoordinates = GlidingCentreInfo.initalizeGCInfoList()
        glidingCentreCoordinates = GlidingCentreInfo.filterToCurrentRegion(glidingCentreCoordinates)
        
        for siteName in glidingCentreCoordinates.keys
        {
            glidingCentreNames.append(siteName as String)
        }
        
        tableView.reloadData()
        
        glidingCentreNames.sort(by: <)
        preferredContentSize = CGSize(width: 320, height: tableView.contentSize.height)
        tableView.backgroundColor = ((presentingViewController?.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.compact) || presentingViewController == nil) ? UIColor.groupTableViewBackground : UIColor.clear

    }
    
    @objc func dismiss()
    {
        if let presenter = presentingViewController
        {
            presenter.dismiss(animated: true, completion: nil)
        }
        
        else
        {
            currentGlidingCentre = dataModel.glidingCentre.name
            navigationController?.tabBarItem.title = currentGlidingCentre ?? "Site"
            tableView.reloadData()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(previousTraitCollection, controller: self, withDoneButtonAction: "dismiss")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        if !regularFormat
        {
            tableView.backgroundColor = #colorLiteral(red: 0.4196078431, green: 0.7098039216, blue: 0.8196078431, alpha: 1)
        }
    }
    
    //MARK: - UITableViewController Methods
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
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
        cell.accessoryType = currentGlidingCentre == GCname ? UITableViewCell.AccessoryType.checkmark : UITableViewCell.AccessoryType.none
        let GCImage = UIImage(named: GCname)
        cell.imageView?.image = GCImage
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        delegate?.glidingCentreSelected(glidingCentreNames[(indexPath as NSIndexPath).row])
        dismiss()
    }
}
