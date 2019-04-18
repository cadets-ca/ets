//
//  SelectDateToViewRecords.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-01.
//
//

import Foundation
import UIKit

final class SelectDateToViewRecords : UIViewController
{
    @IBOutlet var datePicker: UIDatePicker!
    
    @IBAction func timeChanged()
    {
        switch (datePicker.date, regularFormat)
        {
        case (Date.distantPast ..< Date().midnight, _):
            dataModel.viewPreviousRecords = true
            dataModel.dateToViewRecords = datePicker.date
            
        case (_, regularFormat):
            dataModel.dateToViewRecords = datePicker.date

        case (_, !regularFormat):
            dataModel.viewPreviousRecords = false
            
        default:
            break
        }
        
        if dataModel.previousRecordsGlidingCentre == nil
        {
            dataModel.previousRecordsGlidingCentre = dataModel.glidingCentre
        }
        NotificationCenter.default.post(name: enterOrExitViewPreviousRecordsNotification, object:self, userInfo:nil)
        dataModel.configureFlightCounters()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if !regularFormat
        {
            guard let tabBarController = presentingViewController as? UITabBarController else {return}
            guard let currentViewControllers = tabBarController.viewControllers else {return}

            let viewControllers = Array(currentViewControllers[0...2])
            tabBarController.setViewControllers(viewControllers, animated:true)
        }
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        let today = Date().midnight
        datePicker.maximumDate = today + -1
        
        if dataModel.viewPreviousRecords
        {
            datePicker.date = dataModel.dateToViewRecords as Date
        }
            
        else
        {
            datePicker.date = datePicker.maximumDate!
        }
    }
}
