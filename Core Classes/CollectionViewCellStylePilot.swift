//
//  CollectionViewCellStylePilot.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-12.
//
//

import Foundation
import UIKit

final class CollectionViewCellStylePilot : UICollectionViewCell
{
    @IBOutlet var medicalExpiryDate: UILabel!
    @IBOutlet var currencyExpiryDate: UILabel!
    @IBOutlet var flightInstructorExpiryDate: UILabel?
    @IBOutlet var numberOfDaysWorked: UILabel!
    @IBOutlet var totalGliderFlights: UILabel?
    @IBOutlet var totalTowFlights: UILabel?
    @IBOutlet var gliderFlightsInPast365days: UILabel?
    @IBOutlet var towFlightsInPast365days: UILabel?
    @IBOutlet var launchesAsWinchOperator: UILabel?
    @IBOutlet var winchLabel: UILabel?
    @IBOutlet var launchesAsAutoTowDriver: UILabel?
    @IBOutlet var PICtime: UILabel!
    @IBOutlet var instructorTime: UILabel?
    @IBOutlet var participantStatus: UILabel!
    @IBOutlet var towPIC: UILabel?
    @IBOutlet var name: UILabel!
    @IBOutlet var photo: UIImageView!
    
    override func prepareForReuse()
    {
        super.prepareForReuse()
        
        name.text = nil
        photo.image = nil
        participantStatus.text = nil
        medicalExpiryDate.text = nil
        currencyExpiryDate.text = nil
        flightInstructorExpiryDate?.text = nil
        numberOfDaysWorked.text = nil
        totalGliderFlights?.text = nil
        launchesAsWinchOperator?.text = nil
        launchesAsAutoTowDriver?.text = nil
        gliderFlightsInPast365days?.text = nil
        PICtime.text = nil
        towPIC?.text = nil
        instructorTime?.text = nil
        totalTowFlights?.text = nil
        towFlightsInPast365days?.text = nil
    }
}

