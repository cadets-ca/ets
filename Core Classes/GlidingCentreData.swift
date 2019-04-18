//
//  GlidingCentreData.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-06-22.
//
//

import Foundation

final class GlidingCentreData: CustomStringConvertible, CustomDebugStringConvertible, Comparable
{
    let mostRecentFlight: Date
    let lastFiveDaysArray: [Int]
    let flightsThisSeason: Int
    let minutesThisSeason: Int
    let gcName: String
    var flightsToday: Int = 0
    
    let hasFlownToday: Bool
    let activeInLast100Days: Bool
    var flightsInLastFiveDays = 0
    
    init (name: String, gcData: [String: AnyObject])
    {
        gcName = name
//        print("\(gcName)")
        mostRecentFlight = gcData["MostRecentLaunchTime"] as? Date ?? Date()
        lastFiveDaysArray = gcData["FlightsLastFiveDaysArray"] as! [Int]
        flightsThisSeason = (gcData["GliderFlightsThisSeason"] as? Int) ?? 0
        minutesThisSeason = (gcData["GliderMinutesThisSeason"] as? Int) ?? 0
        hasFlownToday = mostRecentFlight.isDateInToday
        activeInLast100Days = mostRecentFlight.timeIntervalSinceNow > -1*60*60*24*100 ? true : false
        
        let componentsOfIntervalSinceLastFlight = gregorian.dateComponents([.day], from: mostRecentFlight, to: Date())
        let daysSinceLastFlight = componentsOfIntervalSinceLastFlight.day ?? 0
        let daysRelevant = 5 - daysSinceLastFlight
        
        if daysRelevant > 0
        {
            flightsToday = hasFlownToday ? lastFiveDaysArray[0] : 0
            for i in 0 ..< daysRelevant
            {
                flightsInLastFiveDays += lastFiveDaysArray[i]
            }
        }
    }
    
    var description: String
        {
            return "\(gcName) has flown \(flightsInLastFiveDays) times in the last five days and \(flightsThisSeason) times this season. Its most recent flight was \(mostRecentFlight). It has flown today \(hasFlownToday) and in the last 100 days \(activeInLast100Days)"
    }
    
    var debugDescription: String
        {
            return description
    }
}

func == (lhs: GlidingCentreData, rhs: GlidingCentreData) -> Bool
{
    if (lhs.flightsToday != rhs.flightsToday) || (lhs.flightsThisSeason != rhs.flightsThisSeason) || (lhs.gcName != rhs.gcName)
    {
        return false
    }
    
    return true
}

func < (lhs: GlidingCentreData, rhs: GlidingCentreData) -> Bool
{
    if lhs.flightsInLastFiveDays != rhs.flightsInLastFiveDays
    {
        return lhs.flightsInLastFiveDays < rhs.flightsInLastFiveDays
    }
    
    else
    {
        if lhs.flightsToday != rhs.flightsToday
        {
            return lhs.flightsToday < rhs.flightsToday
        }
        
        else
        {
            return lhs.flightsThisSeason < rhs.flightsThisSeason
        }
    }
}

