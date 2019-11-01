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
    var centre: GlidingCentre!
    var anotherCenter : GlidingCentre!
    var pilotJoBlack: Pilot!
    var pilotJohnDo: Pilot!
    var staffCadetPilot: Pilot!
    var staffCadetPilot2: Pilot!
    var cadet: Pilot!
    
    override func setUp()
    {
        dataModel.viewPreviousRecords = true
        dataModel.dateToViewRecords = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        regularFormat = true
        dataModel.regionName = "South"
        
        context = dataModel.managedObjectContext
        
        centre = GlidingCentre(context: context)
        centre.name = "Middle Island"
        
        anotherCenter = GlidingCentre( context: context)
        anotherCenter.name = "Pelee Island"

        dataModel.glidingCentre = centre
        dataModel.previousRecordsGlidingCentre = centre // -TODO: need to confirm if that need to be set.
        
        pilotJoBlack = createPilot(name: "Jo Black", typeOfParticipant: "COATS")
        dataModel.createAttendanceRecordForPerson(pilotJoBlack)

        pilotJohnDo = createPilot(name: "John Do", typeOfParticipant: "COATS")

        staffCadetPilot = createStaffCadet(name: "Glider Pilot 1", squadron: 444)
        dataModel.createAttendanceRecordForPerson(staffCadetPilot)
        
        staffCadetPilot2 = createStaffCadet(name: "Glider Pilot 2", squadron: 618)
        dataModel.createAttendanceRecordForPerson(staffCadetPilot2)

        cadet = createCadet(name: "A Cadet", squadron: 999)
        dataModel.createAttendanceRecordForPerson(cadet)

        for _ in -4..<0
        {
            dataModel.dateToViewRecords += (60*60*24)
            dataModel.createAttendanceRecordForPerson(pilotJoBlack)
            dataModel.createAttendanceRecordForPerson(staffCadetPilot)
            dataModel.createAttendanceRecordForPerson(staffCadetPilot2)
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
        pilot.firstName = name.components(separatedBy: " ")[0]
        pilot.fullName = name
        pilot.typeOfParticipant = typeOfParticipant
        pilot.glidingCentre = centre
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
    
    fileprivate func createWinchTow(registration : String, tailNumber : String) -> AircraftEntity
    {
        let aircraft = AircraftEntity(context: context)
        aircraft.registration = registration
        aircraft.tailNumber = tailNumber
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
    
    fileprivate func createLaunch(glider : AircraftEntity, launcher : AircraftEntity, takeOffDate : Date)
    {
        let gliderTimesheet = createTimesheet(glider, takeOffDate)
        let launcherTimesheet = createTimesheet(launcher, takeOffDate)
        let launcherFlight = createFlight(launcher, launcherTimesheet, startingOn: takeOffDate, forMinutes: 20, sequence: .TowCourse)
        createGliderFlight(glider, gliderTimesheet, startingOn: takeOffDate, forMinutes: 20, sequence: .Famil, withPilot: staffCadetPilot, towByFlight: launcherFlight)
        
        launcher.updateTTSN()
        glider.updateTTSN()
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

        let towPlane1 = createTowPlane(registration: "REG#1", tailNumber: "123")
        _ = createTowPlane(registration: "REG#2", tailNumber: "3")

        let lastFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-1), to: Date())!
        var timesheet = createTimesheet(towPlane1, lastFlightDate)
        _ = createFlight(towPlane1, timesheet, startingOn: lastFlightDate, forMinutes: 300)
        
        towPlane1.updateTTSN() // important to updateTTSN after each timesheet created with its flight. Otherwise the time is not adding up properly for the report...

        let middleFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-2), to: Date())!
        timesheet = createTimesheet(towPlane1, middleFlightDate)
        _ = createFlight(towPlane1, timesheet, startingOn: middleFlightDate, forMinutes: 25, sequence: .Proficiency)
        _ = createFlight(towPlane1, timesheet, startingOn: middleFlightDate, forMinutes: 15, sequence: .Towing)
        _ = createFlight(towPlane1, timesheet, startingOn: middleFlightDate, forMinutes: 65, sequence: .Upgrade)

        towPlane1.updateTTSN()
        
        let previousFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-3), to: Date())!
        timesheet = createTimesheet(towPlane1, previousFlightDate)
        _ = createFlight(towPlane1, timesheet, startingOn: previousFlightDate, forMinutes: 5, sequence: .Maintenance)
        _ = createFlight(towPlane1, timesheet, startingOn: previousFlightDate, forMinutes: 20, sequence: .FamPRWx)
        _ = createFlight(towPlane1, timesheet, startingOn: previousFlightDate, forMinutes: 30, sequence: .Transit)
        
        towPlane1.updateTTSN()
        
        // FIXME: total of 460 minutes in 7 flights... only 6 flights are totalized, but all the minutes are there....
        
        let glider = createGlider(registration: "Glider", tailNumber: "333")
        let maintenanceEvent = createMaintenance(for: glider,
                          on: Calendar.current.date(byAdding: Calendar.Component.month, value: -1, to: Date())!,
                          withComment: "Maintenance pour \"\(glider.registrationWithTailNumberInBrackets)\".")
        let maintenanceEvent2 = createMaintenance(for: glider,
                                                 on: Calendar.current.date(byAdding: Calendar.Component.month, value: -2, to: Date())!,
                                                 withComment: "Something broke on \"\(glider.registrationWithTailNumberInBrackets)\".")
        
        //
        let gliderTakeOffDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-4), to: Date())!
        
        //
        createLaunch(glider: glider, launcher: towPlane1, takeOffDate: gliderTakeOffDate)
        // - TODO: Create another launch for another towplane
        
        // FIXME: total of 480 minutes in 8 flights... only 7 flights are totalized, but all the minutes are there....

        // AUTO LAUNCH
        let gliderLaunchWithAuto = createGlider(registration: "GliderFromGround", tailNumber: "GCTMT")
        let autoLauncher = createAutoTow()
        createLaunch(glider: gliderLaunchWithAuto, launcher: autoLauncher, takeOffDate: gliderTakeOffDate)

        // 2 WINCH LAUNCHes
        let gliderLaunchWithWinch = createGlider(registration: "GliderFromWinch1", tailNumber: "AAAAH")
        let winchLauncher = createWinchTow(registration: "WINCH", tailNumber: "#1")
        createLaunch(glider: gliderLaunchWithWinch, launcher: winchLauncher, takeOffDate: gliderTakeOffDate)
        let gliderLaunchWithWinch2 = createGlider(registration: "GliderFromWinch2", tailNumber: "OOOOH")
        let winchLauncher2 = createWinchTow(registration: "WINCH", tailNumber: "#2")
        createLaunch(glider: gliderLaunchWithWinch2, launcher: winchLauncher2, takeOffDate: gliderTakeOffDate)

        // Upgrade
        let staffUpgradeFrontSeat = createPilot(name: "Upgrade Pilot 1", typeOfParticipant: "COATS")
        staffUpgradeFrontSeat.dateOfFrontSeatFamilPilot = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        staffUpgradeFrontSeat.highestGliderQual = 3
        let staffUpgradeRearSeat = createStaffCadet(name: "Upgrade Pilot 2",squadron: 613)
        staffUpgradeRearSeat.dateOfRearSeatFamilPilot = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        staffUpgradeRearSeat.highestGliderQual = 4

        let staffUpgradeRearSeat2 = createStaffCadet(name: "Upgrade Pilot 3",squadron: 121)
        staffUpgradeRearSeat2.dateOfRearSeatFamilPilot = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        staffUpgradeRearSeat2.highestGliderQual = 4
        staffUpgradeRearSeat2.glidingCentre = anotherCenter

        // When
        let reportDate = Date()
        let generator = ReportGenerator()
        generator.unit = dataModel.glidingCentre.name
        let result = generator.statsReportFromDate(reportDate - (5*24*60*60), toDate: reportDate, false)
        let result2 = generator.statsReportFromDate(for: HtmlStatsReportFromDate(reportDate - (5*24*60*60), toDate: reportDate, false))
        _ = generator.statsReportFromDate(for: ExcelStatsReportFromDate(reportDate - (5*24*60*60), toDate: reportDate, false))

        // Then
        saveResultAsHtml(data: result, name: "report-\(reportDate).html")
        saveResultAsHtml(data: result2, name: "report2-\(reportDate).html")

        XCTAssertFalse(result.contains("</tr><td"), "Oops... misformated HTML; <tr> missing between </tr> and <td>.")
        XCTAssertFalse(result.contains("</td><tr"), "Oops... misformated HTML; </tr> missing between </td> and <tr>.")
        XCTAssertFalse(result.contains("</table></table>"), "Oops... misformated HTML; multiple </table> together.")
        XCTAssert(result.contains("\(towPlane1.registrationWithTailNumberInBrackets)</td>"),
                  "Plane \" \(towPlane1.registrationWithTailNumberInBrackets)\" missing from the table.")
        XCTAssertTrue(result.contains("<td>\(lastFlightDate.militaryFormatShort)</td>"),
                      "Line for date \(lastFlightDate.militaryFormatShort) missing from the table.")
        let aircraftRegWithTailNumberForRegEx = towPlane1.registrationWithTailNumberInBrackets.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
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
