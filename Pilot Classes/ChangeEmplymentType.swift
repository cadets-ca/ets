//
//  ChangeEmplymentType.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-22.
//
//

import Foundation
import UIKit

final class ChangeEmplymentType : UITableViewController
{
    var pilot: Pilot!
    @IBOutlet var staffCadet: UITableViewCell!
    @IBOutlet var CI: UITableViewCell!
    @IBOutlet var officer: UITableViewCell!
    @IBOutlet var volunteer: UITableViewCell!

    //MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        switch pilot.typeOfParticipant
        {
        case "Staff Cadet":
            staffCadet.accessoryType = .checkmark
        
        case "COATS":
            officer.accessoryType = .checkmark

        case "Civilian Instructor":
            CI.accessoryType = .checkmark
            
        case "Volunteer":
            volunteer.accessoryType = .checkmark
            
        default:
            break
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    //MARK: - UITableView Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let selectedParticipantType: String
        
        switch (indexPath as NSIndexPath).row
        {
        case 0:
            selectedParticipantType = "Staff Cadet"
            
        case 2:
            selectedParticipantType = "Civilian Instructor"

        case 3:
            selectedParticipantType = "COATS"
            
        default:
            selectedParticipantType = "Volunteer"
        }
        
        pilot.typeOfParticipant = selectedParticipantType
        
        for record in pilot.attendanceRecords where record.timeIn.isDateInToday
        {
            record.participantType = selectedParticipantType
            break
        }

        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        let _ = navigationController?.popViewController(animated: true)
    }
}
