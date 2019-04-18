//
//  EditMaintenanceIssue.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-20.
//
//

import Foundation
import UIKit

final class EditMaintenanceIssue: UIViewController, UITextViewDelegate
{
    var issueBeingEdited: MaintenanceEvent!
    @IBOutlet var datePicker: UIDatePicker!
    @IBOutlet var textViewer: UITextView!

    override func viewDidLoad()
    {
        datePicker.date = issueBeingEdited.date as Date
        textViewer.text = issueBeingEdited.comment
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        if (textViewer.text.count > 1)
        {
            issueBeingEdited.comment = textViewer.text
            issueBeingEdited.date = datePicker.date
        }
            
        else
        {
            dataModel.managedObjectContext.delete(issueBeingEdited)
        }
        
        dataModel.saveContext()
        super.viewWillDisappear(animated)
    }
    
    @IBAction func cancel()
    {
        textViewer.text = ""
        let _ = navigationController?.popViewController(animated: true)
    }
    
    @IBAction func done()
    {
        let _ = navigationController?.popViewController(animated: true)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    {
        if text == "\n"
        {
            textView.resignFirstResponder()
            return false
        }
        
        return true
    }
}
