//
//  TableViewCellStyleRecord.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-05.
//
//

import Foundation
import UIKit

final class TableViewCellStyleRecord : UITableViewCell
{
    @IBOutlet var aircraftName: UILabel!
    @IBOutlet var PIClabel: UILabel?
    @IBOutlet var PICname: UILabel!
    @IBOutlet var passengerName: UILabel!
    @IBOutlet var passengerLabel: UILabel?
    @IBOutlet var connectedAircraftName: UILabel?
    @IBOutlet var connectedAircraftLabel: UILabel?
    @IBOutlet var sequenceName: UILabel!
    @IBOutlet var sequenceLabel: UILabel?
    @IBOutlet var upAndDownTimes: UILabel!
    @IBOutlet var flightLength: UILabel!
    
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
