//
//  ViewJourneyLogEntries.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-21.
//
//

import Foundation
import UIKit
import CoreData

final class ViewJourneyLogEntries: UITableViewController
{
    var aircraftBeingEdited: AircraftEntity!
    var fetchedResultsController: NSFetchedResultsController<AircraftTimesheet>!
    var shouldScrollToBottom = false
    
    //MARK: - UIViewController Overrides
    override func viewDidLoad()
    {
        let request = AircraftTimesheet.request
        request.predicate = NSPredicate(format: "aircraft == %@", aircraftBeingEdited)
        let sortByDate = NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: true)
        request.sortDescriptors = [sortByDate]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try fetchedResultsController.performFetch()
        } catch _ {
        }
        
        if (fetchedResultsController.fetchedObjects!.count > 0)
        {
            shouldScrollToBottom = true
        }
        
        for timesheet in fetchedResultsController.fetchedObjects!
        {
            if (timesheet !== fetchedResultsController.fetchedObjects?.last) && (timesheet.flightRecords.count == 0)
            {
                dataModel.managedObjectContext.delete(timesheet)
                cloudKitController?.deleteTimesheet(timesheet)
            }
        }
        
        dataModel.saveContext()
        try! fetchedResultsController.performFetch()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if shouldScrollToBottom
        {
            let lastRow = IndexPath(item: (fetchedResultsController.fetchedObjects!.count - 1), section: 0)
            tableView.scrollToRow(at: lastRow, at: .bottom, animated: true)
            shouldScrollToBottom = false
        }
        
        else
        {
            tableView.reloadData()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    enum SegueIdentifiers: String
    {
        case EditJourneyLogEntrySegue = "EditJourneyLogEntrySegue"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .EditJourneyLogEntrySegue:
            let editor = segue.destination as? JourneyLogEntryEditor
            let indexPathOfRowBeingEdited = tableView.indexPathForSelectedRow!
            editor?.timesheetBeingEdited = fetchedResultsController.fetchedObjects![(indexPathOfRowBeingEdited as NSIndexPath).row] 
        }
    }
    
    @IBAction func enterEditMode()
    {
        tableView.setEditing(true, animated: true)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(ViewJourneyLogEntries.exitEditMode))
        navigationItem.rightBarButtonItem = doneButton
    }
    
    @objc func exitEditMode()
    {
        tableView.setEditing(false, animated: true)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(ViewJourneyLogEntries.enterEditMode))
        navigationItem.rightBarButtonItem = doneButton
    }
    
    //MARK: - UITableViewController Overrides
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
    {
        let timesheet = fetchedResultsController.object(at: sourceIndexPath)
        
        if (destinationIndexPath as NSIndexPath).row > 0
        {
            let previousTimesheet = fetchedResultsController.object(at: IndexPath(row: ((destinationIndexPath as NSIndexPath).row - 1), section: 0))
            timesheet.date = previousTimesheet.date + 1
        }
        
        else
        {
            let nextTimesheet = fetchedResultsController.object(at: IndexPath(row: ((destinationIndexPath as NSIndexPath).row + 1), section: 0))
            timesheet.date = nextTimesheet.date + -1
        }
        
        dataModel.saveContext()
        try! fetchedResultsController.performFetch()
    }
    
    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?)
    {
        tableView.reloadRows(at: tableView.indexPathsForVisibleRows ?? [IndexPath](), with: .automatic)
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle
    {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool
    {
        return false
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let timesheets = fetchedResultsController.fetchedObjects
        guard let timesheet = timesheets?[(indexPath as NSIndexPath).row] else {return cell}
        var nextTimesheet: AircraftTimesheet?
        var previousTimesheet: AircraftTimesheet?
        
        if (indexPath as NSIndexPath).row != ((fetchedResultsController.fetchedObjects?.count ?? 0) - 1)
        {
            nextTimesheet = timesheets?[(indexPath as NSIndexPath).row + 1]
        }
        
        if (indexPath as NSIndexPath).row != 0
        {
            previousTimesheet = timesheets?[(indexPath as NSIndexPath).row - 1]
        }
        
        cell.textLabel?.text = timesheet.date.militaryFormatLong
        cell.imageView?.image = UIImage(named: timesheet.glidingCentre.name)
        
        let initialTTSN = timesheet.TTSNinitial.stringWithDecimal
        let type = timesheet.aircraft.type
        if type.isAircraft()
        {
            timesheet.updateTTSN()
        }
        
        let finalTTSN = timesheet.TTSNfinal.stringWithDecimal
        
        let hoursString = timesheet.TTSNfinal - timesheet.TTSNinitial
        let flightsString = timesheet.flightRecords.count == 1 ? "1 flight" : "\(timesheet.flightRecords.count) flights"
        cell.detailTextLabel?.text = "\(flightsString), \(initialTTSN)-\(finalTTSN) \(hoursString.stringWithDecimal) hours"
        
        var errorFound = false
        
        if let next = nextTimesheet, timesheet.TTSNfinal != next.TTSNinitial
        {
            errorFound = true
        }
        
        if let prior = previousTimesheet, timesheet.TTSNinitial != prior.TTSNfinal
        {
            errorFound = true
        }
        
        cell.backgroundColor = errorFound ? UIColor.red : UIColor.white
        return cell
    }
}
