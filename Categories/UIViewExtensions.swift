//
//  UIViewExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-03.
//
//

import Foundation
import UIKit

extension UIView
{
    var tableViewCell: UITableViewCell?
    {
        var cell: UITableViewCell?
        var superview = self
        
        while let parent = superview.superview
        {
            superview = parent
            if let cellFound = superview as? UITableViewCell
            {
                cell = cellFound
                break
            }
        }
        
        return cell
    }
}