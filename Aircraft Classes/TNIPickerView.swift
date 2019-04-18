//
//  TNIPickerView.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-17.
//
//

import Foundation
import UIKit

final class TNIPickerView : UIViewController, UIPickerViewDataSource, UIPickerViewDelegate
{
    @IBOutlet var picker: UIPickerView!
    @IBOutlet var stepper: UIStepper!
    @IBOutlet var stackView: UIStackView!

    var aircraftBeingEdited: AircraftEntity!
    var timesheetBeingEdited: AircraftTimesheet!
    var mode = TNIpickerMode.tni
    
    private var initialTimeRemainingHourString = ""
    private var initialTNIdecimalFormat = Decimal(0)
    private var initialhours = 0
    private var initialdecimal = 0
    private var currentHours = 0
    private var currentDecimal = 0
    private var newHours = 0
    private var newDecimal = 0
    private var currentStepperValue = 0

    //MARK: - UIViewController Methods
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        currentStepperValue = 0
        if aircraftBeingEdited == nil
        {
            aircraftBeingEdited = timesheetBeingEdited.aircraft
        }
        
        if mode != .initialTTSN
        {
            guard let setToPriorTTSNbutton = stackView.subviews.last else {return}
            stackView.removeArrangedSubview(setToPriorTTSNbutton)
            setToPriorTTSNbutton.removeFromSuperview()
        }
        
        switch mode
        {
        case .tni:
            initialTNIdecimalFormat = dataModel.aircraftAreaController?.calculateTNIforAircraft(aircraftBeingEdited) ?? 0
            title = "TNI"
            
            guard let adjustBy1000 = stackView.subviews.last else {break}
            stackView.removeArrangedSubview(adjustBy1000)
            adjustBy1000.removeFromSuperview()
            
            if initialTNIdecimalFormat < 0
            {
                initialTNIdecimalFormat = 0
                aircraftBeingEdited.TTNI = aircraftBeingEdited.currentTimesheet?.TTSNfinal ?? 0
            }

        case .ttsn:
            var timesheet = aircraftBeingEdited.currentTimesheet
            if timesheet == nil
            {
                dataModel.setCurrentTimesheetForAircraft(self.aircraftBeingEdited, possibleContext:nil)
                timesheet = aircraftBeingEdited?.currentTimesheet
            }
            
            initialTNIdecimalFormat = timesheet?.TTSNfinal ?? 0
            title = "TTSN"

        case .initialTTSN:
            initialTNIdecimalFormat = timesheetBeingEdited.TTSNinitial
            title = "Initial TTSN"

        case .finalTTSN:
            initialTNIdecimalFormat = timesheetBeingEdited.TTSNfinal
            title = "Final TTSN"

        case .ttni:
            initialTNIdecimalFormat = aircraftBeingEdited.TTNI
            title = "TTNI"
        }
        
        currentHours = initialTNIdecimalFormat.integerPortion
        currentDecimal = initialTNIdecimalFormat.firstDecimalPlaceDigit
        
        picker.selectRow(currentHours, inComponent:0, animated:false)
        picker.selectRow(currentDecimal, inComponent:1, animated:false)
        
        initialhours = currentHours
        newHours = currentHours
        initialdecimal = currentDecimal
        newDecimal = currentDecimal
        
        let initialHoursInThousands = initialhours / 1000
        stepper.minimumValue = Double(initialHoursInThousands * -1000)
        
        self.preferredContentSize = CGSize(width: 320, height: 400)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
    
    @IBAction func saveButtonPushed()
    {
        if (newHours != initialhours) || (newDecimal != initialdecimal)
        {
            let confirmChangesAlert = UIAlertController(title: "Save Changes?", message: "Do you want to save the changes you have made to this time?", preferredStyle: .alert)
            
            let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let signOutButton = UIAlertAction(title: "Save", style: .default){_ in
                self.save()
            }
            
            confirmChangesAlert.addAction(signOutButton)
            confirmChangesAlert.addAction(cancelButton)
            
            self.present(confirmChangesAlert, animated:true, completion:nil)
        }
    }
    
    @IBAction func setToPriorButtonPushed()
    {
        let oldTTSN = timesheetBeingEdited.TTSNinitial
        timesheetBeingEdited.setTTSN()
        let newTTSN = timesheetBeingEdited.TTSNinitial
        
        newHours = newTTSN.integerPortion
        newDecimal = newTTSN.firstDecimalPlaceDigit
        
        currentHours = newHours
        currentDecimal = newDecimal
        
        picker.selectRow(currentHours, inComponent:0, animated: true)
        picker.selectRow(currentDecimal, inComponent:1, animated: true)
        
        timesheetBeingEdited.TTSNinitial = oldTTSN
    }
    
    //MARK: - UIPickerViewDelegate Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int
    {
        return 2
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
    {
        var numberOfRows = 0
        
        if mode == .tni
        {
            switch component
            {
            case 0:
                numberOfRows = 101
                
            case 1:
                numberOfRows = 10
                
            default:
                break
            }
        }
            
        else
        {
            switch component
            {
            case 0:
                numberOfRows = 100000
                
            case 1:
                numberOfRows = 10
                
            default:
                break
            }
        }
        
        return numberOfRows
    }
    

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat
    {
        return 44.0
    }
    
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat
    {
        return component != 0 ? 50.0 : 100.0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        return "\(row)"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        newHours = pickerView.selectedRow(inComponent: 0)
        newDecimal = pickerView.selectedRow(inComponent: 1)
        
        currentHours = newHours
        currentDecimal = newDecimal
    }
    
    @IBAction func stepperValueChanged()
    {
        let stepperChange = Int(stepper.value) - currentStepperValue
        let currentPickerRow = picker.selectedRow(inComponent: 0)
        let newPickerRow = currentPickerRow + stepperChange
        
        picker.selectRow(newPickerRow, inComponent:0, animated:true)
        pickerView(picker, didSelectRow:newPickerRow, inComponent:0)
        currentStepperValue = Int(stepper.value)
    }
    
   //MARK: - Support Methods

    @IBAction func cancel()
    {
        newHours = initialhours
        newDecimal = initialdecimal
        
        let _ = navigationController?.popViewController(animated: true)
    }
    
    func save()
    {
        var newValue = Decimal(newDecimal)
        newValue = newValue / 10
        newValue = newValue + Decimal(newHours)
        
        func computeDifference() -> Decimal
        {
            var initialValue = Decimal(initialdecimal)
            initialValue = initialValue / 10
            initialValue = initialValue + Decimal(initialhours)
            return newValue - initialValue
        }
        
        switch mode
        {
        case .tni:
            let difference = computeDifference()
            let formerTTNI = aircraftBeingEdited.TTNI
            let newTTNI = formerTTNI + difference
            aircraftBeingEdited.TTNI = newTTNI

        case .ttsn:
            let difference = computeDifference()
            var timesheet: AircraftTimesheet
            if aircraftBeingEdited.currentTimesheet == nil
            {
                dataModel.setCurrentTimesheetForAircraft(aircraftBeingEdited, possibleContext:nil)
                timesheet = aircraftBeingEdited.currentTimesheet!
            }
            
            else
            {
                timesheet = aircraftBeingEdited.currentTimesheet!
            }
            
            if timesheet.date.isDateInToday == true
            {
                if aircraftBeingEdited.type == .winch
                {
                    timesheet.TTSNfinal = newValue
                    timesheet.winchFinalTTSNsetCorrectly = true
                }
                    
                else
                {
                    let newInitialTTSN = timesheet.TTSNinitial + difference
                    timesheet.TTSNinitial = newInitialTTSN
                    aircraftBeingEdited.updateTTSN()
                }
            }
            
            else
            {
                if aircraftBeingEdited.type == .winch
                {
                    let difference = computeDifference()
                    let newfinalTTSN = timesheet.TTSNfinal + difference
                    timesheet.TTSNfinal = newfinalTTSN
                }
                
                else
                {
                    let newInitialTTSN = timesheet.TTSNinitial + difference
                    timesheet.TTSNinitial = newInitialTTSN
                    aircraftBeingEdited.updateTTSN()
                }

            }
            
        case .initialTTSN:
            let difference = computeDifference()
            let newInitialTTSN = timesheetBeingEdited.TTSNinitial + difference
            timesheetBeingEdited.TTSNinitial = newInitialTTSN
            aircraftBeingEdited.updateTTSN()
            
            if timesheetBeingEdited.aircraft.type > .winch
            {
                timesheetBeingEdited.updateTTSN()
            }
            
            else
            {
                let newFinalTTSN = timesheetBeingEdited.TTSNfinal + difference
                timesheetBeingEdited.TTSNfinal = newFinalTTSN
            }

        case .finalTTSN:
            let difference = computeDifference()
            let newfinalTTSN = timesheetBeingEdited.TTSNfinal + difference
            timesheetBeingEdited.TTSNfinal = newfinalTTSN
            
            if timesheetBeingEdited.aircraft.type > .winch
            {
                aircraftBeingEdited.updateTTSN()
            }

        case .ttni:
            aircraftBeingEdited.TTNI = newValue
        }
        
        dataModel.saveContext()
        NotificationCenter.default.post(name: aircraftChangedNotification, object:aircraftBeingEdited, userInfo:nil)
        let _ = navigationController?.popViewController(animated: true)
    }
}
