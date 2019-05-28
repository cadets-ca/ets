//
//  StatsManager.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-18.
//
//

import Foundation
import UIKit
import CoreData
import UserNotifications

final class StatsManager: NSObject
{
    var _previousKVSdictionaryRepresentation: Dictionary<String, Any>?

    var sharedContainerPath: String
    {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ca.cadets.Timesheets")!
        return containerURL.path.stringByAppendingPathComponent("KVSdata") 
    }
    
    var previousKVSdictionaryRepresentation: Dictionary<String, Any>
    {
        if _previousKVSdictionaryRepresentation == nil
        {
            _previousKVSdictionaryRepresentation = NSDictionary(contentsOfFile:sharedContainerPath) as? Dictionary<String, AnyObject>
            
            if _previousKVSdictionaryRepresentation == nil
            {
                _previousKVSdictionaryRepresentation = dataModel.keyValueStore.dictionaryRepresentation
            }
        }
        
        return _previousKVSdictionaryRepresentation!
    }
    
    override init()
    {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(self.performBackgroundUpdate), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
    }
    
    func updateKVSwithTotalNumberOfGliderFlight(_ totalNumberOfGliderFlights: Int = -1)
    {
        var flightsLastFiveDaysArray = [Int]()
        
        let mostRecentGliderFlightFetchRequest = FlightRecord.request
        mostRecentGliderFlightFetchRequest.predicate = NSPredicate(format: "timesheet.glidingCentre == %@ AND (flightSequence == %@ OR flightSequence == %@ OR flightSequence == %@)", dataModel.glidingCentre, "Towing", "Winching", "Auto")
        let sortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: false)
        mostRecentGliderFlightFetchRequest.sortDescriptors = [sortDescriptor]
        mostRecentGliderFlightFetchRequest.fetchBatchSize = 1
        let results = (try? dataModel.managedObjectContext.fetch(mostRecentGliderFlightFetchRequest)) ?? [FlightRecord]()
        
        let mostRecentGliderFlightRecord = results.first
        let mostRecentLaunchTime = mostRecentGliderFlightRecord?.timeUp ?? Date.distantPast
        
        let today = Date()
        let twelveWeeksAgo = today + Double(TIME_PERIOD_FOR_FUN_STATS)
        let thisMorningAtMidnight = today.midnight
        let yesterdayMorningAtMidnight = thisMorningAtMidnight + -1*60*60*24
        let twoDaysAgoAtMidnight = yesterdayMorningAtMidnight + -1*60*60*24
        let threeDaysAgoAtMidnight = twoDaysAgoAtMidnight + -1*60*60*24
        let fourDaysAgoAtMidnight = threeDaysAgoAtMidnight + -1*60*60*24
        
        if totalNumberOfGliderFlights >= 0
        {
            flightsLastFiveDaysArray.append(totalNumberOfGliderFlights)
        }
        
        else
        {
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.aircraft.gliderOrTowplane = 1 AND timesheet.glidingCentre == %@", argumentArray: [thisMorningAtMidnight, today, dataModel.glidingCentre!])
            let flightsToday = try! dataModel.managedObjectContext.count(for: request)
            flightsLastFiveDaysArray.append(flightsToday)
        }
        
        let flightsLastFewDaysRequest = FlightRecord.request
        flightsLastFewDaysRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.aircraft.gliderOrTowplane = 1 AND timesheet.glidingCentre == %@", argumentArray: [yesterdayMorningAtMidnight, thisMorningAtMidnight, dataModel.glidingCentre!])
        let flightsOneDayAgo = try! dataModel.managedObjectContext.count(for: flightsLastFewDaysRequest)
        flightsLastFiveDaysArray.append(flightsOneDayAgo)
        
        flightsLastFewDaysRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.aircraft.gliderOrTowplane = 1 AND timesheet.glidingCentre == %@", argumentArray: [twoDaysAgoAtMidnight, yesterdayMorningAtMidnight, dataModel.glidingCentre!])
        let flightsTwoDaysAgo = try! dataModel.managedObjectContext.count(for: flightsLastFewDaysRequest)
        flightsLastFiveDaysArray.append(flightsTwoDaysAgo)

        flightsLastFewDaysRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.aircraft.gliderOrTowplane = 1 AND timesheet.glidingCentre == %@", argumentArray: [threeDaysAgoAtMidnight, twoDaysAgoAtMidnight, dataModel.glidingCentre!])
        let flightsThreeDaysAgo = try! dataModel.managedObjectContext.count(for: flightsLastFewDaysRequest)
        flightsLastFiveDaysArray.append(flightsThreeDaysAgo)
        
        flightsLastFewDaysRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.aircraft.gliderOrTowplane = 1 AND timesheet.glidingCentre == %@", argumentArray: [fourDaysAgoAtMidnight, threeDaysAgoAtMidnight, dataModel.glidingCentre!])
        let flightsFourDaysAgo = try! dataModel.managedObjectContext.count(for: flightsLastFewDaysRequest)
        flightsLastFiveDaysArray.append(flightsFourDaysAgo)

        var gcInfo = [String: AnyObject]()
        gcInfo["FlightsLastFiveDaysArray"] = flightsLastFiveDaysArray as NSArray
        gcInfo["MostRecentLaunchTime"] = mostRecentLaunchTime as NSDate
        
        let flightsThisSeasonRequest = FlightRecord.request
        flightsThisSeasonRequest.predicate = NSPredicate(format: "timeUp > %@ AND timesheet.aircraft.gliderOrTowplane = 1 AND timesheet.glidingCentre == %@", argumentArray: [twelveWeeksAgo, dataModel.glidingCentre!])
        let flightsThisSeason = try! dataModel.managedObjectContext.fetch(flightsThisSeasonRequest)
        
        let numberOfGliderFlights = flightsThisSeason.count
        let numberOfGliderMinutes = flightsThisSeason.reduce(0, {$0 + Int($1.flightLengthInMinutes)})
        
        gcInfo["GliderFlightsThisSeason"] = numberOfGliderFlights as NSNumber
        gcInfo["GliderMinutesThisSeason"] = numberOfGliderMinutes  as NSNumber
        
        let newInfo = GlidingCentreData(name: dataModel.glidingCentre.name, gcData: gcInfo)
        var oldInfo: GlidingCentreData?
        
        if let oldStoredData = previousKVSdictionaryRepresentation[dataModel.glidingCentre.name] as? [String : AnyObject]
        {
            oldInfo = GlidingCentreData(name: dataModel.glidingCentre.name, gcData:oldStoredData)
        }
                        
        if (newInfo != oldInfo && numberOfGliderFlights > 0) || oldInfo == nil
        {
            dataModel.keyValueStore.set(gcInfo, forKey: dataModel.glidingCentre.name)
            (dataModel.keyValueStore.dictionaryRepresentation as NSDictionary).write(toFile: sharedContainerPath, atomically: true)
            _previousKVSdictionaryRepresentation = dataModel.keyValueStore.dictionaryRepresentation
        }
    }
    
    @objc func performBackgroundUpdate()
    {
        var KVSchangedExternally = false
        
        for gcName in (dataModel.keyValueStore.dictionaryRepresentation as Dictionary<String, AnyObject>).keys
        {
            if gcName == dataModel.glidingCentre.name
            {
                continue
            }
            
            let gcInfo = GlidingCentreData(name: gcName, gcData: (dataModel.keyValueStore.dictionaryRepresentation as Dictionary<String, AnyObject>)[gcName]! as! [String : AnyObject])
            var oldInfo: GlidingCentreData?
            if let oldStoredData = previousKVSdictionaryRepresentation[gcName] as? [String : AnyObject]
            {
                oldInfo = GlidingCentreData(name: gcName, gcData:oldStoredData)
            }

            let currentMostRecentLaunchTime = gcInfo.mostRecentFlight
            let previousMostRecentLaunchTime = oldInfo?.mostRecentFlight ?? Date.distantPast
            
            if currentMostRecentLaunchTime != previousMostRecentLaunchTime
            {
                KVSchangedExternally = true
                
                let flightsToday = gcInfo.flightsToday
                var userInfo = ["gcName" : gcName]
                
                let content = UNMutableNotificationContent()
                content.title = "Gliding Activity"
                
                if previousMostRecentLaunchTime.isDateInToday
                {
                    let alertText = "Gliding continues at \(gcName), \(flightsToday) flights today. Most recent launch at \(currentMostRecentLaunchTime.hoursAndMinutes)"
                    content.body = alertText
                    
//                    content.subtitle = "Gliding continues at \(gcName), \(flightsToday) flights today."
//                    content.body = "Most recent launch at \(currentMostRecentLaunchTime.hoursAndMinutes)"

                    userInfo["Alert Text"] = alertText
                    content.userInfo = userInfo
                }
                    
                else if currentMostRecentLaunchTime.isDateInToday
                {
                    
                    let alertText = "Gliding has begun at \(gcName), \(flightsToday) flights today. Most recent launch at \(currentMostRecentLaunchTime.hoursAndMinutes)"
                    content.body = alertText
                    userInfo["Alert Text"] = alertText
                    content.userInfo = userInfo
                }
                
//                let attachment = UNNotificationAttachment(identifier: "Crest", url: <#T##URL#>, options: nil)
                let requestIdentifier = "Gliding Activity Alert"
                let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler:{(error) in print(error?.localizedDescription ?? "")})
            }
        }
        
        if KVSchangedExternally
        {
            (dataModel.keyValueStore.dictionaryRepresentation as NSDictionary).write(toFile: sharedContainerPath, atomically: true)
            _previousKVSdictionaryRepresentation = dataModel.keyValueStore.dictionaryRepresentation
        }
        
//        print("Background update was called for")
    }
}
