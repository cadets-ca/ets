//
//  DeduplicateProgressViewController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-16.
//
//

import Foundation
import UIKit

final class DeduplicateProgressViewController : UITableViewController
{
    @IBOutlet var region: UIProgressView!
    @IBOutlet var glidingCentre: UIProgressView!
    @IBOutlet var glidingDayComments: UIProgressView!
    @IBOutlet var summerUnits: UIProgressView!
    @IBOutlet var aircraft: UIProgressView!
    @IBOutlet var maintenanceEvents: UIProgressView!
    @IBOutlet var pilots: UIProgressView!
    @IBOutlet var quals: UIProgressView!
    @IBOutlet var attendance: UIProgressView!
    @IBOutlet var timesheets: UIProgressView!
    @IBOutlet var flightRecords: UIProgressView!
    @IBOutlet var pairing: UIProgressView!
    @IBOutlet var updatingTimesheetTotals: UIProgressView!
}
