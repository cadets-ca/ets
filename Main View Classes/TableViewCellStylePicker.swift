//
//  TableViewCellStylePicker.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-16.
//
//

import Foundation
import UIKit

final class TableViewCellStylePicker : UITableViewCell
{
    @IBOutlet var label: UILabel!
    @IBOutlet var stackView: UIStackView!
    var datePicker: UIDatePicker?
    
    func addPickerToStackView(_ picker: UIDatePicker, atPosition position: Int = -1)
    {
        datePicker = picker
        
        if position >= 0
        {
            stackView.insertArrangedSubview(picker, at: position)
        }
        
        else
        {
            stackView.addArrangedSubview(picker)
        }

        picker.alpha = 0
        UIView.animate(withDuration: 0.2, animations:{picker.alpha = 1}, completion:nil)
        
    }
    
    func removePickerFromStackView()
    {
        if let oldPicker = datePicker
        {
            datePicker = nil
            stackView.removeArrangedSubview(oldPicker)
            oldPicker.removeFromSuperview()
        }
    }
}
