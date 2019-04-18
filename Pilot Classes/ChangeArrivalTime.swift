//
//  ChangeArrivalTime.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-24.
//
//

import Foundation
import UIKit

final class ChangeArrivalTime : ChangeSignificantDate
{
    var recordBeingEdited: AttendanceRecord!

    convenience init(record: AttendanceRecord, delegate: ChangeSignificantDateDelegate? = nil)
    {
        self.init()
        recordBeingEdited = record
        self.delegate = delegate
        addTarget(self, action:#selector(ChangeSignificantDate.timeChanged), for: .valueChanged)
        datePickerMode = .time
        locale = Locale(identifier: "fr")
        date = record.timeIn as Date
        self.maximumDate = Date()
    }
    
    @objc override func timeChanged()
    {
        recordBeingEdited.timeIn = date
        delegate?.dateChanged()
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
    }
}
