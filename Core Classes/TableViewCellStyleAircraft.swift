//
//  TableViewCellStyleAircraft.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-05.
//
//

import Foundation
import UIKit

final class TableViewCellStyleAircraft : UITableViewCell
{
    @IBOutlet var pilotName: UILabel!
    @IBOutlet var aircraftName: UILabel!
    @IBOutlet var flightTimeCounter: UILabel!
    @IBOutlet var passengerName: UILabel!
    @IBOutlet var pilotCockpitTime: UILabel!
    @IBOutlet var flightSequenceType: UILabel!
    @IBOutlet var TNIlabel: UILabel!
    @IBOutlet var TNIvalue: UILabel!
    @IBOutlet var sequenceLabel: UILabel!
    @IBOutlet var cockpitTimeLabel: UILabel!
    @IBOutlet var takeOffButton: UIButton!
    @IBOutlet var landButton: UIButton!
    @IBOutlet var beaconStatusImageView: UIImageView?
    
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
