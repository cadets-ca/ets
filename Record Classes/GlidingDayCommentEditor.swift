//
//  GlidingDayCommentEditor.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-02.
//
//

import Foundation
import UIKit

final class GlidingDayCommentEditor: UIViewController, UITextViewDelegate
{
    @IBOutlet var datePicker: UIDatePicker!
    @IBOutlet var textViewer: UITextView!
    var commentBeingEdited: GlidingDayComment!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        datePicker.date = commentBeingEdited.date as Date
        textViewer.text = commentBeingEdited.comment
        
        view.backgroundColor = presentingViewController?.traitCollection.horizontalSizeClass == .compact ? UIColor.groupTableViewBackground : UIColor.clear
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if textViewer.text.count > 1
        {
            commentBeingEdited.comment = textViewer.text
            commentBeingEdited.date = datePicker.date
        }
            
        else
        {
            dataModel.managedObjectContext.delete(commentBeingEdited)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        dataModel.saveContext()
    }
    
    @IBAction func cancel()
    {
        textViewer.text = ""
        let _ = navigationController?.popViewController(animated: true)
    }

    @objc @IBAction func done()
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
        
        if text.count > 0
        {
            let backButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(GlidingDayCommentEditor.done))
            self.navigationItem.leftBarButtonItem = backButton
        }
        
        return true
    }
}
