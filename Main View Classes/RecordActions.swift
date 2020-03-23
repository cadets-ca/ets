//
//  RecordActions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-24.
//
//

import Foundation
import UIKit
import CoreData

final class RecordActions : UITableViewController, ChangeSignificantDateDelegate, UICloudSharingControllerDelegate
{
    var statsReportStartDate = Date.startOfYear
    var statsReportEndDate = Date().startOfDay + (24*60*60 - 1)

    @IBOutlet var printLogCell: UITableViewCell!
    @IBOutlet var printTimesheetsCell: UITableViewCell!
    @IBOutlet var viewPreviousRecordsCell: UITableViewCell!
    @IBOutlet var emailStatsCell: UITableViewCell!
    @IBOutlet var regionalStatsCell: UITableViewCell!
    @IBOutlet var emailPTRcell: UITableViewCell!
    @IBOutlet var startDateCell: UITableViewCell!
    @IBOutlet var endDateCell: UITableViewCell!
    @IBOutlet var emailDatabaseCell: UITableViewCell!
    @IBOutlet var funStatsCell: UITableViewCell!
    @IBOutlet var shareDatabaseCell: UITableViewCell!

    var customDatePicker: ChangeSignificantDate?

    enum SegueIdentifiers: String
    {
        case ViewPreviousRecords = "ViewPreviousRecords"
        case ViewPreviousRecordsConstrained = "ViewPreviousRecordsConstrained"
        case ListGlidingDayCommentsSegue = "ListGlidingDayCommentsSegue"
        case ViewFunStatsSegue = "ViewFunStatsSegue"
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        tableView.layoutIfNeeded()
        preferredContentSize = CGSize(width: 320, height: self.tableView.contentSize.height)
    }
    
    @objc @IBAction func dismiss()
    {
        presentingViewController?.dismiss(animated: true, completion:nil)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        addOrRemoveDoneButtonGivenTraitCollection(presentingViewController?.traitCollection, controller: self, withDoneButtonAction: "dismiss")
        viewPreviousRecordsCell?.isHidden = false
        
        if dataModel.viewPreviousRecords == true
        {
            viewPreviousRecordsCell?.textLabel?.text = "View Today's Records"
            viewPreviousRecordsCell?.accessoryType = .none
            
            if regularFormat
            {
                viewPreviousRecordsCell?.isHidden = true
            }
        }
            
        else
        {
            viewPreviousRecordsCell?.textLabel?.text = "View Previous Flights"
            viewPreviousRecordsCell?.accessoryType = .disclosureIndicator
        }
        
        if observerMode
        {
            shareDatabaseCell.textLabel?.text = "Sharing Remote Database"
            shareDatabaseCell.detailTextLabel?.text = "Invite Others or Stop Sharing"
        }
        
        let startDateLabel = startDateCell.viewWithTag(1) as? UILabel
        startDateLabel?.text = statsReportStartDate.militaryFormatShort
        let endDateLabel = endDateCell.viewWithTag(1) as? UILabel
        endDateLabel?.text = statsReportEndDate.militaryFormatShort
                
        super.viewWillAppear(animated)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(previousTraitCollection, controller: self, withDoneButtonAction: "dismiss")
    }
    
    func dateChanged()
    {
        viewWillAppear(false)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard let cell = tableView.cellForRow(at: indexPath) else {return}
        switch cell
        {
        case printLogCell:
            dataModel.emailPilotLogs()
            
        case printTimesheetsCell:
            // TODO: currently working on this report!!!
            dataModel.emailTimesheets(false)
            
        case emailStatsCell:
            dataModel.emailLocalStatsReportFromDate(statsReportStartDate, toDate:statsReportEndDate)
            
            let aircraftRequest = AircraftEntity.request
            let registrationSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftEntity.registration), ascending: true)
            aircraftRequest.sortDescriptors = [registrationSortDescriptor]
            let aircraftList = try! dataModel.managedObjectContext.fetch(aircraftRequest) 
            
            var aircraftFlying = false
            for aircraft in aircraftList
            {
                if aircraft.status == .flying
                {
                    aircraftFlying = true
                    break
                }
            }
            
            if aircraftFlying
            {
                let alert = UIAlertController(title: "Aircraft Flying", message: "Recommend resending stats when all aircraft are on the ground.", preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(cancel)
                present(alert, animated:true, completion:nil)
            }
            
        case regionalStatsCell:
            dataModel.emailRegionalStatsReportFromDate(statsReportStartDate, toDate:statsReportEndDate)
            
            let aircraftRequest = AircraftEntity.request
            let registrationSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftEntity.registration), ascending: true)
            aircraftRequest.sortDescriptors = [registrationSortDescriptor]
            let aircraftList = try! dataModel.managedObjectContext.fetch(aircraftRequest) 
            
            var aircraftFlying = false
            for aircraft in aircraftList
            {
                if aircraft.status == .flying
                {
                    aircraftFlying = true
                    break
                }
            }
            
            if aircraftFlying
            {
                let alert = UIAlertController(title: "Aircraft Flying", message: "Recommend resending stats when all aircraft are on the ground.", preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(cancel)
                present(alert, animated:true, completion:nil)
            }
            
        case emailPTRcell:
            dataModel.emailPTRs()

        case shareDatabaseCell:
            if let cloudKitController = cloudKitController
            {
                guard let sharingController = cloudKitController.configureSharing() else {return}
                sharingController.delegate = self
                sharingController.popoverPresentationController?.sourceView = shareDatabaseCell
                sharingController.availablePermissions = [.allowPublic, .allowReadOnly]
                self.present(sharingController, animated: true, completion: nil)
            }
            
            else
            {
                let alert = UIAlertController(title: "Sharing Disabled", message: "Enable sharing in the Timesheets area of the Settings app found on the home screen.", preferredStyle: .alert)
                let cancel = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(cancel)
                present(alert, animated:true, completion:nil)
            }
            
        case emailDatabaseCell:
            cloudKitController?.backupDatabase()

        case viewPreviousRecordsCell:
            if dataModel.viewPreviousRecords == true
            {
                dataModel.viewPreviousRecords = false
                NotificationCenter.default.post(name: enterOrExitViewPreviousRecordsNotification, object:self, userInfo:nil)
                dataModel.configureFlightCounters()
                
                if !regularFormat
                {
                    guard let rootController = ((UIApplication.shared.delegate as? TimesheetsAppDelegate)!.window?.rootViewController) as? UITabBarController else {break}
                    let currentViewControllers =  rootController.viewControllers!
                    var viewControllers = Array(currentViewControllers[0...2])
                    viewControllers.append(storyboard!.instantiateViewController(withIdentifier: "AircraftTab"))
                    rootController.setViewControllers(viewControllers, animated:true)
                    presentingViewController?.dismiss(animated: true, completion:nil)
                }
                    
                else
                {
                    dataModel.viewPreviousRecords = true
                    guard let path = tableView.indexPathForSelectedRow else {break}
                    tableView.deselectRow(at: path, animated:true)
                }
            }
            
        default:
            break
        }
        
        if ((indexPath as NSIndexPath).section == 2) && ((indexPath as NSIndexPath).row < 2)
        {
            if customDatePicker == nil
            {
                addPickerToCell(cell, atIndexPath:indexPath)
            }
                
            else
            {
                let previouslySelectedCell = customDatePicker?.tableViewCell as? TableViewCellStylePicker
                previouslySelectedCell?.removePickerFromStackView()
                customDatePicker = nil

                if previouslySelectedCell !== cell
                {
                    addPickerToCell(cell, atIndexPath:indexPath)
                }
            }
            
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        var allowedActions = [UIContextualAction]()
        if tableView.cellForRow(at: indexPath) == funStatsCell
        {
            guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ca.cadets.Timesheets") else {return nil}

            let exportDB = UIContextualAction(style: .normal, title: "Export Database"){_,_,_   in
                let path = groupURL.appendingPathComponent("Timesheets.sqlite")
                let vc = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                self.present(vc, animated:true, completion:nil)
            }

            allowedActions.append(exportDB)
        }
        
        if tableView.cellForRow(at: indexPath) == printTimesheetsCell
        {
            let emailTimesheetsWithChangeLog = UIContextualAction(style: .normal, title: "Include Change Log"){_,_,_  in
                dataModel.emailTimesheets(false, true)
            }
            
            allowedActions.append(emailTimesheetsWithChangeLog)
        }
        
        return UISwipeActionsConfiguration(actions: allowedActions)

    }
    
    func itemTitle(for csc: UICloudSharingController) -> String?
    {
        return "Timesheet Database"
    }
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error)
    {
        return
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController)
    {
        cloudKitController?.toggleSharingTo(state: false)
    }
    
    func itemThumbnailData(for csc: UICloudSharingController) -> Data?
    {
        guard let icon = NSDataAsset(name: "AppIcon") else
        {
            return nil
        }
        
        return icon.data
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool
    {
        guard let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(identifier)")}
        
        switch (segueIdentifer, regularFormat, dataModel.viewPreviousRecords)
        {
        case (.ViewPreviousRecords, true, _):
            return true
            
        case (.ViewPreviousRecords, false, false):
            performSegue(withIdentifier: SegueIdentifiers.ViewPreviousRecordsConstrained.rawValue, sender:self)
            fallthrough
            
        case (.ViewPreviousRecords, false, _):
            return false
            
        default:
            return true
        }
    }
    
    private func addPickerToCell(_ cell: UITableViewCell?, atIndexPath indexPath: IndexPath?)
    {
        if let newCell = cell as? TableViewCellStylePicker
        {
            switch (indexPath! as NSIndexPath).row
            {
            case 0:
                customDatePicker =  ChangeSignificantDate(mode: .statsReportStartDate, pilotBeingEdited: nil, recordActions: self, logBookCreator: nil)
                newCell.addPickerToStackView(customDatePicker!)
                
            case 1:
                customDatePicker =  ChangeSignificantDate(mode: .statsReportEndDate, pilotBeingEdited: nil, recordActions: self, logBookCreator: nil)
                newCell.addPickerToStackView(customDatePicker!)
                
            default:
                break
            }
            
            customDatePicker?.delegate = self
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .ViewPreviousRecords:
            dataModel.viewPreviousRecords = true
            
        case .ViewPreviousRecordsConstrained, .ListGlidingDayCommentsSegue, .ViewFunStatsSegue:
            break
        }
    }
}
