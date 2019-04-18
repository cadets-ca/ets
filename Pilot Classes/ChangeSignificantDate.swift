//
//  ChangeSignificantDate.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-23.
//
//

import Foundation
import UIKit

protocol ChangeSignificantDateDelegate
{
    func dateChanged()
}

class ChangeSignificantDate : UIDatePicker
{
    var logBookCreator: LogBookCreator?
    var recordActions: RecordActions?
    var pilot: Pilot?
    var typeOfSignificantDate = SignificantDateMode.birthday
    var delegate: ChangeSignificantDateDelegate?
    
    deinit
    {
        print("deleted")
    }
    
    @objc func timeChanged()
    {
        switch typeOfSignificantDate
        {
        case .birthday:
            pilot?.birthday = date
            
        case .gliderAPC:
            pilot?.aniversaryOfGliderAPC = date
            
        case .towAPC:
            pilot?.aniversaryOfTowAPC = date
            
        case .medicalExpiry:
                let newDate = date.startOfMonth
                setDate(newDate, animated:true)
                pilot?.medical = newDate
                dataModel.saveContext()
            
        case .fIexpiry:
                pilot?.fiExpiry = date

        case .towPilotDate:
                pilot?.dateOfTowPilot = date

        case .towCheckPilotDate:
                pilot?.dateOfTowCheckPilot = date

        case .towStandardsPilotDate:
                pilot?.dateOfTowStandardsPilot = date

        case .basicGliderPilotDate:
                pilot?.dateOfBasicGliderPilot = date

        case .fsfDate:
                pilot?.dateOfFrontSeatFamilPilot = date
            
        case .rsfDate:
                pilot?.dateOfRearSeatFamilPilot = date
            
        case .qgiDate:
                pilot?.dateOfGliderInstructorPilot = date

        case .gliderCheckPilotDate:
                pilot?.dateOfGliderCheckPilot = date

        case .gliderStandardsPilotDate:
                pilot?.dateOfGliderStandardsPilot = date

        case .lcoDate:
                pilot?.dateOfLaunchControlOfficer = date

        case .winchLaunchDate:
                pilot?.dateOfWinchLaunchPilot = date
            
        case .winchOperatorDate:
                pilot?.dateOfWinchLaunchOperator = date
            
        case .winchLaunchInstructorDate:
                pilot?.dateOfWinchLaunchInstructor = date

        case .winchRetrieveDate:
                pilot?.dateOfWinchRetrieveDriver = date
            
        case .gliderXCountryDate:
                pilot?.dateOfGliderPilotXCountry = date
            
        case .towXCountryDate:
                pilot?.dateOfTowPilotXCountry = date

        case .logBookStartDate:
                logBookCreator?.startDate = date
            
        case .logBookEndDate:
                logBookCreator?.endDate = date
            
        case .statsReportStartDate:
                recordActions?.statsReportStartDate = date
            
        case .statsReportEndDate:
                recordActions?.statsReportEndDate = date
        }
        
        delegate?.dateChanged()
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
    }
    
    convenience init(mode: SignificantDateMode, pilotBeingEdited: Pilot? = nil, recordActions actions: RecordActions? = nil, logBookCreator creator: LogBookCreator? = nil)
    {
        self.init()
        
        typeOfSignificantDate = mode
        pilot = pilotBeingEdited
        recordActions = actions
        logBookCreator = creator
        self.addTarget(self, action: #selector(ChangeSignificantDate.timeChanged), for: .valueChanged)
        datePickerMode = .date
        
        switch mode
        {
        case .birthday:
            let twelveYearsAgo = Double(-365*24*60*60*12)
            let oneHundredTwentyYearsAgo = twelveYearsAgo * 10
            let sixteenYearsAgo = Double(-365.1*24*60*60*16)
            
            let now = Date()
            let latestDate = now + twelveYearsAgo
            let earliestDate = now + oneHundredTwentyYearsAgo
            if let birthday = pilot?.birthday
            {
                date = birthday as Date
            }
            
            else
            {
                date = now + sixteenYearsAgo
            }

            maximumDate = latestDate
            minimumDate = earliestDate
            
        case .towAPC:
                let now = Date()
                maximumDate = now
                date = (pilot?.aniversaryOfTowAPC ?? now) as Date

                if pilot?.aniversaryOfTowAPC == nil
                {
                    pilot?.aniversaryOfTowAPC = now
                    NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
                }
            
        case .gliderAPC:
                let now = Date()
                maximumDate = now
                date = (pilot?.aniversaryOfGliderAPC ?? now) as Date

                if pilot?.aniversaryOfGliderAPC == nil
                {
                    pilot?.aniversaryOfGliderAPC = now
                    NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
                }
            
        case .medicalExpiry:
                date = pilot?.medical ?? Date().startOfMonth
            
        case .fIexpiry:
                date = (pilot?.fiExpiry ?? Date()) as Date
            
        case .towPilotDate:
                date = (pilot?.dateOfTowPilot ?? Date()) as Date
            
        case  .towCheckPilotDate:
                date = (pilot?.dateOfTowCheckPilot ?? Date()) as Date
            
        case .towStandardsPilotDate:
                date = (pilot?.dateOfTowStandardsPilot ?? Date()) as Date
            
        case .basicGliderPilotDate:
                date = (pilot?.dateOfBasicGliderPilot ?? Date()) as Date
            
        case .fsfDate:
                date = (pilot?.dateOfFrontSeatFamilPilot ?? Date()) as Date
            
        case .rsfDate:
                date = pilot?.dateOfRearSeatFamilPilot ?? Date()

        case .qgiDate:
                date = pilot?.dateOfGliderInstructorPilot ?? Date()
            
        case .gliderCheckPilotDate:
                date = (pilot?.dateOfGliderCheckPilot ?? Date()) as Date
            
        case .gliderStandardsPilotDate:
                date = (pilot?.dateOfGliderStandardsPilot ?? Date()) as Date

        case .lcoDate:
                date = (pilot?.dateOfLaunchControlOfficer ?? Date()) as Date
            
        case .winchLaunchDate:
                date = (pilot?.dateOfWinchLaunchPilot ?? Date()) as Date

        case .winchOperatorDate:
                date = (pilot?.dateOfWinchLaunchOperator ?? Date()) as Date
            
        case .winchLaunchInstructorDate:
                date = (pilot?.dateOfWinchLaunchInstructor ?? Date()) as Date
            
        case .winchRetrieveDate:
                date = (pilot?.dateOfWinchRetrieveDriver ?? Date()) as Date

        case .gliderXCountryDate:
                date = (pilot?.dateOfGliderPilotXCountry ?? Date()) as Date

        case .towXCountryDate:
                date = (pilot?.dateOfTowPilotXCountry ?? Date()) as Date

        case .logBookStartDate:
                date = logBookCreator?.startDate ?? Date()

        case .logBookEndDate:
                date = logBookCreator?.endDate ?? Date()
            
        case .statsReportStartDate:
                date = recordActions?.statsReportStartDate ?? Date()
            
        case .statsReportEndDate:
                date = recordActions?.statsReportEndDate ?? Date()
        }
        
        let oneThousandYearsAgo = Date() - 1000*365*24*60*60
        date = date > oneThousandYearsAgo ? date : Date()
    }
}
