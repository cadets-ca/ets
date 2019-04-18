//
//  ChangeTimesheetDate.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-07.
//
//

import Foundation
import UIKit

final class ChangeTimesheetDate: ChangeSignificantDate
{
    var timesheet: AircraftTimesheet!

    convenience init(timesheet newTimesheet: AircraftTimesheet, delegate: ChangeSignificantDateDelegate? = nil)
    {
        self.init()
        timesheet = newTimesheet
        self.delegate = delegate
        self.addTarget(self, action: #selector(ChangeSignificantDate.timeChanged), for: .valueChanged)
        datePickerMode = .dateAndTime
        date = timesheet.date as Date
    }
    
    @objc override func timeChanged()
    {
        if timesheet.date < Date().midnight && dataModel.editorSignInTime < Date() - 30*60
        {
            let title = "Sign In"
            let message = "You must sign in to edit records from prior days. Your license number will be logged on all edits taking place in the next half hour."
            let signInAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            signInAlert.addAction(cancelAction)
            
            let proceedAction = UIAlertAction(title: "Login", style: .default){_ in
                guard let name = signInAlert.textFields?.first?.text, name.count > 0 else {return}
                guard let license = signInAlert.textFields?.last?.text, license.count > 3 else {return}
                dataModel.editorName = name
                dataModel.editorLicense = license
                dataModel.editorSignInTime = Date()
            }
            
            signInAlert.addAction(proceedAction)
            signInAlert.addTextField(){textField in textField.placeholder = "Name"}
            signInAlert.addTextField(){textField in textField.placeholder = "License Number"}
            
            if let delegate = delegate as? UIViewController
            {
                delegate.present(signInAlert, animated: true)
            }
            
            date = timesheet.date
            return
        }
        
        let newDate = date
        let oldDate = timesheet.date
        timesheet.date = newDate
        
        let components = gregorian.dateComponents([.day], from: oldDate, to: newDate)

        let recordsOnCurrentTimesheet = Array(timesheet.flightRecords) 
        for record in recordsOnCurrentTimesheet
        {
            record.timeUp = gregorian.date(byAdding: components, to: record.timeUp) ?? Date()
            record.timeDown = gregorian.date(byAdding: components, to: record.timeDown) ?? Date()
        }
        
        dataModel.saveContext()
        delegate?.dateChanged()
    }
}
