//
//  StringExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-23.
//
//

import Foundation

var nextRowGrey = false

extension String
{
    /// Takes a number of seconds and creates a string in the format of hh:mm
    ///
    /// - parameter seconds: a number of seconds
    ///
    /// - returns: Formatted string
    init(fromSeconds seconds: Double)
    {
        var negative = false
        
        if seconds < 0
        {
            negative = true
        }
        
        let secondsProvided = abs(seconds)
        var hours = floor(secondsProvided / 3600)
        var minutes = round((secondsProvided - (hours * 3600)) / 60)
        
        if minutes == 60
        {
            minutes = 0
            hours += 1
        }
        
        var minuteString = "\(Int(minutes))"
        var hourString = "\(Int(hours))"
        
        if negative
        {
            hourString = "-" + hourString
        }
        
        if minutes < 10
        {
            minuteString = "0" + minuteString
        }
        
        let properlyFormatted = "\(hourString):\(minuteString)"
        self = properlyFormatted
    }
    
    init(fromMinutes minutes: Double)
    {
        let seconds = minutes*60
        var negative = false
        
        if seconds < 0
        {
            negative = true
        }
        
        let secondsProvided = abs(seconds)
        var hours = floor(secondsProvided / 3600)
        var minutes = round((secondsProvided - (hours * 3600)) / 60)
        
        if minutes == 60
        {
            minutes = 0
            hours += 1
        }
        
        var minuteString = "\(Int(minutes))"
        var hourString = "\(Int(hours))"
        
        if negative
        {
            hourString = "-" + hourString
        }
        
        if minutes < 10
        {
            minuteString = "0" + minuteString
        }
        
        let properlyFormatted = "\(hourString):\(minuteString)"
        self = properlyFormatted
    }
    
    var intValueWithNegatives: Int
        {
            var value = self
            
            if let decimalIndex = value.firstIndex(of: ".")
            {
                value = String(value[..<decimalIndex])
            }
            
            if let negativeIndex = value.firstIndex(of: "-")
            {
                value.remove(at: negativeIndex)
                let positivePart = Int(value) ?? 0
                return -positivePart
            }
                
            else
            {
                return Int(value) ?? 0
            }
    }
    
    /// Returns a string formatted hours.tenths
    var decimalHoursValue: String
    {
        let components = self.components(separatedBy: ":")
        var hour = Int(components[0])!
        let minute = Int(components[1])!
        var rounded = Int(round(Double(minute)/6))
        
        if rounded == 10
        {
            rounded = 0
            hour += 1
        }
        
        return "\(hour).\(rounded)"
    }
    
    var doubleValue: Double
    {
        return (self as NSString).doubleValue
    }
    
    func stringByAppendingPathComponent(_ component: String) -> String
    {
        return (self as NSString).appendingPathComponent(component)
    }
    
    /// Creates the HTML code for a table row.
    ///
    /// - parameter shading:          By default, even numbered table rows are shaded. This parameter can override this.
    /// - parameter header:           If header is set to true, the row will be a deeper grey and content will be bold. Shading is ignored in this case.
    /// - parameter rowTextGenerator: A closure that generates the cells for the table row.
    mutating func appendTableRow(shading: Bool? = nil, header: Bool = false, _ rowTextGenerator: () -> String)
    {
        if header
        {
            self += "<tr bgcolor='CCCCCC'>"
        }
        
        else
        {
            if let shade = shading
            {
                nextRowGrey = shade
            }
            
            if nextRowGrey
            {
                self += "<tr bgcolor='#E3E3E3'>"
            }
                
            else
            {
                self += "<tr>"
            }
            
            nextRowGrey = !nextRowGrey
        }
        
        self += rowTextGenerator()
        self += "</tr>"
    }
}
