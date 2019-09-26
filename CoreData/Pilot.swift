//
//  Pilot.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-23.
//
//

import Foundation
import UIKit
import CoreData

final class Pilot: NSManagedObject, NSFetchedResultsControllerDelegate, RecordsChanges, HasID, AttachedToGlidingUnit, AttachedToSummerUnit
{
    @NSManaged var address: String
    @NSManaged var aniversaryOfGliderAPC: Date
    @NSManaged var aniversaryOfTowAPC: Date
    @NSManaged var birthday: Date
    @NSManaged var city: String
    @NSManaged var dateOfBasicGliderPilot: Date
    @NSManaged var dateOfFrontSeatFamilPilot: Date
    @NSManaged var dateOfGliderCheckPilot: Date
    @NSManaged var dateOfGliderInstructorPilot: Date
    @NSManaged var dateOfGliderPilotXCountry: Date
    @NSManaged var dateOfGliderStandardsPilot: Date
    @NSManaged var dateOfLaunchControlOfficer: Date
    @NSManaged var dateOfRearSeatFamilPilot: Date
    @NSManaged var dateOfTowCheckPilot: Date
    @NSManaged var dateOfTowPilot: Date
    @NSManaged var dateOfTowPilotXCountry: Date
    @NSManaged var dateOfTowStandardsPilot: Date
    @NSManaged var dateOfWinchLaunchInstructor: Date
    @NSManaged var dateOfWinchLaunchOperator: Date
    @NSManaged var dateOfWinchLaunchPilot: Date
    @NSManaged var dateOfWinchRetrieveDriver: Date
    @NSManaged var email: String
    @NSManaged var fiExpiry: Date
    @NSManaged var firstName: String
    @NSManaged var fullName: String
    @NSManaged var gliderLicense: String
    @NSManaged var gliderThumbnailImage: AnyObject?
    @NSManaged var highestGliderQual: Int16
    @NSManaged var highestScoutQual: Int16
    @NSManaged var inactive: Bool
    @NSManaged var medical: Date
    @NSManaged var medicalThumbnailImage: AnyObject?
    @NSManaged var name: String
//    @NSManaged var modifiedBy: String!
    @NSManaged var phone: String
    @NSManaged var photoThumbnailImage: AnyObject?
    @NSManaged var powerLicense: String
    @NSManaged var powerThumbnailImage: AnyObject?
    @NSManaged var recordChangeTime: Date
    @NSManaged var recordID: Date     /// Should always be the current date at the time of insertion and should never be changed. Defaults to 2000
    @NSManaged var signedIn: Bool
    @NSManaged var squadron: Int16
//    @NSManaged var timeDown: Date?
//    @NSManaged var timeIn: Date?
    @NSManaged var typeOfParticipant: String
    @NSManaged var gliderFlightsAdjustment: Int64
    @NSManaged var gliderInstHoursAdjust: Int64
    @NSManaged var gliderPIChoursAdjust: Int64
    @NSManaged var powerHoursAdjust: Int64

    @NSManaged var picAircraft: Timesheets.AircraftEntity?
    @NSManaged var dualAircraft: Timesheets.AircraftEntity?
    
    @NSManaged var attendanceRecords: Set<AttendanceRecord>
    @NSManaged var dualFlights: Set<FlightRecord>
    @NSManaged var gliderLicenseImage: Timesheets.GliderLicenseImage?
    @NSManaged var glidingCentre: Timesheets.GlidingCentre!
    @NSManaged var medicalImage: Timesheets.MedicalImage?
    @NSManaged var photo: Timesheets.Photo?
    @NSManaged var picFlights: Set<FlightRecord>
    @NSManaged var powerLicenseImage: Timesheets.PowerLicenseImage?
    @NSManaged var qualifications: Set<Qualification>
    @NSManaged var summerUnit: Timesheets.SummerUnit?
    
    var PICflightsFetchController: NSFetchedResultsController<FlightRecord>?
    var dualFlightsFetchController: NSFetchedResultsController<FlightRecord>?
    var PICflightsOnTargetDateFetchController: NSFetchedResultsController<FlightRecord>?
    var dualFlightsOnTargetDateFetchController: NSFetchedResultsController<FlightRecord>?
    var PICtargetDate = Date.distantPast
    var dualTargetDate = Date.distantPast
    
    class var request: NSFetchRequest<Pilot>
    {
        return self.fetchRequest() as! NSFetchRequest<Pilot>
    }
    
    var aircraft: Timesheets.AircraftEntity?
    {
        get
        {
            if picAircraft != nil
            {
                return picAircraft
            }
            
            else
            {
                return dualAircraft
            }
        }
    }
    
    //FIXME: This shouldn't need to exist post objc
    class func changeShouldUpdateChangeTimesToValue(_ value: Bool)
    {
        shouldUpdateChangeTimes = value
    }
    
    //MARK: - Computed Properties

    override var description: String
    {
        return  """
                recordID: \(recordID)
                  recordChangeTime: \(recordChangeTime)
                  pilotName: \(uniqueName)
                """
    }
    
    override var debugDescription: String
    {
        return description
    }
    
    var sortedPICflights: [FlightRecord]
    {
        if PICflightsFetchController == nil
        {
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "pilot == %@", self)
            let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
            request.sortDescriptors = [timeUpSortDescriptor]
            PICflightsFetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
            PICflightsFetchController?.delegate = self
            try! PICflightsFetchController!.performFetch()
        }
        
        return PICflightsFetchController!.fetchedObjects!
    }

    func sortedPICflightsForDate(_ date: Date) -> [FlightRecord]
    {
        if (PICflightsOnTargetDateFetchController == nil) || (PICtargetDate != date)
        {
            let oneDayLater = date + 60*60*24
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND pilot == %@", argumentArray: [date, oneDayLater, self])
            let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
            request.sortDescriptors = [timeUpSortDescriptor]
            PICflightsOnTargetDateFetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
            PICflightsOnTargetDateFetchController?.delegate = self
            try! PICflightsOnTargetDateFetchController!.performFetch()
            PICtargetDate = date
        }
        
        return PICflightsOnTargetDateFetchController!.fetchedObjects!
    }
    
    var sortedDualFlights: [FlightRecord]
    {
        if dualFlightsFetchController == nil
        {
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "passenger == %@", self)
            let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
            request.sortDescriptors = [timeUpSortDescriptor]
            dualFlightsFetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
            dualFlightsFetchController?.delegate = self
            try! dualFlightsFetchController!.performFetch()
        }
        
        return dualFlightsFetchController!.fetchedObjects!
    }
    
    func sortedDualFlightsForDate(_ date: Date) -> [FlightRecord]
    {
        if (dualFlightsOnTargetDateFetchController == nil) || (dualTargetDate != date)
        {
            let oneDayLater = date + 60*60*24
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND passenger == %@", argumentArray: [date, oneDayLater, self])
            let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
            request.sortDescriptors = [timeUpSortDescriptor]
            dualFlightsOnTargetDateFetchController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
            dualFlightsOnTargetDateFetchController?.delegate = self
            try! dualFlightsOnTargetDateFetchController!.performFetch()
            dualTargetDate = date
        }
        
        return dualFlightsOnTargetDateFetchController!.fetchedObjects!
    }
    
    var uniqueName: String
    {
        if fullName == ""
        {
            if firstName != ""
            {
                fullName = "\(name), \(firstName)"
            }
        
            else
            {
                fullName = name
            }
        }

        return nameIsUnique ? name : fullName
    }
    
    var nameIsUnique:Bool {return determineUniquenessOfName()}
    
    var _allTimeStatsCache: PilotFlyingStats?
    var allTimeStatsCache: PilotFlyingStats
        {
            get
            {
                if _allTimeStatsCache == nil
                {
                    _allTimeStatsCache = flyingStatsFromDate(Date.distantPast, toDate: Date.distantFuture)
                }
                return _allTimeStatsCache!
            }
        }
    
    var _thisYearStatsCache: PilotFlyingStats?
    var thisYearStatsCache: PilotFlyingStats
        {
            get
            {
                if _thisYearStatsCache == nil
                {
                    _thisYearStatsCache = flyingStatsFromDate(Date() + (-365*24*60*60), toDate: Date.distantFuture)
                }
                return _thisYearStatsCache!
            }
        
            set
            {
                _thisYearStatsCache = nil
            }
        }
    
    var gliderQual: GliderQuals
    {
        return GliderQuals(rawValue: Int(highestGliderQual))!
    }
    
    var towQual: TowplaneQuals
    {
        return TowplaneQuals(rawValue: Int(highestScoutQual))!
    }
    
    var ageOutDate: Date
    {
        let gregorian = Calendar(identifier: Calendar.Identifier.gregorian)
        let comps = DateComponents(year: 19)
        let ageOutDate = gregorian.date(byAdding: comps, to: birthday)!
        return ageOutDate
    }
    
    var powerMedicalExpiryDate: Date
    {
        let gregorian = Calendar(identifier: Calendar.Identifier.gregorian)
        var comps = DateComponents(year: -5)
        let medicalStartDate = gregorian.date(byAdding: comps, to: medical)!
        comps.year = 40
        let fourtiethBirthday = gregorian.date(byAdding: comps, to: birthday)!
        
        var returnDate = medical
        if fourtiethBirthday < medicalStartDate
        {
            comps.year = -3
            returnDate = gregorian.date(byAdding: comps, to: medical)!
        }
        
        return returnDate
    }
    
    var typeOfParticipantStringWithSquadronForCadets: String
    {
        if typeOfParticipant == "Staff Cadet"
        {
            let squadron = String(Int(self.squadron))
            return "\(typeOfParticipant) (\(squadron) Squadron)"
        }
        
        else
        {
            return typeOfParticipant
        }
    }
    
    lazy var largePilotPhotoThumbnail: UIImage? =
    {
        let workingImage = self.photo?.value(forKey: "image") as? UIImage
        
        guard let image = workingImage else {return nil}
        
        let size = image.size
        var ratio: CGFloat = 0
        ratio = (size.width > size.height) ? (88.0 / size.width) : (88.0 / size.height)
        let rect = CGRect(x: 0.0, y: 0.0, width: ratio * size.width, height: ratio * size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 2.0)
        
        image.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }()
    
    //MARK: - Other Methods

    func determineUniquenessOfName() -> Bool
    {
        var unique: Bool
        
        if (gliderQual > .noGlider) || (towQual > TowplaneQuals.noScout)
        {
            let request = Pilot.request
            request.predicate = NSPredicate(format: "name == %@ AND (highestGliderQual > %d OR highestScoutQual > %d) AND inactive == NO", name , 0, 0)
            let pilotsWithSameLastName = try! managedObjectContext!.fetch(request)
            unique = pilotsWithSameLastName.count > 1 ? false : true
        }
        
        else
        {
            unique = false
        }
        
        return unique
    }
    
    func clearRelationships()
    {
        picAircraft = nil
        dualAircraft = nil
        glidingCentre = nil
        summerUnit = nil
        name = ""
        fullName = ""
        inactive = true
        
        for record in attendanceRecords
        {
            cloudKitController?.deleteAttendanceRecord(record)
            self.managedObjectContext?.delete(record)
        }
    }
    
    func checkConsistencyBasedOnChangesToRecord(_ record: FlightRecord)
    {
        let request = FlightRecord.request
        request.predicate = NSPredicate(format: "(pilot == %@ OR passenger = %@) AND timeDown > %@ AND timeUp < %@ AND recordID != %@", argumentArray: [self, self, record.timeUp, record.timeDown, record.recordID])
        
        guard let numberOfConflicts = try! managedObjectContext?.count(for: request) else {return}
        if numberOfConflicts > 0
        {
            let errorText = "There is a conflict- \(fullName) is now recorded as doing two flights at once!"
            let alert = UIAlertController(title: "Warning", message: errorText, preferredStyle: .alert)
            let cancel = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(cancel)
            UIViewController.presentOnTopmostViewController(alert)
        }
    }

    func flyingStatsFromDate(_ startDate: Date, toDate endDate: Date) -> PilotFlyingStats
    {
        let request = FlightRecord.request
        request.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND (pilot == %@ OR passenger == %@)", argumentArray: [startDate, endDate, self, self])
        let allFlights = try! managedObjectContext!.fetch(request) 

        var stats = PilotFlyingStats()
        
        for record in allFlights
        {
            let type = record.timesheet?.aircraft.type ?? VehicleType.auto
            switch type
            {
            case .glider:
                stats.gliderFlights += 1
                if record.pilot === self
                {
                    if (record.flightSequence == "Famil") || (record.passenger == nil)
                    {
                        stats.gliderPICminutes += Int(record.flightLengthInMinutes)
                    }
                
                    else
                    {
                        stats.gliderInstructorMinutes += Int(record.flightLengthInMinutes)
                    }
                }
                
                if record.passenger === self
                {
                    stats.gliderDualMinutes += Int(record.flightLengthInMinutes)
                }
            
            case .towplane:
                if record.pilot === self
                {
                    stats.towPICminutes += Int(record.flightLengthInMinutes)
                
                    if record.flightSequence == "Towing"
                    {
                        stats.towAircraftTows += 1
                    }
                }
            
            case .winch:
                stats.launchesAsWinchOperator += 1
            
            case .auto:
                stats.launchesAsAutoDriver += 1
            }
        }
        
        return stats
    }
    
    func pilotHoldsQual(_ qual: String) -> Bool
    {
        for qualHeld in qualifications
        {
            if qualHeld.nameOfQualification == qual
            {
                return true
            }
        }
        
        return false
    }
    
    func numberOfGliderDualsOnDate(_ date: Date) -> Int
    {
        var numberOfDuals = 0
        
        for record in dualFlights
        {
            let type = record.timesheet?.aircraft.type ?? VehicleType.auto
            if (record.timeUp.midnight == date) && (type == .glider)
            {
                numberOfDuals += 1
            }
        }
        
        return numberOfDuals
    }
    
    func numberOfDaysWorkedAtGC(_ gc: GlidingCentre) -> Double
    {
        let request = AttendanceRecord.request
        request.predicate = NSPredicate(format: "pilot == %@ AND timeIn > %@ AND glidingCentre == %@", argumentArray: [self, Date(timeIntervalSinceNow: -365*24*60*60), gc])
        let currentYearAttendanceRecords = try! managedObjectContext!.fetch(request) 
        
        var numberOfDays = 0.0
        
        for record in currentYearAttendanceRecords
        {
            if record.dayOrSession == true
            {
                numberOfDays += 1
            }
        
            else
            {
                numberOfDays += 0.5
            }
        }
        
        return numberOfDays
    }
    
    func calculateCurrencyDateOnType(_ type: VehicleType, withSortedPICflights flights: [FlightRecord]? = nil, andDualFlights dualFlights: [FlightRecord]? = nil) -> (APCexpiresBeforeCurrency: Bool, canFlyUntilDate: Date)
    {
        var numberOfFlightsPIC = 0
        var dateOfMostRecentPIC = Date.distantPast
        var dateOfFifthMostRecentPIC = Date.distantPast
        var firstDualFound = false
        var dateOfMostRecentDual = Date.distantPast
        var dateOfSecondMostRecentDual = Date.distantPast
        var currencyDate = Date.distantPast
        var dateOfRelevantFlight: Date
        var picFlightsArray = [FlightRecord]()
        var dualFlightsArray = [FlightRecord]()
        
        if let picArray = flights, let dualArray = dualFlights
        {
            picFlightsArray = picArray
            dualFlightsArray = dualArray
        }
            
        else
        {
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "pilot == %@", self)
            let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
            request.sortDescriptors = [timeUpSortDescriptor]
            picFlightsArray = try! managedObjectContext!.fetch(request) 
            request.predicate = NSPredicate(format: "passenger == %@", self)
            dualFlightsArray = try! managedObjectContext!.fetch(request) 
        }
        
        for record in picFlightsArray.reversed()
        {
            if record.timesheet?.aircraft.type != type
            {
                continue
            }
            
            if numberOfFlightsPIC == 0
            {
                dateOfMostRecentPIC = record.timeUp as Date
            }
            
            numberOfFlightsPIC += 1
            
            if numberOfFlightsPIC == 5
            {
                dateOfFifthMostRecentPIC = record.timeUp as Date
                break
            }
        }
        
        for record in dualFlightsArray.reversed()
        {
            if record.timesheet?.aircraft.type != type
            {
                continue
            }
            
            if type == .glider
            {
                if record.pilot.gliderQual < .checkPilot
                {
                    continue
                }
            }
                
            else
            {
                if record.pilot.towQual < .towCheckPilot
                {
                    continue
                }
            }
            
            if firstDualFound == false
            {
                firstDualFound = true
                dateOfMostRecentDual = record.timeUp as Date
            }
                
            else
            {
                dateOfSecondMostRecentDual = record.timeUp as Date
                break
            }
        }
        
        if type == .glider
        {
            switch gliderQual
            {
            case .student:
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfMostRecentDual ? dateOfMostRecentPIC : dateOfMostRecentDual
                let midnight = dateOfRelevantFlight.midnight
                currencyDate = midnight + (5*24*3600 - 1)

            case .basic ... .instructor:
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfSecondMostRecentDual ? dateOfMostRecentPIC : dateOfSecondMostRecentDual
                let midnight = dateOfRelevantFlight.midnight
                currencyDate = midnight + (60*24*3600 - 1)
                
            case .checkPilot:
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfSecondMostRecentDual ? dateOfMostRecentPIC : dateOfSecondMostRecentDual
                var midnight = dateOfRelevantFlight.midnight
                let ACGPcurrency = midnight + (90*24*3600 - 1)
                dateOfRelevantFlight = dateOfFifthMostRecentPIC > dateOfSecondMostRecentDual ? dateOfFifthMostRecentPIC : dateOfSecondMostRecentDual
                midnight = dateOfRelevantFlight.midnight
                let TCcurrency = midnight + (180*24*3600 - 1)
                currencyDate = ACGPcurrency < TCcurrency ? ACGPcurrency : TCcurrency

            case .standardsPilot:
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfSecondMostRecentDual ? dateOfMostRecentPIC : dateOfSecondMostRecentDual
                let midnight = dateOfRelevantFlight.midnight
                currencyDate = midnight + (180*24*3600 - 1)
                
            default:
                break
            }
        }
            
        else
        {
            if towQual == .towPilot
            {
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfMostRecentDual ? dateOfMostRecentPIC : dateOfMostRecentDual
                let midnight = dateOfRelevantFlight.midnight
                currencyDate = midnight + (60*24*3600 - 1)
            }
                
            else
            {
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfMostRecentDual ? dateOfMostRecentPIC : dateOfMostRecentDual
                var midnight = dateOfRelevantFlight.midnight
                let ACGPcurrency = midnight + (90*24*3600 - 1)
                
                dateOfRelevantFlight = dateOfMostRecentPIC > dateOfMostRecentDual ? dateOfMostRecentPIC : dateOfMostRecentDual
                midnight = dateOfRelevantFlight.midnight
                let TCcurrency = midnight + (180*24*3600 - 1)
                currencyDate = ACGPcurrency < TCcurrency ? ACGPcurrency : TCcurrency
            }
        }
        
        var APCdate: Date?
        
        if type == .glider
        {
            APCdate = aniversaryOfGliderAPC
        }
            
        else
        {
            APCdate = aniversaryOfTowAPC
        }
        
        if APCdate == nil
        {
            APCdate = Date.distantPast
        }
        
        let APCexpiryDate = APCdate!.calculateAPCanniversaryFromSelf
        var APCexpiresBeforeCurrency = false
        
        if APCexpiryDate < currencyDate
        {
            APCexpiresBeforeCurrency = true
        }
        
        let canFlyUntilDate = APCexpiryDate < currencyDate ? APCexpiryDate : currencyDate
        
        return (APCexpiresBeforeCurrency, canFlyUntilDate)
    }
    
    /// Updates the receiver with the data supplied by another Pilot object. Merges the relationships only if the receiver and other piot are in the same store.
    ///
    /// - parameter pilotToDelete: The other pilot object. This object will be deleted after this method is called, unless relationshipsIncluded is false.
    /// - parameter relationshipsIncluded: If this is set to false relationships are not included and the other pilot is not deleted.
    func mergeWithPilot(_ pilotToDelete: Pilot, includingRelationships relationshipsIncluded: Bool = true)
    {
        if relationshipsIncluded
        {
            attendanceRecords = attendanceRecords.union(pilotToDelete.attendanceRecords)
            dualFlights = dualFlights.union(pilotToDelete.dualFlights)
            picFlights = picFlights.union(pilotToDelete.picFlights)
            qualifications = qualifications.union(pilotToDelete.qualifications)
            medicalImage = medicalImage ?? pilotToDelete.medicalImage
            photo = photo ?? pilotToDelete.photo
            gliderLicenseImage = gliderLicenseImage ?? pilotToDelete.gliderLicenseImage
            powerLicenseImage = powerLicenseImage ?? pilotToDelete.powerLicenseImage
            managedObjectContext?.delete(pilotToDelete)
        }
        
        medicalThumbnailImage = medicalThumbnailImage ?? pilotToDelete.medicalThumbnailImage
        photoThumbnailImage = photoThumbnailImage ?? pilotToDelete.photoThumbnailImage
        gliderThumbnailImage = gliderThumbnailImage ?? pilotToDelete.gliderThumbnailImage
        powerThumbnailImage = powerThumbnailImage ?? pilotToDelete.powerThumbnailImage
        
        aniversaryOfGliderAPC = aniversaryOfGliderAPC > pilotToDelete.aniversaryOfGliderAPC ? aniversaryOfGliderAPC : pilotToDelete.aniversaryOfGliderAPC
        aniversaryOfTowAPC = aniversaryOfTowAPC > pilotToDelete.aniversaryOfTowAPC ? aniversaryOfTowAPC : pilotToDelete.aniversaryOfTowAPC
        dateOfBasicGliderPilot = dateOfBasicGliderPilot > pilotToDelete.dateOfBasicGliderPilot ? dateOfBasicGliderPilot : pilotToDelete.dateOfBasicGliderPilot
        dateOfFrontSeatFamilPilot = dateOfFrontSeatFamilPilot > pilotToDelete.dateOfFrontSeatFamilPilot ? dateOfFrontSeatFamilPilot : pilotToDelete.dateOfFrontSeatFamilPilot
        dateOfGliderCheckPilot = dateOfGliderCheckPilot > pilotToDelete.dateOfGliderCheckPilot ? dateOfGliderCheckPilot : pilotToDelete.dateOfGliderCheckPilot
        dateOfGliderInstructorPilot = dateOfGliderInstructorPilot > pilotToDelete.dateOfGliderInstructorPilot ? dateOfGliderInstructorPilot : pilotToDelete.dateOfGliderInstructorPilot
        dateOfGliderPilotXCountry = dateOfGliderPilotXCountry > pilotToDelete.dateOfGliderPilotXCountry ? dateOfGliderPilotXCountry : pilotToDelete.dateOfGliderPilotXCountry
        dateOfGliderStandardsPilot = dateOfGliderStandardsPilot > pilotToDelete.dateOfGliderStandardsPilot ? dateOfGliderStandardsPilot : pilotToDelete.dateOfGliderStandardsPilot
        dateOfLaunchControlOfficer = dateOfLaunchControlOfficer > pilotToDelete.dateOfLaunchControlOfficer ? dateOfLaunchControlOfficer : pilotToDelete.dateOfLaunchControlOfficer
        dateOfRearSeatFamilPilot = dateOfRearSeatFamilPilot > pilotToDelete.dateOfRearSeatFamilPilot ? dateOfRearSeatFamilPilot : pilotToDelete.dateOfRearSeatFamilPilot
        dateOfTowCheckPilot = dateOfTowCheckPilot > pilotToDelete.dateOfTowCheckPilot ? dateOfTowCheckPilot : pilotToDelete.dateOfTowCheckPilot
        dateOfTowPilot = dateOfTowPilot > pilotToDelete.dateOfTowPilot ? dateOfTowPilot : pilotToDelete.dateOfTowPilot
        dateOfTowPilotXCountry = dateOfTowPilotXCountry > pilotToDelete.dateOfTowPilotXCountry ? dateOfTowPilotXCountry : pilotToDelete.dateOfTowPilotXCountry
        dateOfTowStandardsPilot = dateOfTowStandardsPilot > pilotToDelete.dateOfTowStandardsPilot ? dateOfTowStandardsPilot : pilotToDelete.dateOfTowStandardsPilot
        dateOfWinchLaunchInstructor = dateOfWinchLaunchInstructor > pilotToDelete.dateOfWinchLaunchInstructor ? dateOfWinchLaunchInstructor : pilotToDelete.dateOfWinchLaunchInstructor
        dateOfWinchLaunchOperator = dateOfWinchLaunchOperator > pilotToDelete.dateOfWinchLaunchOperator ? dateOfWinchLaunchOperator : pilotToDelete.dateOfWinchLaunchOperator
        dateOfWinchLaunchPilot = dateOfWinchLaunchPilot > pilotToDelete.dateOfWinchLaunchPilot ? dateOfWinchLaunchPilot : pilotToDelete.dateOfWinchLaunchPilot
        dateOfWinchRetrieveDriver = dateOfWinchRetrieveDriver > pilotToDelete.dateOfWinchRetrieveDriver ? dateOfWinchRetrieveDriver : pilotToDelete.dateOfWinchRetrieveDriver
        squadron = squadron > pilotToDelete.squadron ? squadron : pilotToDelete.squadron
        recordID = recordID < pilotToDelete.recordID ? recordID : pilotToDelete.recordID
        fiExpiry = fiExpiry > pilotToDelete.fiExpiry ? fiExpiry : pilotToDelete.fiExpiry
        recordChangeTime = recordChangeTime > pilotToDelete.recordChangeTime ? recordChangeTime : pilotToDelete.recordChangeTime
        
        highestGliderQual = highestGliderQual > pilotToDelete.highestGliderQual ? highestGliderQual : pilotToDelete.highestGliderQual
        highestScoutQual = highestScoutQual > pilotToDelete.highestScoutQual ? highestScoutQual : pilotToDelete.highestScoutQual

         if inactive == true || pilotToDelete.inactive == true
         {
            inactive = true
         }
         
         else
         {
            inactive = false
         }
        
        medical = medical > pilotToDelete.medical ? medical : pilotToDelete.medical
    }
    
    //MARK: - NSFetchedResultsController Delegate
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        NotificationCenter.default.post(name: reloadPilotNotification, object:self, userInfo:nil)
    }
    
    //MARK: - NSManagedObject Methods
    override func awakeFromFetch()
    {
        super.awakeFromFetch()

        addObserver(self, forKeyPath: "picAircraft", options: [.new], context: nil)
        addObserver(self, forKeyPath: "dualAircraft", options: [.new], context: nil)
        
        if fullName == ""
        {
            if firstName != ""
            {
                fullName = "\(name), \(firstName)"
            }
                
            else
            {
                fullName = name
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if (keyPath == "picAircraft")
        {
            if picAircraft != nil
            {
                dualAircraft = nil
            }
        }
        
        if (keyPath == "dualAircraft")
        {
            if dualAircraft != nil
            {
                picAircraft = nil
            }
        }
    }
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        recordChangeTime = Date()
        recordID = Date()
        addObserver(self, forKeyPath: "picAircraft", options: [.new], context: nil)
        addObserver(self, forKeyPath: "dualAircraft", options: [.new], context: nil)
        
        address = ""
        aniversaryOfGliderAPC = Date.distantPast
        aniversaryOfTowAPC = Date.distantPast
        birthday = Date() - 365*16*24*60*60
        city = ""
        dateOfBasicGliderPilot = Date.distantPast
        dateOfFrontSeatFamilPilot = Date.distantPast
        dateOfGliderCheckPilot = Date.distantPast
        dateOfGliderStandardsPilot = Date.distantPast
        aniversaryOfTowAPC = Date.distantPast
        dateOfGliderPilotXCountry = Date.distantPast
        dateOfLaunchControlOfficer = Date.distantPast
        dateOfRearSeatFamilPilot = Date.distantPast
        dateOfTowCheckPilot = Date.distantPast
        dateOfTowPilot = Date.distantPast
        dateOfTowPilotXCountry = Date.distantPast
        dateOfTowStandardsPilot = Date.distantPast
        dateOfWinchLaunchInstructor = Date.distantPast
        dateOfWinchLaunchOperator = Date.distantPast
        dateOfWinchLaunchPilot = Date.distantPast
        dateOfWinchRetrieveDriver = Date.distantPast
        fiExpiry = Date.distantPast
        medical = Date.distantPast
        email = ""
        firstName = ""
        fullName = ""
        gliderLicense = ""
        name = ""
        phone = ""
        powerLicense = ""
    }
    
    override func willSave()
    {
        var noChangesOtherThanSignOut = false
        
        let changes = changedValues()
        if changes["signedIn"] != nil, changes["attendanceRecords"] != nil, changes.count == 2
        {
            noChangesOtherThanSignOut = true
        }
        
        if shouldUpdateChangeTimes && noChangesOtherThanSignOut == false
        {
            setPrimitiveValue(Date(), forKey:"recordChangeTime")
        }
        
        super.willSave()
    }
    
    override func didSave()
    {
        if isDeleted == false, managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadPilotChanges(self)
        }
    }
    
    override func willTurnIntoFault()
    {
        removeObserver(self, forKeyPath: "picAircraft")
        removeObserver(self, forKeyPath: "dualAircraft")
    }
}

struct PilotFlyingStats
{
    var gliderFlights = 0
    var launchesAsWinchOperator = 0
    var launchesAsAutoDriver = 0
    var gliderPICminutes = 0
    var gliderDualMinutes = 0
    var gliderInstructorMinutes = 0
    var towPICminutes = 0
    var towAircraftTows = 0
}
