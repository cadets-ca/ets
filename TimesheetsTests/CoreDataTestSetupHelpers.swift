//
//  CoreDataTestSetupHelpers.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-11-14.
//

import Foundation
import CoreData
@testable import Timesheets

class CoreDataTestSetupHelpers
{
    private var context: NSManagedObjectContext
    {
        return dataModel.managedObjectContext
    }
    
    var defaultCentre : GlidingCentre!
    var defaultPilot : Pilot!
    
    func setDefaultCentre(_ centre: GlidingCentre)
    {
        dataModel.glidingCentre = centre
        dataModel.previousRecordsGlidingCentre = centre
        defaultCentre = centre
    }
    
    func setDefaultPilot(_ pilot: Pilot)
    {
        defaultPilot = pilot
    }
    
    func rollback()
    {
        context.rollback()
    }
    
    func createGlidingCentre(_ name : String) -> GlidingCentre
    {
        let centre = GlidingCentre(context: context)
        centre.name = name
        return centre
    }
    
    func createPilot(name: String,
                     typeOfParticipant: String,
                     withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -20), to: Date())!) -> Pilot
    {
        let pilot = Pilot(context: context)
        pilot.name = name
        pilot.firstName = name.components(separatedBy: " ")[0]
        pilot.fullName = name
        pilot.typeOfParticipant = typeOfParticipant
        pilot.glidingCentre = defaultCentre
        pilot.email = "\(pilot.name.replacingOccurrences(of: " ", with: ""))@hellkitchen.us"
        pilot.address = "13 Anywhere"
        pilot.aniversaryOfTowAPC = Date().advanced(by: -10)
        pilot.aniversaryOfGliderAPC = Date().advanced(by: -10)
        pilot.birthday = birthday
        pilot.inactive = false
        pilot.highestGliderQual = 3
        return pilot
    }
    
    func createStaffCadet(name: String,
                          withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -17), to: Date())!,
                          squadron : Int16 = 123) -> Pilot
    {
        let pilot = createPilot(name: name, typeOfParticipant: "Staff Cadet", withBirthDay: birthday)
        pilot.squadron = squadron
        return pilot
    }
    
    func createCadet(name: String,
                     withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -15), to: Date())!,
                     squadron : Int16 = 123) -> Pilot
    {
        let pilot = createPilot(name: name, typeOfParticipant: "cadet", withBirthDay: birthday)
        pilot.squadron = squadron
        return pilot
    }
    
    func createFlight(_ aircraft: AircraftEntity, _ timesheet: AircraftTimesheet, startingOn startDate: Date, forMinutes duration: Int16, sequence: TowplaneSequence = .TowCourse, withPilot pilot : Pilot? = nil, withPassenger passenger : Pilot? = nil) -> FlightRecord
    {
        let flight = FlightRecord(context: context)
        flight.aircraft = aircraft
        flight.timesheet = timesheet
        flight.flightSequence = sequence.rawValue
        flight.pilot = pilot ?? defaultPilot
        flight.passenger = passenger
        flight.timeUp = startDate
        flight.timeDown = Calendar.current.date(byAdding: Calendar.Component.minute, value: Int(duration), to: flight.timeUp)!
        flight.flightLengthInMinutes = duration
        return flight
    }

    func createGliderFlight(_ aircraft: AircraftEntity, _ timesheet: AircraftTimesheet, startingOn startDate: Date, forMinutes duration: Int16, sequence: GliderSequence = .StudentTrg, withPilot pilot : Pilot? = nil, withPassenger passenger : Pilot? = nil, towByFlight towFlight : FlightRecord? = nil) -> FlightRecord
    {
        let flight = FlightRecord(context: context)
        flight.aircraft = aircraft
        flight.timesheet = timesheet
        flight.flightSequence = sequence.rawValue
        flight.pilot = pilot ?? defaultPilot
        flight.passenger = passenger
        flight.timeUp = startDate
        flight.timeDown = Calendar.current.date(byAdding: Calendar.Component.minute, value: Int(duration), to: flight.timeUp)!
        flight.flightLengthInMinutes = duration
        flight.connectedAircraftRecord = towFlight
        return flight
    }

    func createTimesheet(_ aircraft : AircraftEntity, _ forDate : Date) -> AircraftTimesheet {
        let timesheet = aircraft.insertNewTimeSheetForAircraft(withContext: context)
        timesheet.date = forDate
        timesheet.glidingCentre = dataModel.glidingCentre
        timesheet.initialTTSN = 0
        timesheet.glidingCentre = dataModel.glidingCentre
        timesheet.setTTSN()
        return timesheet
    }
    
    func createLaunch(glider : AircraftEntity, launcher : AircraftEntity, takeOffDate : Date, withPilot pilot : Pilot)
    {
        let gliderTimesheet = createTimesheet(glider, takeOffDate)
        let launcherTimesheet = createTimesheet(launcher, takeOffDate)
        let launcherFlight = createFlight(launcher, launcherTimesheet, startingOn: takeOffDate, forMinutes: 20, sequence: .TowCourse)
        _ = createGliderFlight(glider, gliderTimesheet, startingOn: takeOffDate, forMinutes: 20, sequence: .Famil,
                               withPilot: pilot, towByFlight: launcherFlight)
        
        launcher.updateTTSN()
        glider.updateTTSN()
    }

    func createTowPlane(registration: String, tailNumber: String) -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = registration
        aircraft.tailNumber = tailNumber
        aircraft.type = .towplane
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = defaultCentre
        return aircraft
    }
    
    func createGlider(registration: String, tailNumber: String) -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = registration
        aircraft.tailNumber = tailNumber
        aircraft.type = .glider
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = defaultCentre
        return aircraft
    }
    
    func createAutoTow() -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = "AUTO"
        aircraft.tailNumber = "GO-UP"
        aircraft.type = .auto
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = defaultCentre
        return aircraft
    }

    func createWinchTow(registration : String, tailNumber : String) -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = registration
        aircraft.tailNumber = tailNumber
        aircraft.type = .winch
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = defaultCentre
        return aircraft
    }
    
    func createMaintenance(for aircraft: AircraftEntity, on date: Date, withComment comment: String) -> MaintenanceEvent
    {
        let event = MaintenanceEvent(context: context)
        event.aircraft = aircraft
        event.date = date
        event.comment = comment
        return event
    }

    func fetch<T>(_ request : NSFetchRequest<T>) throws -> [T]
    {
        return try context.fetch(request)
    }
    
    func delete(_ obj : NSManagedObject)
    {
        context.delete(obj)
    }
}
