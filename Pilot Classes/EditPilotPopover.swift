//
//  EditPilotPopover.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-27.
//
//

import Foundation
import UIKit
import CoreData

final class EditPilotPopover : UITableViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate, ChangeSignificantDateDelegate
{
    @IBOutlet var arrivalTime: UITableViewCell?
    @IBOutlet var pilotName: UITextField!
    @IBOutlet var pilotFirstName: UITextField!
    @IBOutlet var email: UITextField?
    @IBOutlet var phone: UITextField?
    @IBOutlet var address: UITextField?
    @IBOutlet var city: UITextField?
    @IBOutlet var birthday: UITableViewCell?
    @IBOutlet var employment: UITableViewCell?
    @IBOutlet var RGSunit: UITableViewCell?
    @IBOutlet var highestGliderQual: UITableViewCell?
    @IBOutlet var gliderAPC: UITableViewCell?
    @IBOutlet var checkDuplicates: UITableViewCell?
    @IBOutlet var towAPC: UITableViewCell?
    @IBOutlet var gliderLicense: UITextField?
    @IBOutlet var medicalExpiryDate: UILabel?
    @IBOutlet var glidingCentreName: UILabel?
    @IBOutlet var birthdayDate: UILabel?
    @IBOutlet var gliderAPCdate: UILabel?
    @IBOutlet var towAPCdate: UILabel?
    @IBOutlet var FIexpiryDate: UILabel?
    @IBOutlet var medicalInstructions: UILabel?
    @IBOutlet var arrivalTimeLabel: UILabel?
    @IBOutlet var glidingCentreImage: UIImageView?
    @IBOutlet var powerLicense: UITextField?
    @IBOutlet var FIexpiry: UITableViewCell?
    @IBOutlet var qualifications: UITableViewCell?
    @IBOutlet var highestTowQual: UITableViewCell?
    @IBOutlet var aviationMedical: UITableViewCell?
    @IBOutlet var squadron: UITextField?
    @IBOutlet var level: UISegmentedControl?
    @IBOutlet var gliderLicenseImage: UIButton?
    @IBOutlet var powerLicenseImage: UIButton?
    @IBOutlet var medicalLicenseImage: UIButton?
    @IBOutlet var photo: UIButton?
    
    var pilot: Pilot!
    var gliderQual: GliderQuals!
    var towQual: TowplaneQuals!
    var creatingNewPilot = false
    var customDatePicker: ChangeSignificantDate?
    var record: AttendanceRecord?
    var changesMade = false

    let gliderQualTitles = ["Level 4+ Cadet", "Level 3 Cadet", "Level 2 Cadet", "Level 1 Cadet", "None", "Student", "Basic Glider Pilot", "Front Seat Famil", "Rear seat Famil", "Glider Instructor", "Glider Check Pilot", "Glider Standards Pilot"]

    let towplaneQualTitles = ["None", "Tow Pilot", "Tow Check Pilot", "Tow Standards Pilot"]
    
    enum SegueIdentifiers: String
    {
        case EmploymentSegue = "EmploymentSegue"
        case GlidingCentreSegue = "GlidingCentreSegue"
        case SummerUnitSegue = "SummerUnitSegue"
        case QualificationsSegue = "QualificationsSegue"
        case GliderQualSegue = "GliderQualSegue"
        case TowQualSegue = "TowQualSegue"
        case FlyingRecordsSegue = "FlyingRecordsSegue"
        case AttendanceRecordSegue = "AttendanceRecordSegue"
        case ShowGliderLicenseSegue = "ShowGliderLicenseSegue"
        case ShowPowerLicenseSegue = "ShowPowerLicenseSegue"
        case ShowPilotPhotoSegue = "ShowPilotPhotoSegue"
        case MedicalSegue = "MedicalSegue"
    }
    
    func dateChanged()
    {
        viewWillAppear(false)
    }
    
    //MARK: - UIViewController Methods
    override func viewDidLoad()
    {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.saveIfAppropriate), name: pilotBeingEditedNotification, object: nil)
        
        if pilot.name == ""
        {
            creatingNewPilot = true
        }
    }
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool
    {
        return false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        if !regularFormat
        {
            addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "done")
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if creatingNewPilot
        {
            navigationController?.popoverPresentationController?.delegate = self
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}

        switch segueIdentifer
        {
        case .EmploymentSegue:
            let changeEmployment = segue.destination as? ChangeEmplymentType
            changeEmployment?.pilot = pilot

        case .GlidingCentreSegue:
            let changeGC = segue.destination as? ChangeGlidingCentreForPilot
            changeGC?.pilot = pilot
            
        case .SummerUnitSegue:
            let changeFlight = segue.destination as? ChangeRGSflight
            changeFlight?.pilot = pilot
            
        case .QualificationsSegue:
            let changeQuals = segue.destination as? PilotQualifications
            changeQuals?.pilot = pilot
            
        case .GliderQualSegue:
            let changeQuals = segue.destination as? ChangeGliderQual
            changeQuals?.pilot = pilot
            
        case .TowQualSegue:
            let changeQuals = segue.destination as? ChangeTowQual
            changeQuals?.pilot = pilot
            
        case .FlyingRecordsSegue:
            let records = segue.destination as? FlyingRecords
            records?.pilot = pilot
            
        case .AttendanceRecordSegue:
            let records = segue.destination as? ListAttendanceRecords
            records?.pilot = pilot
            
        case .ShowGliderLicenseSegue:
            let photoController = segue.destination as? ShowPhotoViewController
            photoController?.pilot = pilot
            photoController?.title = "Glider License"
            photoController?.photoType = .gliderLicense
            
        case .ShowPowerLicenseSegue:
            let photoController = segue.destination as? ShowPhotoViewController
            photoController?.pilot = pilot
            photoController?.title = "Power License"
            photoController?.photoType = .powerLicense
            
        case .ShowPilotPhotoSegue:
            let photoController = segue.destination as? ShowPhotoViewController
            photoController?.pilot = pilot
            photoController?.title = "Photo"
            photoController?.photoType = .pilotPhoto
            
        case .MedicalSegue:
            let photoController = segue.destination as? ShowPhotoViewController
            photoController?.pilot = pilot
            photoController?.title = "Medical"
            photoController?.photoType = .medical
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "done")

        title = pilot.name
        if title == ""
        {
            title = "New Pilot"
        }
        
        if pilot.attendanceRecords.count == 0
        {
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(EditPilotPopover.cancel))
            navigationItem.leftBarButtonItem = cancelButton
        }
        
        let attendanceRecords = pilot.attendanceRecords.sorted(by: {$0.timeIn > $1.timeIn})
        record = attendanceRecords.first

        if let firstRecord = record
        {
            let timeIn = firstRecord.timeIn
            arrivalTimeLabel?.text = timeIn.hoursAndMinutes
            
            if !timeIn.isDateInToday
            {
                arrivalTimeLabel?.text = "Not Signed In"
            }
        }
        
        pilotName.text = pilot.name
        pilotFirstName.text = pilot.firstName
        email?.text = pilot.email
        phone?.text = pilot.phone
        address?.text = pilot.address
        city?.text = pilot.city
        
        squadron?.text = String(pilot.squadron)
        
        birthdayDate?.text = pilot.birthday.militaryFormatLong
        gliderAPCdate?.text = pilot.aniversaryOfGliderAPC.militaryFormatLong
        towAPCdate?.text = pilot.aniversaryOfTowAPC.militaryFormatLong
        employment?.detailTextLabel?.text = pilot.typeOfParticipant
        glidingCentreName?.text = pilot.glidingCentre.name
        
        if let gcName = pilot.glidingCentre?.name, gcName != ""
        {
            glidingCentreImage?.image = UIImage(named: gcName)
            glidingCentreImage?.isHidden = false
        }
        
        RGSunit?.detailTextLabel?.text = pilot.summerUnit?.name
        
        var highestQual = gliderQualTitles[Int((pilot.highestGliderQual))+4]
        highestGliderQual?.detailTextLabel?.text = highestQual
        
        if pilot.highestGliderQual < 0
        {
            let levelInt = Int(pilot.highestGliderQual)
            level?.selectedSegmentIndex = -levelInt - 1
        }
        
        highestQual = towplaneQualTitles[Int(pilot.highestScoutQual)]
        highestTowQual?.detailTextLabel?.text = highestQual
        
        gliderLicense?.text = pilot.gliderLicense
        powerLicense?.text = pilot.powerLicense
        
        if pilot.fiExpiry > oneHundredYearsAgo
        {
            FIexpiryDate?.text = pilot.fiExpiry.militaryFormatLong
            
            if pilot.fiExpiry.timeIntervalSinceNow < 0
            {
                FIexpiryDate?.textColor = UIColor.red
            }
                
            else
            {
                let sixMonths = Double(6*30*24*60*60)
                FIexpiryDate?.textColor = (pilot.fiExpiry.timeIntervalSinceNow < sixMonths) ? UIColor.orange : UIColor.black
            }
        }
            
        else
        {
            FIexpiryDate?.text = ""
        }
        
        let numberOfQuals = pilot.qualifications.count 
        
        switch numberOfQuals
        {
        case 0:
            qualifications?.textLabel?.text = "No Other Quals"

        case 1:
            qualifications?.textLabel?.text = pilot.qualifications.first?.nameOfQualification

        case 2:
            var qualString = pilot.qualifications.first?.nameOfQualification ?? ""
            qualString += ", and one more..."
            qualifications?.textLabel?.text = qualString

        case let number where number > 2:
            var qualString = pilot.qualifications.first?.nameOfQualification ?? ""
            qualString += ", and \(numberOfQuals - 1) more..."
            qualifications?.textLabel?.text = qualString
            
        default:
            break
        }
        
        if pilot.medical > oneHundredYearsAgo
        {
            let powerMedicalExpiry = pilot.powerMedicalExpiryDate
            
            if powerMedicalExpiry != pilot.medical
            {
                medicalExpiryDate?.text = "\(pilot.medical.militaryFormatShort) (\(powerMedicalExpiry.militaryFormatShort) for power)"
            }
                
            else
            {
                medicalExpiryDate?.text = pilot.medical.militaryFormatShort
            }
            
            
            if powerMedicalExpiry.timeIntervalSinceNow < 0
            {
                medicalExpiryDate?.textColor = UIColor.red
            }
                
            else
            {
                let sixMonths = Double(6*30*24*60*60)
                medicalExpiryDate?.textColor = (powerMedicalExpiry.timeIntervalSinceNow < sixMonths) ? UIColor.orange : UIColor.black
            }
        }
            
        else
        {
            medicalExpiryDate?.text = ""
        }
        
        if let photoThumbnailImage = pilot.photoThumbnailImage as? UIImage
        {
            photo?.setImage(photoThumbnailImage, for: UIControl.State())
        }
            
        else
        {
            photo?.setImage(nil, for: UIControl.State())
        }
        
        if let gliderThumbnailImage = pilot.gliderThumbnailImage as? UIImage
        {
            let size = gliderThumbnailImage.size
            let ratio = (size.width > size.height) ? (44.0 / size.width) : (44.0 / size.height)
            let rect = CGRect(x: 0.0, y: 0.0, width: ratio * size.width, height: ratio * size.height)
            gliderLicenseImage?.bounds = rect
            gliderLicenseImage?.setImage(gliderThumbnailImage, for: UIControl.State())
        }
            
        else
        {
            gliderLicenseImage?.setImage(nil, for: UIControl.State())
        }
        
        if let powerThumbnailImage = pilot.powerThumbnailImage as? UIImage
        {
            let size = powerThumbnailImage.size
            let ratio = (size.width > size.height) ? (44.0 / size.width) : (44.0 / size.height)
            let rect = CGRect(x: 0.0, y: 0.0, width: ratio * size.width, height: ratio * size.height)
            powerLicenseImage?.bounds = rect
            powerLicenseImage?.setImage(powerThumbnailImage, for: UIControl.State())
        }
            
        else
        {
            powerLicenseImage?.setImage(nil, for: UIControl.State())
        }
        
        if let medicalThumbnailImage = pilot.medicalThumbnailImage as? UIImage
        {
            let size = medicalThumbnailImage.size
            let ratio = (size.width > size.height) ? (44.0 / size.width) : (44.0 / size.height)
            let rect = CGRect(x: 0.0, y: 0.0, width: ratio * size.width, height: ratio * size.height)
            medicalLicenseImage?.bounds = rect
            medicalLicenseImage?.setImage(medicalThumbnailImage, for: UIControl.State())
        }
            
        else
        {
            medicalLicenseImage?.setImage(nil, for: UIControl.State())
        }
    }
    
    deinit
    {
        if pilot.name != "" && changesMade
        {
            dataModel.saveContext()
            let reloadNotification = Notification(name: reloadPilotNotification, object: pilot)
            NotificationQueue.default.enqueue(reloadNotification, postingStyle: .whenIdle, coalesceMask: [.onSender], forModes: nil)
        }
    }
    
    @objc func saveIfAppropriate()
    {
        changesMade = true
        NotificationCenter.default.post(name: reloadPilotNotification, object: pilot)
    }
    
    //MARK: - UITableView Methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cell = tableView.cellForRow(at: indexPath)
        
        if (cell === arrivalTime && arrivalTimeLabel?.text != "Not Signed In") || cell === birthday || cell === gliderAPC || cell === towAPC || cell === aviationMedical || cell === FIexpiry
        {
            if customDatePicker == nil
            {
                addPickerToCell(cell)
            }
                
            else
            {
                let previouslySelectedCell = customDatePicker!.tableViewCell as! TableViewCellStylePicker
                customDatePicker = nil
                previouslySelectedCell.removePickerFromStackView()
                medicalInstructions?.isHidden = true
                
                if previouslySelectedCell !== cell
                {
                    addPickerToCell(cell)
                }
            }
        }
        
        if cell == checkDuplicates
        {
            checkForDuplicates()
        }
        
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func addPickerToCell(_ cell: UITableViewCell?)
    {
        if cell == nil
        {
            return
        }
        
        switch cell
        {
        case let cellValue where cellValue == birthday:
            customDatePicker =  ChangeSignificantDate(mode: SignificantDateMode.birthday, pilotBeingEdited: pilot)
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!)
        
        case let cellValue where cellValue == gliderAPC:
            customDatePicker =  ChangeSignificantDate(mode: SignificantDateMode.gliderAPC, pilotBeingEdited: pilot)
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!)
        
        case let cellValue where cellValue == towAPC:
            customDatePicker =  ChangeSignificantDate(mode: SignificantDateMode.towAPC, pilotBeingEdited: pilot)
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!)
        
        case let cellValue where cellValue == FIexpiry:
            customDatePicker =  ChangeSignificantDate(mode: SignificantDateMode.fIexpiry, pilotBeingEdited: pilot)
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!)
        
        case let cellValue where cellValue == aviationMedical:
            customDatePicker =  ChangeSignificantDate(mode: SignificantDateMode.medicalExpiry, pilotBeingEdited: pilot)
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!, atPosition: 1)
            medicalInstructions?.isHidden = false
        
        case let cellValue where cellValue == arrivalTime:
            customDatePicker =  ChangeArrivalTime(record: record!, delegate: nil)
            (cell as? TableViewCellStylePicker)?.addPickerToStackView(customDatePicker!)
            
        default:
            break
        }
 
        customDatePicker?.delegate = self
    }
    
    //MARK: - UITextFieldDelegate Methods
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        let blankField = UITextField()
        switch textField
        {
        case pilotName, pilotFirstName:
            let nameNoWhite = (textField.text ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let nameNoNumbers = nameNoWhite.trimmingCharacters(in: CharacterSet.decimalDigits)
            let nameNoSymbols = nameNoNumbers.trimmingCharacters(in: CharacterSet.symbols)
            textField.text = nameNoSymbols
            
            if nameNoSymbols != ""
            {
                if textField == pilotName
                {
                    pilot.name = textField.text ?? ""
                    let _ = pilot.nameIsUnique
                    title = pilot.name
                }
                    
                else
                {
                    pilot.firstName = textField.text ?? ""
                }
                
                pilot.fullName = pilot.name + ", " + pilot.firstName
                
                dataModel.saveContext()
                NotificationCenter.default.post(name: nameChangedNotification, object: pilot, userInfo: nil)
            }
                
            else
            {
                let invalidNameAlert = UIAlertController(title: "Invalid Name", message: "A name must contain at least one letter of the alphabet.", preferredStyle: .alert)
                let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
                invalidNameAlert.addAction(cancelButton)
                present(invalidNameAlert, animated:true, completion:nil)
            }
            
        case email ?? blankField:
            if stringIsValidEmail(textField.text ?? "")
            {
                pilot.email = textField.text ?? ""
            }
                
            else
            {
                let invalidEmailAlert = UIAlertController(title: "Invalid e-mail", message: "e-mail addresses must be of the format someone@myCompany.com", preferredStyle: .alert)
                let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
                invalidEmailAlert.addAction(cancelButton)
                present(invalidEmailAlert, animated:true, completion:nil)
            }

        case phone ?? blankField:
            let set = CharacterSet.decimalDigits.inverted
            let numbersOnly = textField.text!.components(separatedBy: set).reduce("", +)
            
            if numbersOnly.count == 10
            {
                var formattedNumber = numbersOnly
                formattedNumber = "(" + formattedNumber
                var areaCode = String(formattedNumber.prefix(4))
                areaCode += ") "
                areaCode += String(formattedNumber.suffix(formattedNumber.count - 4))
                formattedNumber = areaCode
                formattedNumber.insert("-", at: formattedNumber.index(formattedNumber.startIndex, offsetBy: 9))
                
                textField.text = formattedNumber
                pilot.phone = formattedNumber
            }
                
                
            else
            {
                textField.text = ""
                
                let invalidPhoneNumberAlert = UIAlertController(title: "Invalid Number", message: "Phone numbers must contain ten digits. Formatting is done automatically.", preferredStyle: .alert)
                let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
                invalidPhoneNumberAlert.addAction(cancelButton)
                present(invalidPhoneNumberAlert, animated:true, completion:nil)
            }

        case address ?? blankField:
            pilot.address = textField.text ?? ""
            
        case city ?? blankField:
            pilot.city = textField.text ?? ""
            
        case gliderLicense ?? blankField:
            pilot.gliderLicense = textField.text ?? ""
            
        case powerLicense ?? blankField:
            pilot.powerLicense = textField.text ?? ""
            
        case squadron ?? blankField:
            let set = CharacterSet.decimalDigits.inverted
            let numbersOnly = textField.text!.components(separatedBy: set).reduce("", +)
            pilot.squadron = Int16(numbersOnly) ?? 0 as Int16
            
        default:
            break
        }
        
        saveIfAppropriate()
        dataModel.aircraftAreaController?.becomeFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.endEditing(false)
        return false
    }
    
    //MARK: - Accessory Methods

    @IBAction func changeLevel()
    {
        var newLevel = level?.selectedSegmentIndex ?? 0
        newLevel += 1
        newLevel *= -1
        pilot.highestGliderQual = Int16(newLevel)
        dataModel.saveContext()
        NotificationQueue.default.enqueue(Notification(name: highestQualChangedNotification, object:nil), postingStyle: .whenIdle)
    }
    
    @objc @IBAction func done()
    {
        pilotName.resignFirstResponder()
        pilotFirstName.resignFirstResponder()
        navigationController?.popoverPresentationController?.delegate = nil

        let _ = pilot.nameIsUnique
        
        if pilot.name == ""
        {
            let invalidNameAlert = UIAlertController(title: "Name not Set", message: "You must give the new pilot a name.", preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
            invalidNameAlert.addAction(cancelButton)
            present(invalidNameAlert, animated:true, completion:nil)
            return
        }
        
        let pilotRequest = Pilot.request
        pilotRequest.predicate = NSPredicate(format: "fullName == %@ AND birthday == %@", argumentArray: [pilot.fullName, pilot.birthday])
        let pilotsFound = try! dataModel.managedObjectContext.fetch(pilotRequest) 
        
        var shouldPopController = false
        
        if pilotsFound.count > 1
        {
            var oldPilot: Pilot!
            for pilotToCheck in pilotsFound
            {
                if pilotToCheck !== pilot
                {
                    oldPilot = pilotToCheck
                    break
                }
            }
            
            if oldPilot.inactive == true
            {
                oldPilot.inactive = false
                pilot.managedObjectContext?.delete(pilot)
                dataModel.createAttendanceRecordForPerson(oldPilot)
                dataModel.saveContext()
                shouldPopController = true
            }
                
            else
            {
                let invalidNameAlert = UIAlertController(title: "Name in Use", message: "There is already a pilot with the same name and birthday. Use the 'Show Archived Pilots feature if this pilot is not visible in the pilot list.", preferredStyle: .alert)
                let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
                invalidNameAlert.addAction(cancelButton)
                present(invalidNameAlert, animated:true, completion:nil)
            }
        }
            
        else
        {
            dataModel.createAttendanceRecordForPerson(pilot)
            dataModel.saveContext()
            shouldPopController = true
        }
        
        if shouldPopController
        {
            if navigationController?.viewControllers.count == 1
            {
                presentingViewController?.dismiss(animated: true, completion:nil)
            }
                
            else
            {
                let _ = navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func checkForDuplicates()
    {
        let pilotRequest = Pilot.request
        pilotRequest.predicate = NSPredicate(format: "fullName == %@", argumentArray: [pilot.fullName])
        let pilotsFound = try! dataModel.managedObjectContext.fetch(pilotRequest) 
        var foundPilotSet = Set(pilotsFound)
        
        var allSignedOut = true
        var pilotsWithDifferentBirthdate = Set<Pilot>()
        
        for somePilot in foundPilotSet
        {
            if somePilot.signedIn == true
            {
                allSignedOut = false
            }
            
            if somePilot.birthday.startOfDay != pilot.birthday.startOfDay
            {
                pilotsWithDifferentBirthdate.insert(somePilot)
            }
        }
        
        foundPilotSet = foundPilotSet.subtracting(pilotsWithDifferentBirthdate)
        
        if allSignedOut == false
        {
            let signedInAlert = UIAlertController(title: "Unable to Proceed", message: "Cannot check for duplicates while this pilot or others with the same name are signed in.", preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
            signedInAlert.addAction(cancelButton)
            present(signedInAlert, animated:true, completion:nil)
            return
        }
        
        foundPilotSet.remove(pilot)
        
        if foundPilotSet.count == 0
        {
            let noDplicatesAlert = UIAlertController(title: "None Found", message: "No pilots were found with the same names and birthdate as \(pilot.fullName)", preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "OK", style: .default, handler:nil)
            noDplicatesAlert.addAction(cancelButton)
            present(noDplicatesAlert, animated:true, completion:nil)
        }
        
        else
        {
            var message = "\(foundPilotSet.count) pilot"
            if foundPilotSet.count > 1
            {
                message += "s"
            }
            
            message += " found with the same names and birthdate as \(pilot.fullName). They have been merged together."
            
            let duplicatesAlert = UIAlertController(title: "Duplicates Found", message: message, preferredStyle: .alert)
            let cancelButton = UIAlertAction(title: "OK", style: .default){_ in
                self.presentingViewController?.dismiss(animated: true, completion:nil)
                dataModel.saveContext()
            }
            duplicatesAlert.addAction(cancelButton)
            present(duplicatesAlert, animated:true, completion:nil)

            for otherPilot in foundPilotSet
            {
                let (mostRecentlyUpdatedPilotInfo, olderPilotInfo) = newerAndOlderRecord(otherPilot, secondRecord: pilot!)
                mostRecentlyUpdatedPilotInfo.mergeWithPilot(olderPilotInfo)
            }
        }
    }
    
    @objc func cancel()
    {
        navigationController?.popoverPresentationController?.delegate = nil
        pilotName.text = ""
        pilotFirstName.text = ""
        dataModel.managedObjectContext.delete(pilot)
        let _ = navigationController?.popViewController(animated: true)
    }
}
