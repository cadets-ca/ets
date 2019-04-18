//
//  DateExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-03.
//
//

import Foundation
import UIKit

let gregorian = Calendar.autoupdatingCurrent

var militaryFormat: DateFormatter =
{
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "dd-MM-yy"
    return formatter
}()

var HHmmFormatter: DateFormatter =
{
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "HHmm"
    return formatter
}()

var militaryLongFormatter: DateFormatter =
{
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "dd-MMMM-yyyy"
    return formatter
}()

var militaryShortFormatter: DateFormatter =
{
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "dd-MMM-yy"
    return formatter
}()

var yearFormatter: DateFormatter =
{
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy"
    return formatter
}()

public func - (left: Date, right: Date) -> Double
{
    return left.timeIntervalSince(right)
}

public func > (left: Date?, right: Date?) -> Bool
{
    return left ?? Date.distantPast > right ?? Date.distantPast
}

extension Date
{
    static func updateFormatters()
    {
        militaryFormat.timeZone = TimeZone.current
        HHmmFormatter.timeZone = TimeZone.current
        militaryLongFormatter.timeZone = TimeZone.current
        militaryShortFormatter.timeZone = TimeZone.current
        yearFormatter.timeZone = TimeZone.current
    }
    
    static var startOfYear: Date
    {
        var components = gregorian.dateComponents([.year], from: Date())
        components.month = 1
        components.day = 1
        return gregorian.date(from: components) ?? Date()
    }
    
    static var startOfPriorYear: Date
    {
        var components = gregorian.dateComponents([.year], from: Date())
        components.month = 1
        components.day = 1
        components.year = components.year! - 1
        return gregorian.date(from: components) ?? Date()
    }
    
    var startOfMonth: Date
    {
        var components = gregorian.dateComponents([.year, .month], from: self)
        components.day = 1
        return gregorian.date(from: components) ?? Date()
    }
    
    var startOfDay: Date
    {
        return gregorian.startOfDay(for: self)
    }
    
    var isDateInToday: Bool
    {
        return gregorian.isDateInToday(self)
    }
    
    var IsDuringSummerOps: Bool
    {
        let dayOfMonthDateFormatter = DateFormatter()
        dayOfMonthDateFormatter.dateFormat = "ddMMyyyy"
        dayOfMonthDateFormatter.timeZone = TimeZone.current
        
        let yearDateFormatter = DateFormatter()
        yearDateFormatter.dateFormat = "yyyy"
        yearDateFormatter.timeZone = TimeZone.current
        let yearString = yearDateFormatter.string(from: Date())
        let startDateString = "1006\(yearString)"
        
        let RGSstartDate = dayOfMonthDateFormatter.date(from: startDateString)!
        let secondsSinceRGSstart = Int(timeIntervalSince(RGSstartDate))
        
        var returnValue = true
        
        if (secondsSinceRGSstart > LENGTH_OF_SUMMER_OPS) || (secondsSinceRGSstart < 0)
        {
            returnValue = false
        }
        
        return returnValue
    }
    
    var floorToMinute: Date
    {
        let comps = gregorian.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return gregorian.date(from: comps) ?? Date()
    }
    
    /// Returns a Date corresponding to local midnight of the receiver
    var midnight: Date
    {
        let comps = gregorian.dateComponents([.year, .month, .day], from: self)
        return gregorian.date(from: comps) ?? Date()
    }
    
    var hoursAndMinutes: String
    {
        return HHmmFormatter.string(from: self)
    }
    
    var militaryFormatLong: String
    {
        var todayDate = militaryLongFormatter.string(from: self)
        
        if todayDate.hasPrefix("0")
        {
            todayDate.remove(at: todayDate.startIndex)
        }
        
        return todayDate
    }

    /// Returns a string in format dd-MMM-YY hhmm
    var militaryFormatWithMinutes: String
    {
        return "\(militaryFormatShort) \(hoursAndMinutes)"
    }

    var year: String
    {
        return yearFormatter.string(from: self)
    }

    var militaryFormatShort: String
    {
        var todayDate = militaryShortFormatter.string(from: self)
        
        if todayDate.hasPrefix("0")
        {
            todayDate.remove(at: todayDate.startIndex)
        }
        
        return todayDate
    }

    var calculateAPCanniversaryFromSelf: Date
    {
        let comps = DateComponents(month: 13)
        let date = gregorian.date(byAdding: comps, to:self) ?? Date()
        return Date(timeInterval: (24*60*60 - 1), since: date.midnight)
    }
}
