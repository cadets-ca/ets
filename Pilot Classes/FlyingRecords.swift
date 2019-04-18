//
//  FlyingRecords.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-22.
//
//

import Foundation
import UIKit

final class FlyingRecords : UITableViewController
{
    @IBOutlet var gliderDual: UITableViewCell!
    @IBOutlet var TowPIC: UITableViewCell!
    @IBOutlet var winchLaunches: UITableViewCell!
    @IBOutlet var autoLaunches: UITableViewCell!
    @IBOutlet var gliderFlights: UILabel!
    @IBOutlet var gliderFlightAdjust: UIStepper!

    @IBOutlet var gliderPIC: UILabel!
    @IBOutlet var gliderPICAdjust: UIStepper!

    @IBOutlet var gliderInstructor: UILabel!
    @IBOutlet var gliderInstructorAdjust: UIStepper!

    @IBOutlet var powerPIC: UILabel!
    @IBOutlet var powerPICAdjust: UIStepper!
    
    var pilot: Pilot!
    var pilotStats: PilotFlyingStats!
    var lastStepTime = Date()
    
    enum SegueIdentifiers: String
    {
        case ListFlightsSegue = "ListFlightsSegue"
        case CreateLogBookSegue = "CreateLogBookSegue"
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        pilotStats = pilot.flyingStatsFromDate(Date.distantPast, toDate:Date.distantFuture)
        
        gliderInstructor.text = String(fromMinutes: Double(pilotStats.gliderInstructorMinutes) + Double(pilot.gliderInstHoursAdjust))
        gliderInstructorAdjust.minimumValue = 0
        gliderInstructorAdjust.maximumValue = 100000
        gliderInstructorAdjust.value = Double(pilot.gliderInstHoursAdjust)
        
        gliderDual.detailTextLabel?.text = String(fromMinutes: Double(pilotStats.gliderDualMinutes))
        
        gliderFlights.text = "\(pilotStats.gliderFlights + Int(pilot.gliderFlightsAdjustment))"
        gliderFlightAdjust.minimumValue = 0
        gliderFlightAdjust.maximumValue = 100000
        gliderFlightAdjust.value = Double(pilot.gliderFlightsAdjustment)
        
        gliderPIC.text = String(fromMinutes: Double(pilotStats.gliderPICminutes) + Double(pilot.gliderPIChoursAdjust))
        gliderPICAdjust.minimumValue = 0
        gliderPICAdjust.maximumValue = 100000
        gliderPICAdjust.value = Double(pilot.gliderPIChoursAdjust)
        
        winchLaunches.detailTextLabel?.text = "\(pilotStats.launchesAsWinchOperator)"
        autoLaunches.detailTextLabel?.text = "\(pilotStats.launchesAsAutoDriver)"
        
        TowPIC.detailTextLabel?.text = String(fromMinutes: Double(pilotStats.towPICminutes)).decimalHoursValue
        
        powerPIC.text = String(fromMinutes: Double(pilotStats.towPICminutes + Int(pilot.powerHoursAdjust))).decimalHoursValue
        powerPICAdjust.minimumValue = 0
        powerPICAdjust.maximumValue = 2000000
        powerPICAdjust.stepValue = 6

        powerPICAdjust.value = Double(pilot.powerHoursAdjust)

    }
    
    @IBAction func gliderFlightsAdjusted()
    {
        pilot.gliderFlightsAdjustment = Int64(gliderFlightAdjust.value)
        gliderFlights.text = "\(pilotStats.gliderFlights + Int(pilot.gliderFlightsAdjustment))"
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        
        if Date() - lastStepTime < 0.1
        {
            gliderFlightAdjust.stepValue = 10
            mainQueue.asyncAfter(deadline: .now() + 1){if Date() - self.lastStepTime > 0.1{self.gliderFlightAdjust.stepValue = 1}}
        }
        
        lastStepTime = Date()
    }
    
    @IBAction func gliderPICAdjusted()
    {
        pilot.gliderPIChoursAdjust = Int64(gliderPICAdjust.value)
        gliderPIC.text = String(fromMinutes: Double(pilotStats.gliderPICminutes) + Double(pilot.gliderPIChoursAdjust))
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        
        if Date() - lastStepTime < 0.1
        {
            gliderPICAdjust.stepValue = 60
            mainQueue.asyncAfter(deadline: .now() + 1){if Date() - self.lastStepTime > 0.1{self.gliderPICAdjust.stepValue = 1}}
        }
        
        lastStepTime = Date()
    }
    
    @IBAction func gliderInstAdjusted()
    {
        pilot.gliderInstHoursAdjust = Int64(gliderInstructorAdjust.value)
        gliderInstructor.text = String(fromMinutes: Double(pilotStats.gliderInstructorMinutes) + Double(pilot.gliderInstHoursAdjust))
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        
        if Date() - lastStepTime < 0.1
        {
            gliderInstructorAdjust.stepValue = 60
            mainQueue.asyncAfter(deadline: .now() + 1){if Date() - self.lastStepTime > 0.1{self.gliderInstructorAdjust.stepValue = 1}}
        }
        
        lastStepTime = Date()
    }
    
    @IBAction func powerPICAdjusted()
    {
        pilot.powerHoursAdjust = Int64(powerPICAdjust.value)
        powerPIC.text = String(fromMinutes: Double(pilotStats.towPICminutes + Int(pilot.powerHoursAdjust))).decimalHoursValue
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        
        if Date() - lastStepTime < 0.1
        {
            powerPICAdjust.stepValue = 60
            mainQueue.asyncAfter(deadline: .now() + 1){if Date() - self.lastStepTime > 0.1{self.powerPICAdjust.stepValue = 6}}
        }
        
        lastStepTime = Date()
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
            case .ListFlightsSegue:
                let list = segue.destination as? ListFlights
                list?.pilot = pilot

            case .CreateLogBookSegue:
                let creator = segue.destination as? LogBookCreator
                creator?.pilot = pilot
        }
    }
}
