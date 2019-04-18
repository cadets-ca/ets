//
//  RecordCell.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-25.
//

import Foundation
import UIKit

enum TableCellColor{case defaultColor, yellow, red, green, black}

final class FlightRecordCell : UITableViewCell
{
    @IBOutlet var aircraftName: UILabel!
    @IBOutlet var PICname: UILabel!
    @IBOutlet var passengerName: UILabel!
    @IBOutlet var sequenceName: UILabel!
    @IBOutlet var upAndDownTimes: UILabel!
    @IBOutlet var flightLength: UILabel!
    @IBOutlet var glidingCenter: UIImageView!
    
    var currentColor: TableCellColor?
    
    func setBackgroundToColor(_ color: TableCellColor, withImage image: UIImage)
    {
        if color != currentColor
        {
            currentColor = color
            backgroundView = UIImageView(image: image)
        }
    }
}

