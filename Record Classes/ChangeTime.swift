//
//  ChangeTime.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-23.
//
//

import Foundation
import UIKit

final class ChangeTime : ChangeSignificantDate
{
    var flightRecord: FlightRecord!
    var upOrDown = ChangeTimeMode.uptime
    var aircraftIsFlying = true

    convenience init(record: FlightRecord, upOrDown mode: ChangeTimeMode, aircraftIsFlying flyingOrNot: Bool, delegate: ChangeSignificantDateDelegate? = nil)
    {
        self.init()
        self.delegate = delegate
        upOrDown = mode
        aircraftIsFlying = flyingOrNot
        flightRecord = record
        locale = Locale(identifier: "fr")
        addTarget(self, action: #selector(ChangeSignificantDate.timeChanged), for: .valueChanged)
        datePickerMode = .time
        
        if aircraftIsFlying
        {
            upOrDown = .uptime
        }
        
        if upOrDown == .uptime
        {
            date = flightRecord.timeUp as Date
            var downTime = Date()
            let recordDownTime = flightRecord.timeDown
            let connectedRecordDownTime = flightRecord.connectedAircraftRecord?.timeDown ?? recordDownTime
            
            let recordAircraftType = flightRecord.timesheet?.aircraft?.type ?? VehicleType.glider
            
            if let connectedRecordAircraftType = flightRecord.connectedAircraftRecord?.timesheet?.aircraft?.type
            {
                switch (recordAircraftType, connectedRecordAircraftType)
                {
                case let (recordType, connectedType) where (recordType > .winch && connectedType > .winch):
                    downTime = recordDownTime < connectedRecordDownTime ? recordDownTime : connectedRecordDownTime

                case let (recordType, connectedType) where (recordType > .winch && connectedType <= .winch):
                    downTime = recordDownTime
                    
                case (.winch, _):
                    if flightRecord.connectedAircraftRecord?.timeDown != Date.distantFuture
                    {
                        downTime = connectedRecordDownTime
                    }
                 
                default:
                break
                }
            }
            
            maximumDate = downTime + -60
            
            if aircraftIsFlying
            {
                maximumDate = Date()
            }
        }
            
        else
        {
            date = self.flightRecord.timeDown as Date
            let upTime = self.flightRecord.timeUp
            minimumDate = upTime as Date + 60
        }
    }
    
    override func timeChanged()
    {
        flightRecord.timesheet.logChangesTo(record: flightRecord)
        
        let newDate = date
        
        if upOrDown == .uptime
        {
            flightRecord.timeUp = newDate
        }
            
        else
        {
            flightRecord.timeDown = newDate
        }
        
        var minutes: Int
        
        if aircraftIsFlying
        {
            let comps = gregorian.dateComponents([.minute], from: flightRecord.timeUp, to: Date())
            minutes = comps.minute!
        }
            
        else
        {
            let comps = gregorian.dateComponents([.minute], from: flightRecord.timeUp, to: flightRecord.timeDown)
            minutes = comps.minute!
        }
        
        if flightRecord.timesheet.aircraft.type > .winch
        {
            flightRecord.flightLengthInMinutes = Int16(minutes)
        }
            
        else
        {
            flightRecord.timeDown = newDate
        }
        
        if upOrDown == .uptime, let connectedAircraftRecord = flightRecord.connectedAircraftRecord
        {
            connectedAircraftRecord.timesheet.logChangesTo(record: connectedAircraftRecord)
            connectedAircraftRecord.timeUp = newDate
            
            if connectedAircraftRecord.timesheet.aircraft.type > .winch
            {
                var flightLengthInSeconds: Double
                
                if connectedAircraftRecord.timeDown == Date.distantFuture
                {
                    flightLengthInSeconds = Date().floorToMinute - newDate
                }
                    
                else
                {
                    flightLengthInSeconds = connectedAircraftRecord.timeDown - newDate
                }
                
                minutes = Int(round(flightLengthInSeconds / 60))
                connectedAircraftRecord.flightLengthInMinutes = Int16(minutes)
                connectedAircraftRecord.timesheet?.aircraft?.updateTTSN()
                
            }
                
            else
            {
                connectedAircraftRecord.timeDown = newDate
            }
        }
        
        guard let aircraft = flightRecord.timesheet?.aircraft else {return}
        if aircraft.type > .winch
        {
            aircraft.updateTTSN()
        }
        
        NotificationCenter.default.post(name: aircraftChangedNotification, object:aircraft, userInfo:nil)
        dataModel.saveContext()
        delegate?.dateChanged()
        dataModel.aircraftAreaController?.updateFlightTimes()
        
        flightRecord.timesheet?.aircraft?.checkConsistencyBasedOnChangesToRecord(flightRecord)
        flightRecord.pilot?.checkConsistencyBasedOnChangesToRecord(flightRecord)
        flightRecord.passenger?.checkConsistencyBasedOnChangesToRecord(flightRecord)
    }
}
