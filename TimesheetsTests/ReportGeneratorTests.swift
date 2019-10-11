//
//  TimesheetsTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-09-23.
//

import XCTest
import CoreData
@testable import Timesheets

/**
 This test class will be used to compare actual output for report to new output.
 
 The major goal is to refactor report generation to allow testing and separate reporting, data extract, and sharing of reporting results.
 
 There is a ManagedObjectContext that is rollbacked after each test. This ensure that we start fresh with each new test.
 */
class ReportGeneratorTests: XCTestCase
{
    let centerName = "Test"
    
    var context: NSManagedObjectContext!
    var center: GlidingCentre!
    var pilotJoBlack: Pilot!
    var pilotJohnDo: Pilot!
    var staffCadetPilot: Pilot!
    var cadet: Pilot!
    
    override func setUp()
    {
        dataModel.viewPreviousRecords = true
        dataModel.dateToViewRecords = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        regularFormat = true
        dataModel.regionName = "South"
        
        context = dataModel.managedObjectContext
        
        center = GlidingCentre(context: context)
        center.name = "Test"

        dataModel.glidingCentre = center
        dataModel.previousRecordsGlidingCentre = center // -TODO: need to confirm if that need to be set.
        
        pilotJoBlack = createPilot(name: "Jo Black", typeOfParticipant: "COATS")
        dataModel.createAttendanceRecordForPerson(pilotJoBlack)

        pilotJohnDo = createPilot(name: "John Do", typeOfParticipant: "COATS")

        staffCadetPilot = createStaffCadet(name: "Glider Pilot")
        dataModel.createAttendanceRecordForPerson(staffCadetPilot)
        
        cadet = createCadet(name: "A Cadet")
        dataModel.createAttendanceRecordForPerson(cadet)

        for _ in -4..<0
        {
            dataModel.dateToViewRecords += (60*60*24)
            dataModel.createAttendanceRecordForPerson(pilotJoBlack)
            dataModel.createAttendanceRecordForPerson(staffCadetPilot)
            dataModel.createAttendanceRecordForPerson(cadet)
        }
        dataModel.viewPreviousRecords = false
        dataModel.dateToViewRecords = Date().midnight + (-60*60*24)
    }

    override func tearDown() {
        context.rollback()
    }
    
    // MARK: - Exploratory tests
    func testCoreDataDelete() throws
    {
        // Arrange
        let centerNameToDelete = "CenterToDelete"
        let centerToDelete = GlidingCentre(context: context)
        centerToDelete.name = centerNameToDelete
        
        let request = GlidingCentre.request
        request.predicate = NSPredicate(format: "name = %@", centerNameToDelete)
        guard let centers = try? context.fetch(request) else
        {
            XCTFail("I just created a gliding center named \(centerNameToDelete), it sould be there.")
            return
        }
        
        // Act
        print("Number of \(centerNameToDelete) centers found: \(centers.count).")
        for center in centers
        {
            context.delete(center)
        }
        
        // Assert
        guard let centersAfterDelete = try? context.fetch(request),
            centersAfterDelete.count == 0 else
        {
                XCTFail("There should be no more \(centerNameToDelete) gliding centre; I deleted them all.")
                return
        }
    }
    
    /// This test doesn't contain any assert section. It was meant to show what was the typeOfParticipant present in the database (what is the possible values).
    func testTypeOfParticipant()
    {
        let request = Pilot.request
        guard let result = try? context.fetch(request) else
        {
            XCTFail("The request to obtain unique typeOfParticipant failed.")
            return
        }
        
        var distinctResult : [String: Int] = [:]
        result.forEach { distinctResult[$0.typeOfParticipant, default: 0] += 1 }
        print("Number of distinct value is \(distinctResult.count)")
        for value in distinctResult
        {
            print("typeOfParticipant \(value)")
        }
        
        XCTAssertTrue(distinctResult["COATS", default: 0] > 0, "Hoho... should have at least 1 of that.")
        XCTAssertTrue(distinctResult["patate", default: 0] == 0, "What !!! Who put that there?")
    }
    
    // MARK: - Tests for createAttendanceRecordForPerson
    // TODO: Move this section into its own test file.
    func testCreateAttendanceRecordForPersonSigninPilot()
    {
        print("Pilot is signed in? \(pilotJohnDo.signedIn)")
        dataModel.createAttendanceRecordForPerson(pilotJohnDo)
        
        XCTAssertTrue(pilotJohnDo.signedIn, "The pilot must now be signed in (as per the post condition of createAttendanceRecordForPerson.")
    }
    
    // MARK: - Helper functions for StatsReportFromDate
    // TODO: Never never forget to have some fun on the road to improvement!
    fileprivate func createPilot(name: String,
                                 typeOfParticipant: String,
                                 withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -20), to: Date())!) -> Pilot
    {
        let pilot = Pilot(context: context)
        pilot.name = name
        pilot.typeOfParticipant = typeOfParticipant
        pilot.glidingCentre = dataModel.glidingCentre
        pilot.email = "\(pilot.name.replacingOccurrences(of: " ", with: ""))@hellkitchen.us"
        pilot.address = "13 Anywhere"
        pilot.aniversaryOfTowAPC = Date().advanced(by: -10)
        pilot.aniversaryOfGliderAPC = Date().advanced(by: -10)
        pilot.birthday = birthday
        pilot.inactive = false
        pilot.highestGliderQual = 3
        return pilot
    }
    
    fileprivate func createStaffCadet(name: String,
                                      withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -17), to: Date())!,
                                      squadron : Int16 = 123) -> Pilot
    {
        let pilot = createPilot(name: name, typeOfParticipant: "Staff Cadet", withBirthDay: birthday)
        pilot.squadron = squadron
        return pilot
    }
    
    fileprivate func createCadet(name: String,
                                 withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -15), to: Date())!,
                                 squadron : Int16 = 123) -> Pilot
    {
        let pilot = createPilot(name: name, typeOfParticipant: "cadet", withBirthDay: birthday)
        pilot.squadron = squadron
        return pilot
    }

    fileprivate func createFlight(_ aircraft: AircraftEntity, _ timesheet: AircraftTimesheet, startingOn startDate: Date, forMinutes duration: Int16, sequence: TowplaneSequence = .TowCourse, withPilot pilot : Pilot? = nil, withPassenger passenger : Pilot? = nil) -> FlightRecord
    {
        let flight = FlightRecord(context: context)
        flight.aircraft = aircraft
        flight.timesheet = timesheet
        flight.flightSequence = sequence.rawValue
        flight.pilot = pilot ?? pilotJoBlack
        flight.passenger = passenger
        flight.timeUp = startDate
        flight.timeDown = Calendar.current.date(byAdding: Calendar.Component.minute, value: Int(duration), to: flight.timeUp)!
        flight.flightLengthInMinutes = duration
        return flight
    }

    fileprivate func createGliderFlight(_ aircraft: AircraftEntity, _ timesheet: AircraftTimesheet, startingOn startDate: Date, forMinutes duration: Int16, sequence: GliderSequence = .StudentTrg, withPilot pilot : Pilot? = nil, withPassenger passenger : Pilot? = nil, towByFlight towFlight : FlightRecord? = nil)
    {
        let flight = FlightRecord(context: context)
        flight.aircraft = aircraft
        flight.timesheet = timesheet
        flight.flightSequence = sequence.rawValue
        flight.pilot = pilot ?? pilotJoBlack
        flight.passenger = passenger
        flight.timeUp = startDate
        flight.timeDown = Calendar.current.date(byAdding: Calendar.Component.minute, value: Int(duration), to: flight.timeUp)!
        flight.flightLengthInMinutes = duration
        flight.connectedAircraftRecord = towFlight
    }

    fileprivate func createTimesheet(_ aircraft : AircraftEntity, _ forDate : Date) -> AircraftTimesheet {
        let timesheet = aircraft.insertNewTimeSheetForAircraft(withContext: context)
        timesheet.date = forDate
        timesheet.glidingCentre = dataModel.glidingCentre
        timesheet.initialTTSN = 0
        timesheet.glidingCentre = dataModel.glidingCentre
        timesheet.setTTSN()
        return timesheet
    }
    
    /**
     This method creates a tow plane in the current core data context.
     
     - Parameters:
     - registration: a string representing the registration number for the plan.
     - tailNumber: the number for the tow plane as it would appear on its tail.
     
     - Warning:
     The method uses `context` and `dataModel.glidingCentre` created once in this test file
     
     - Returns
     AircraftEntity: the entity created for the new tow plane.
     */
    fileprivate func createTowPlane(registration: String, tailNumber: String) -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = registration
        aircraft.tailNumber = tailNumber
        aircraft.type = .towplane
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = dataModel.glidingCentre
        return aircraft
    }
    
    fileprivate func createGlider(registration: String, tailNumber: String) -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = registration
        aircraft.tailNumber = tailNumber
        aircraft.type = .glider
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = dataModel.glidingCentre
        return aircraft
    }
    
    fileprivate func createAutoTow() -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = "AUTO"
        aircraft.tailNumber = "GO-UP"
        aircraft.type = .auto
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = dataModel.glidingCentre
        return aircraft
    }
    
    fileprivate func createWinchTow() -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = "WINCH"
        aircraft.tailNumber = "#1"
        aircraft.type = .winch
        aircraft.gliderOrTowplane = Int16(aircraft.type.rawValue)
        aircraft.glidingCentre = dataModel.glidingCentre
        return aircraft
    }

    fileprivate func createMaintenance(for aircraft: AircraftEntity, on date: Date, withComment comment: String) -> MaintenanceEvent
    {
        let event = MaintenanceEvent(context: context)
        event.aircraft = aircraft
        event.date = date
        event.comment = comment
        return event
    }

    /**
     This method attach the `data` as an html file to the current test.
     */
    fileprivate func saveResultAsHtml(data: String, name: String)
    {
        let html = XCTAttachment(data: data.data(using: .utf8)!, uniformTypeIdentifier: "html")
        html.name = name
        html.lifetime = .keepAlways
        self.add(html)
    }
    
    // MARK: - StatsReportFromDate
    func testStatsReportFromDateIsHTML()
    {
        let generator = ReportGenerator()
        
        let forDate = Date()
        let result = generator.statsReportFromDate(forDate, toDate: forDate)
        
        XCTAssert(result.hasPrefix("<html>"), "This is not html?")
        XCTAssert(result.hasSuffix("</html>"), "This is not html?")
        XCTAssertTrue(result.contains(forDate.militaryFormatShort.uppercased()), "Date \(forDate.militaryFormatShort.uppercased()) not found in content")
    }
    
    func testStatsReportFromDateForCenter()
    {
        let generator = ReportGenerator()
        generator.unit = dataModel.glidingCentre.name // FIXME: Find out why need to do both: set the generator unit AND pass the parameter siteSpecific=true
        let forDate = Date()
        let result = generator.statsReportFromDate(forDate, toDate: forDate, true)
        
        XCTAssertTrue(result.contains(dataModel.glidingCentre.name), "Our challenge, if we accept it, is to find how we display the centre name instead of the title REGIONAL REPORT.")
    }
    
    /**
     I'm adding code to this test so I can check every section of the report.
     This is a big challenge.
     
     It can become quite embarassing if it becomes too **big**
     
     - Warning
     The content of this test method will become quite big. This is because I'd like to have all possible cases in one place.
     This might not be possible though. We'll see. If that become too big, I whish to have what it takes to split it into smaller tests...;-)
     
     Better brace yourself!
     
     - TODO: Once all tests implemented in that method, we might think of spliting it. Should not be that hard.
     */
    func testStatsReportFromDateIncludeAircraftInReport()
    {
        // Given
        dataModel.createAttendanceRecordForPerson(pilotJohnDo)

        let aircraft = createTowPlane(registration: "REG", tailNumber: "123")
        
        let lastFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-1), to: Date())!
        var timesheet = createTimesheet(aircraft, lastFlightDate)
        _ = createFlight(aircraft, timesheet, startingOn: lastFlightDate, forMinutes: 300)
        
        aircraft.updateTTSN() // important to updateTTSN after each timesheet created with its flight. Otherwise the time is not adding up properly for the report...

        let middleFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-2), to: Date())!
        timesheet = createTimesheet(aircraft, middleFlightDate)
        _ = createFlight(aircraft, timesheet, startingOn: middleFlightDate, forMinutes: 25, sequence: .Proficiency)
        _ = createFlight(aircraft, timesheet, startingOn: middleFlightDate, forMinutes: 15, sequence: .Towing)
        _ = createFlight(aircraft, timesheet, startingOn: middleFlightDate, forMinutes: 65, sequence: .Upgrade)

        aircraft.updateTTSN()
        
        let previousFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-3), to: Date())!
        timesheet = createTimesheet(aircraft, previousFlightDate)
        _ = createFlight(aircraft, timesheet, startingOn: previousFlightDate, forMinutes: 5, sequence: .Maintenance)
        _ = createFlight(aircraft, timesheet, startingOn: previousFlightDate, forMinutes: 20, sequence: .FamPRWx)
        _ = createFlight(aircraft, timesheet, startingOn: previousFlightDate, forMinutes: 30, sequence: .Transit)
        
        aircraft.updateTTSN()
        
        // FIXME: total of 460 minutes in 7 flights... only 6 flights are totalized, but all the minutes are there....
        
        let glider = createGlider(registration: "Glider", tailNumber: "333")
        let maintenanceEvent = createMaintenance(for: glider,
                          on: Calendar.current.date(byAdding: Calendar.Component.month, value: -1, to: Date())!,
                          withComment: "Maintenance pour \"\(glider.registrationWithTailNumberInBrackets)\".")
        let maintenanceEvent2 = createMaintenance(for: glider,
                                                 on: Calendar.current.date(byAdding: Calendar.Component.month, value: -2, to: Date())!,
                                                 withComment: "Something broke on \"\(glider.registrationWithTailNumberInBrackets)\".")
        let gliderTakeOffDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-4), to: Date())!
        let gliderTimesheet = createTimesheet(glider, gliderTakeOffDate)
        let towTimesheet = createTimesheet(aircraft, gliderTakeOffDate)
        let towFlight = createFlight(aircraft, towTimesheet, startingOn: gliderTakeOffDate, forMinutes: 20, sequence: .TowCourse)
        aircraft.updateTTSN()
        createGliderFlight(glider, gliderTimesheet, startingOn: gliderTakeOffDate, forMinutes: 40, sequence: .StudentTrg, withPilot: staffCadetPilot, towByFlight: towFlight)
        glider.updateTTSN()

        // FIXME: total of 480 minutes in 8 flights... only 7 flights are totalized, but all the minutes are there....

        // AUTO LAUNCH
        let gliderLaunchWithAuto = createGlider(registration: "GliderFromGround", tailNumber: "GCTMT")
        let autoLauncher = createAutoTow()
        let gliderLaunchFromGroundTimesheet = createTimesheet(gliderLaunchWithAuto, gliderTakeOffDate)
        let autoLauncherTimesheet = createTimesheet(autoLauncher, gliderTakeOffDate)
        let autoLauncherFlight = createFlight(autoLauncher, autoLauncherTimesheet, startingOn: gliderTakeOffDate, forMinutes: 2, sequence: .TowCourse)
        createGliderFlight(gliderLaunchWithAuto, gliderLaunchFromGroundTimesheet, startingOn: gliderTakeOffDate, forMinutes: 10, sequence: .Famil, withPilot: staffCadetPilot, towByFlight: autoLauncherFlight)
        
        autoLauncher.updateTTSN()
        gliderLaunchWithAuto.updateTTSN()

        // 2 WINCH LAUNCHes
        let gliderLaunchWithWinch = createGlider(registration: "GliderFromWinch", tailNumber: "AAAAH")
        let winchLauncher = createWinchTow()
        let gliderLaunchWithWinchTimesheet = createTimesheet(gliderLaunchWithWinch, gliderTakeOffDate)
        let winchLauncherTimesheet = createTimesheet(winchLauncher, gliderTakeOffDate)
        let winchLauncherFlight = createFlight(winchLauncher, winchLauncherTimesheet, startingOn: gliderTakeOffDate, forMinutes: 2, sequence: .TowCourse)
        createGliderFlight(gliderLaunchWithWinch, gliderLaunchWithWinchTimesheet, startingOn: gliderTakeOffDate, forMinutes: 10, sequence: .Famil, withPilot: staffCadetPilot, towByFlight: winchLauncherFlight)

        winchLauncher.updateTTSN()
        gliderLaunchWithWinch.updateTTSN()

        _ = createFlight(winchLauncher, winchLauncherTimesheet, startingOn: gliderTakeOffDate, forMinutes: 2, sequence: .TowCourse)
        createGliderFlight(gliderLaunchWithWinch, gliderLaunchWithWinchTimesheet, startingOn: gliderTakeOffDate, forMinutes: 10, sequence: .Famil, withPilot: staffCadetPilot, towByFlight: winchLauncherFlight)

        winchLauncher.updateTTSN()
        gliderLaunchWithWinch.updateTTSN()

        // When
        let reportDate = Date()
        let generator = ReportGenerator()
        generator.unit = dataModel.glidingCentre.name
        let result = generator.statsReportFromDate(reportDate - (5*24*60*60), toDate: reportDate, true)
        let result2 = generator.statsReportFromDateWithReportGenerator(reportDate - (5*24*60*60), toDate: reportDate, true)
        
        // Then
        saveResultAsHtml(data: result, name: "report-\(reportDate).html")
        saveResultAsHtml(data: result2, name: "report2-\(reportDate).html")

        XCTAssertFalse(result.contains("</tr><td"), "Oops... misformated HTML; <tr> missing between </tr> and <td>.")
        XCTAssertFalse(result.contains("</td><tr"), "Oops... misformated HTML; </tr> missing between </td> and <tr>.")
        XCTAssertFalse(result.contains("</table></table>"), "Oops... misformated HTML; multiple </table> together.")
        XCTAssert(result.contains("\(aircraft.registrationWithTailNumberInBrackets)</td>"),
                  "Plane \" \(aircraft.registrationWithTailNumberInBrackets)\" missing from the table.")
        XCTAssertTrue(result.contains("<td>\(lastFlightDate.militaryFormatShort)</td>"),
                      "Line for date \(lastFlightDate.militaryFormatShort) missing from the table.")
        let aircraftRegWithTailNumberForRegEx = aircraft.registrationWithTailNumberInBrackets.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
        AssertMatch(result, pattern: "<tr><td.+?>\(aircraftRegWithTailNumberForRegEx)</td>.+?<td>\(lastFlightDate.militaryFormatShort)</td><td>(.+?)</td>", expectedValue: "5.0")
        XCTAssertTrue(result.contains(maintenanceEvent.comment), "Oops... \"\(maintenanceEvent.comment)\" not found.")
        XCTAssertTrue(result.contains(maintenanceEvent2.comment), "Oops... \"\(maintenanceEvent2.comment)\"not found.")
        let registrationWithTailNumberInBracketsForRegEx = gliderLaunchWithAuto.registrationWithTailNumberInBrackets.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
        AssertMatch(result, pattern: "<tr><td[^>]+?>\(registrationWithTailNumberInBracketsForRegEx)</td>.+?</tr><tr>.+?</tr><tr><td>.+?</td><td>.+?</td><td>(.+?)</td>",
            expectedValue: "1")
        AssertMatch(result, pattern: "(.) winch launches", expectedValue: "2")
        AssertMatch(result, pattern: "(.) auto launches", expectedValue: "1")
    }
    
    
}
