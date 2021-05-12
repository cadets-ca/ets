//
//  GlidingDayCommentList.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-02.
//
//

import Foundation
import UIKit
import CoreData

final class GlidingDayCommentList : UITableViewController, NSFetchedResultsControllerDelegate
{
    var fetchedResultsController: NSFetchedResultsController<GlidingDayComment>!
    var pathsToUpdate = Set<IndexPath>()
    
    enum SegueIdentifiers: String
    {
        case EditCommentSegue = "EditCommentSegue"
        case NewCommentSegue = "NewCommentSegue"
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let request = GlidingDayComment.request
        request.predicate = NSPredicate(format: "glidingCentre == %@", dataModel.glidingCentre)
        let sortByDate = NSSortDescriptor(key: #keyPath(GlidingDayComment.date), ascending:false)
        request.sortDescriptors = [sortByDate]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        try! fetchedResultsController.performFetch()
        fetchedResultsController.delegate = self
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .EditCommentSegue:
            let commentEditor = segue.destination as? GlidingDayCommentEditor
            commentEditor?.commentBeingEdited = fetchedResultsController.object(at: tableView.indexPathForSelectedRow!)

        case .NewCommentSegue:
            let commentEditor = segue.destination as? GlidingDayCommentEditor
            let newComment = GlidingDayComment(context: dataModel.managedObjectContext)
            newComment.date = Date()
            commentEditor?.commentBeingEdited = newComment
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let sectionInfo = fetchedResultsController.sections?[section]
        return sectionInfo?.numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Issue Cell", for:indexPath)
        configureCell(cell, atIndexPath:indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            let comment = fetchedResultsController.object(at: indexPath)
            cloudKitController?.deleteComment(comment)
            dataModel.managedObjectContext.delete(comment)
            dataModel.saveContext()
        }
    }
    
    //MARK: - UITableViewDelegate
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath)
    {
        let comment = fetchedResultsController.object(at: indexPath) 
        cell.textLabel?.text = comment.date.militaryFormatShort
        cell.detailTextLabel?.text = comment.comment
    }
    
    //MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        switch type
        {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
            
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            
        case .update:
            let _ = newIndexPath != nil ? pathsToUpdate.insert(newIndexPath!) : pathsToUpdate.insert(indexPath!)
            
        case .move:
            tableView.moveRow(at: indexPath!, to:newIndexPath!)
        @unknown default:
            fatalError()
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        tableView.endUpdates()
        tableView.reloadRows(at: Array(pathsToUpdate), with: .fade)
        pathsToUpdate.removeAll(keepingCapacity: false)
    }
}
