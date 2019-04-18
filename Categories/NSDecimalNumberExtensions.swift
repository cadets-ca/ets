//
//  NSDecimalNumberExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-03.
//
//

import Foundation

extension NSDecimalNumber
{
    var stringWithDecimal: String
    {
        return decimalNumberFormatter.string(from: self)!
    }
    
    var minutesFromHours: Int
    {
        let hours = rounding(accordingToBehavior: behavior)
        let minutes = subtracting(hours).multiplying(byPowerOf10: 1)
        
        return (hours.intValue * 60) + (minutes.intValue * 6)
    }
    
    var integerPortion: Int
    {
        return rounding(accordingToBehavior: behavior).intValue
    }
    
    var firstDecimalPlaceDigit: Int
    {
        let hours = rounding(accordingToBehavior: behavior)
        let minutes = subtracting(hours).multiplying(byPowerOf10: 1)
        
        return minutes.intValue
    }
}

extension Decimal
{
    /// Returns a string representation containing exactly one decimal place.
    var stringWithDecimal: String
    {
        return decimalNumberFormatter.string(from: self as NSDecimalNumber) ?? ""
    }
    
    var minutesFromHours: Int
    {
        return Int(truncating: (self * 60) as NSDecimalNumber)
    }
    
    var integerPortion: Int
    {
        return Int(truncating: self as NSDecimalNumber)
    }
    
    var firstDecimalPlaceDigit: Int
    {
        return Int(truncating: (self * 10) as NSDecimalNumber) - integerPortion * 10
    }
}
