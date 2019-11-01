//
//  UIColorExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-03.
//
//

import Foundation
import UIKit

extension UIColor
{
    /**
     Create a UIColor from an hex string.
     
     The hex string can begin with a '#' or not.
     
     If the number of character is 6, FF is assumed as the alpha portion. If the string is 8 the 1st pair is assumed to be the alpha.
     */
    public convenience init?(hex hexString: String)
    {
        var chars = Array(hexString.hasPrefix("#") ? hexString.dropFirst() : hexString[...])
        let red, green, blue, alpha: CGFloat
        switch chars.count {
            case 3:
                chars = chars.flatMap { [$0, $0] }
                fallthrough
            case 6:
                chars = ["F","F"] + chars
                fallthrough
            case 8:
                alpha = CGFloat(strtoul(String(chars[0...1]), nil, 16)) / 255
                red   = CGFloat(strtoul(String(chars[2...3]), nil, 16)) / 255
                green = CGFloat(strtoul(String(chars[4...5]), nil, 16)) / 255
                blue  = CGFloat(strtoul(String(chars[6...7]), nil, 16)) / 255
            default:
                return nil
        }
        self.init(red: red, green: green, blue:  blue, alpha: alpha)
    }
    
    class func darkGreen() -> UIColor
    {
        return UIColor(red: 26.0/255, green: 107.0/255, blue: 15.0/255, alpha: 1)
    }
}
