//
//  ListMaintenanceIssues.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-20.
//

import Foundation
import UIKit
import CoreData

final class ListMaintenanceIssues: UITableViewController, NSFetchedResultsControllerDelegate
{
    var aircraftBeingEdited: AircraftEntity!
    var fetchedResultsController: NSFetchedResultsController<MaintenanceEvent>!
    var pathsToUpdate = Set<IndexPath>()
   
    enum SegueIdentifiers: String
    {
        case EditIssueSegue = "EditIssueSegue"
        case NewIssueSegue = "NewIssueSegue"
    }
    
    override func viewDidLoad()
    {
        let request = MaintenanceEvent.request
        request.predicate = NSPredicate(format: "aircraft == %@", aircraftBeingEdited)
        let sortByDate = NSSortDescriptor(key: #keyPath(MaintenanceEvent.date), ascending: true)
        request.sortDescriptors = [sortByDate]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {        
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .EditIssueSegue:
            let issueEditor = segue.destination as? EditMaintenanceIssue
            guard let path = tableView.indexPathForSelectedRow else {return}
            let issueBeingEdited = fetchedResultsController.object(at: path)
            issueEditor?.issueBeingEdited = issueBeingEdited

        case .NewIssueSegue:
            let issueEditor = segue.destination as? EditMaintenanceIssue
            let newIssue = MaintenanceEvent(context: dataModel.managedObjectContext)
            newIssue.aircraft = aircraftBeingEdited
            newIssue.date = Date()
            issueEditor?.issueBeingEdited = newIssue
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        mainQueue.asyncAfter(deadline: .now() + 1){self.tableView.reloadData()}
    }
    
    //MARK: - TableView data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if let array = fetchedResultsController.fetchedObjects
        {
            return array.count
        }
        
        else
        {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Issue Cell", for: indexPath)
        configureCell(cell, atIndexPath:indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            let issue = fetchedResultsController.object(at: indexPath)
            cloudKitController?.deleteMaintenanceIssue(issue)
            dataModel.managedObjectContext.delete(issue)
            dataModel.saveContext()
        }
    }
    
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath)
    {
        let issue = fetchedResultsController.object(at: indexPath)
        cell.textLabel?.text = issue.date.militaryFormatShort 
        cell.detailTextLabel?.text = issue.comment
    }
    
    //MARK: - Fetched Results Controller
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        switch type
        {
        case .delete:
            guard let indexPath = indexPath else {return}
            tableView.deleteRows(at: [indexPath], with: .automatic)
            return

        case .insert:
            guard let newIndexPath = newIndexPath else {return}
            tableView.insertRows(at: [newIndexPath], with: .automatic)
            
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else {return}
            tableView.moveRow(at: indexPath, to: newIndexPath)
            
        default:
            break
        }
        
        guard let indexPath = indexPath else {return}
        guard let newIndexPath = newIndexPath else {pathsToUpdate.insert(indexPath); return}
        pathsToUpdate.insert(newIndexPath)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        tableView.endUpdates()
        tableView.reloadRows(at: Array(pathsToUpdate), with: UITableView.RowAnimation.automatic)
        pathsToUpdate.removeAll()
    }
}
