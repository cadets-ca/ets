//
//  ListAttendanceRecords.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-23.
//
//

import Foundation
import UIKit

final class ListAttendanceRecords : UITableViewController
{
    var pilot: Pilot!
    var records = [AttendanceRecord]()
    
    //MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool)
    {
        records = Array(pilot.attendanceRecords)
        records.sort {$0.timeIn > $1.timeIn}
        tableView.allowsSelection = false
        super.viewWillAppear(animated)
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
   
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            let record = records[(indexPath as NSIndexPath).row]
            let beginningOfRecordDate = record.timeIn.midnight
            let picFlightsOnRecordDate = record.pilot.sortedPICflightsForDate(beginningOfRecordDate)
            let dualFlightsOnRecordDate = record.pilot.sortedDualFlightsForDate(beginningOfRecordDate)
            
            if picFlightsOnRecordDate.count > 0 || dualFlightsOnRecordDate.count > 0
            {
                let alertText = "\(record.pilot.name) flew on \(record.timeIn.militaryFormatShort) so the attendance record for that date cannot be deleted."
                
                let cantDeleteRecordAlert = UIAlertController(title: "Unable to Delete Record", message:alertText, preferredStyle: .alert)
                let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
                cantDeleteRecordAlert.addAction(OKbutton)
                present(cantDeleteRecordAlert, animated:true, completion:nil)
            }
                
            else
            {
                if record.timeIn.isDateInToday
                {
                    record.pilot.signedIn = false
                }
                
                records.remove(at: (indexPath as NSIndexPath).row)
                cloudKitController?.deleteAttendanceRecord(record)
                dataModel.managedObjectContext.delete(record)
                dataModel.saveContext()
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String?
    {
        return "Delete"

    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let record = records[(indexPath as NSIndexPath).row]
        
        var date = record.glidingCentre.name
        date += " \(record.timeIn.militaryFormatShort)"
        cell.textLabel?.text = date
        var times = record.dayOrSession ? "Day" : "Session"
        var timeOut = record.timeOut.hoursAndMinutes
        
        if record.timeOut == Date.distantFuture
        {
            timeOut = " ?"
            times = Date().timeIntervalSince(record.timeIn as Date) > 6*60*60 as Double ? "Day" : "Session"
        }
        
        times += " (\(record.timeIn.hoursAndMinutes)-\(timeOut))"
        cell.detailTextLabel?.text = times
        if record.pilot.typeOfParticipant == "cadet"
        {
            cell.detailTextLabel?.text = nil
        }
        
        cell.imageView?.image = UIImage(named: record.glidingCentre.name)
        return cell
    }
}
