//
//  TableViewCellStylePilot.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-05.
//
//

import Foundation
import UIKit

final class TableViewCellStylePilot : UITableViewCell
{
    @IBOutlet var pilotName: UILabel!
    @IBOutlet var currentUntilLabel: UILabel?
    @IBOutlet var currentUntilDate: UILabel?
    @IBOutlet var aviationMedicalLabel: UILabel?
    @IBOutlet var aviationMedicalValidity: UILabel?
    @IBOutlet var flightIsntructorRatingLabel: UILabel?
    @IBOutlet var flightIsntructorRatingValidity: UILabel?
    @IBOutlet var PIClabel: UILabel?
    @IBOutlet var PICflights: UILabel?
    @IBOutlet var PIChours: UILabel?
    @IBOutlet var dualLabel: UILabel!
    @IBOutlet var dualFlights: UILabel!
    @IBOutlet var dualHours: UILabel!
    @IBOutlet var squadronLabel: UILabel?
    @IBOutlet var squadronNumber: UILabel?
    @IBOutlet var lifetimeFlightsLabel: UILabel?
    @IBOutlet var lifetimeFlightsNumber: UILabel?
    @IBOutlet var photoImageView: UIImageView?
    
    func setPhoto(_ newPhoto: UIImage? = nil)
    {
        if newPhoto != nil
        {
            photoImageView?.image = newPhoto
            photoImageView?.isHidden = false
        }
        
        else
        {
            photoImageView?.image = nil
            photoImageView?.isHidden = true
        }
    }
}
