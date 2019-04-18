//
//  DoubleExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-13.
//
//

import Foundation

extension Double
{
    var oneDecimalStringRepresentation: String
        {
            return String(format: "%.1f", self)
        }
}
