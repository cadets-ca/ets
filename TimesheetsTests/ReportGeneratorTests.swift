//
//  TimesheetsTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-09-23.
//

import XCTest
import CoreData
@testable import Timesheets

/// This test class will be used to compare actual output for report to new output. The major goal is to refactor report generation to allow testing and separate
/// reporting, data extract, and sharing of reporting results
class ReportGeneratorTests: XCTestCase, NDHTMLtoPDFDelegate {
    func HTMLtoPDFDidSucceed(_ htmlToPDF: NDHTMLtoPDF) {
        print("File saved.")
    }
    
    func HTMLtoPDFDidFail(_ htmlToPDF: NDHTMLtoPDF) {
        print("File NOT saved.")
    }
    
    let centerName = "Test"
    
    var context: NSManagedObjectContext!
    var center: GlidingCentre!
    var pilotJoBlack: Pilot!
    var pilotJohnDo: Pilot!
    var staffCadetPilot: Pilot!
    
    override func setUp()
    {
        dataModel.viewPreviousRecords = false
        regularFormat = true
        dataModel.regionName = "South"
        
        context = dataModel.managedObjectContext
        
        let request = GlidingCentre.request
        request.predicate = NSPredicate(format: "name = %@", centerName)
        if let centers = try? context.fetch(request), centers.count > 0 {
            center = centers.first
        } else {
            center = GlidingCentre(context: context)
            center.name = "Test"
        }
        dataModel.glidingCentre = center
        dataModel.previousRecordsGlidingCentre = center
        dataModel.regionName = "NORTH"
        
        if pilotJoBlack == nil
        {
            pilotJoBlack = createPilot(name: "Jo Black", typeOfParticipant: "COATS")
            dataModel.createAttendanceRecordForPerson(pilotJoBlack)
        }
        
        if pilotJohnDo == nil
        {
            pilotJohnDo = createPilot(name: "John Do", typeOfParticipant: "COATS")
        }
        
        if staffCadetPilot == nil
        {
            staffCadetPilot = createPilot(name: "Glider Pilot", typeOfParticipant: "Staff Cadet")
            dataModel.createAttendanceRecordForPerson(staffCadetPilot)
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK: - Exploratory tests
    func testCoreDataDelete() throws {
        // Arrange
        let centerNameToDelete = "CenterToDelete"
        let centerToDelete = GlidingCentre(context: context)
        centerToDelete.name = centerNameToDelete
        
        let request = GlidingCentre.request
        request.predicate = NSPredicate(format: "name = %@", centerNameToDelete)
        guard let centers = try? context.fetch(request) else {
            XCTFail("I just created a gliding center named \(centerNameToDelete), it sould be there.")
            return
        }
        
        // Act
        print("Number of \(centerNameToDelete) centers found: \(centers.count).")
        for center in centers {
            context.delete(center)
        }
        
        // Assert
        guard let centersAfterDelete = try? context.fetch(request),
            centersAfterDelete.count == 0 else {
                XCTFail("There should be no more \(centerNameToDelete) gliding centre; I deleted them all.")
                return
        }
    }
    
    /// This test doesn't contain any assert section. It was meant to show what was the typeOfParticipant present in the database (what is the possible values).
    func testTypeOfParticipant() {
        let request = Pilot.request
        guard let result = try? context.fetch(request) else {
            XCTFail("The request to obtain unique typeOfParticipant failed.")
            return
        }
        
        var distinctResult : [String: Int] = [:]
        result.forEach { distinctResult[$0.typeOfParticipant, default: 0] += 1 }
        print("Number of distinct value is \(distinctResult.count)")
        for value in distinctResult {
            print("typeOfParticipant \(value)")
        }
        
        XCTAssertTrue(distinctResult["COATS", default: 0] > 0, "Hoho... should have at least 1 of that.")
        XCTAssertTrue(distinctResult["patate", default: 0] == 0, "What !!! Who put that there?")
    }
    
    // MARK: - Tests for createAttendanceRecordForPerson
    // TODO: Move this section into its own test file.
    func testCreateAttendanceRecordForPersonSigninPilot() {
        
        print("Pilot is signed in? \(pilotJohnDo.signedIn)")
        dataModel.createAttendanceRecordForPerson(pilotJohnDo)
        
        XCTAssertTrue(pilotJohnDo.signedIn, "The pilot must now be signed in (as per the post condition of createAttendanceRecordForPerson.")
    }
    
    // MARK: - Helper functions for StatsReportFromDate
    // TODO: Never never forget to have some fun on the road to improvement!
    
    fileprivate func createPilot(name: String, typeOfParticipant: String, withBirthDay birthday : Date = Calendar.current.date(byAdding: DateComponents(year: -20), to: Date())!) -> Pilot
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
        return pilot
    }
    
    fileprivate func createFlight(_ aircraft: AircraftEntity, _ timesheet: AircraftTimesheet, startingOn startDate: Date, forMinutes duration: Int16, sequence: TowplaneSequence = .TowCourse, withPilot pilot : Pilot? = nil, withPassenger passenger : Pilot? = nil) {
        let flight = FlightRecord(context: context)
        flight.aircraft = aircraft
        flight.timesheet = timesheet
        flight.flightSequence = sequence.rawValue
        flight.pilot = pilot ?? pilotJoBlack
        flight.passenger = passenger
        flight.timeUp = startDate
        flight.timeDown = Calendar.current.date(byAdding: Calendar.Component.minute, value: Int(duration), to: flight.timeUp)!
        flight.flightLengthInMinutes = duration
    }

    fileprivate func createGliderFlight(_ aircraft: AircraftEntity, _ timesheet: AircraftTimesheet, startingOn startDate: Date, forMinutes duration: Int16, sequence: GliderSequence = .StudentTrg, withPilot pilot : Pilot? = nil, withPassenger passenger : Pilot? = nil) {
        let flight = FlightRecord(context: context)
        flight.aircraft = aircraft
        flight.timesheet = timesheet
        flight.flightSequence = sequence.rawValue
        flight.pilot = pilot ?? pilotJoBlack
        flight.passenger = passenger
        flight.timeUp = startDate
        flight.timeDown = Calendar.current.date(byAdding: Calendar.Component.minute, value: Int(duration), to: flight.timeUp)!
        flight.flightLengthInMinutes = duration
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
    func testStatsReportFromDateIsHTML() {
        let generator = ReportGenerator()
        
        let forDate = Date()
        let result = generator.statsReportFromDate(forDate, toDate: forDate)
        
        XCTAssert(result.hasPrefix("<html>"), "This is not html?")
        XCTAssert(result.hasSuffix("</html>"), "This is not html?")
        XCTAssertTrue(result.contains(forDate.militaryFormatShort.uppercased()), "Date \(forDate.militaryFormatShort.uppercased()) not found in content")
    }
    
    func testStatsReportFromDateForCenter() {
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
     */
    func testStatsReportFromDateIncludeAircraftInReport() {
        // Given
        dataModel.createAttendanceRecordForPerson(pilotJohnDo)

        let aircraft = createTowPlane(registration: "REG", tailNumber: "123")
        
        let lastFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-1), to: Date())!
        var timesheet = createTimesheet(aircraft, lastFlightDate)
        createFlight(aircraft, timesheet, startingOn: lastFlightDate, forMinutes: 300)
        
        aircraft.updateTTSN() // important to updateTTSN after each timesheet created with its flight. Otherwise the time is not adding up properly for the report...

        let middleFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-2), to: Date())!
        timesheet = createTimesheet(aircraft, middleFlightDate)
        createFlight(aircraft, timesheet, startingOn: middleFlightDate, forMinutes: 25, sequence: .Proficiency)
        createFlight(aircraft, timesheet, startingOn: middleFlightDate, forMinutes: 15, sequence: .Towing)
        createFlight(aircraft, timesheet, startingOn: middleFlightDate, forMinutes: 65, sequence: .Upgrade)

        aircraft.updateTTSN()
        
        let previousFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-3), to: Date())!
        timesheet = createTimesheet(aircraft, previousFlightDate)
        createFlight(aircraft, timesheet, startingOn: previousFlightDate, forMinutes: 5, sequence: .Maintenance)
        createFlight(aircraft, timesheet, startingOn: previousFlightDate, forMinutes: 20, sequence: .FamPRWx)
        createFlight(aircraft, timesheet, startingOn: previousFlightDate, forMinutes: 30, sequence: .Transit)
        
        aircraft.updateTTSN()
        
        // FIXME: total of 460 minutes in 7 flights... only 6 flights are totalized, but all the minutes are there....
        let glider = createGlider(registration: "Glider", tailNumber: "333")
        let gliderTakeOffDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-4), to: Date())!
        let gliderTimesheet = createTimesheet(glider, gliderTakeOffDate)
        let towTimesheet = createTimesheet(aircraft, gliderTakeOffDate)
        createFlight(aircraft, towTimesheet, startingOn: gliderTakeOffDate, forMinutes: 20, sequence: .TowCourse)
        aircraft.updateTTSN()
        createGliderFlight(glider, gliderTimesheet, startingOn: gliderTakeOffDate, forMinutes: 40, sequence: .StudentTrg, withPilot: staffCadetPilot)
        glider.updateTTSN()
        
        
        // When
        let reportDate = Date()
        let generator = ReportGenerator()
        generator.unit = dataModel.glidingCentre.name
        let result = generator.statsReportFromDate(reportDate - (5*24*60*60), toDate: reportDate, true)
        
        // Then
        saveResultAsHtml(data: result, name: "report-\(reportDate).html")
        
        XCTAssertFalse(result.contains("</tr><td"), "Oops... misformated HTML; <tr> missing between </tr> and <td>.")
        XCTAssertFalse(result.contains("</td><tr"), "Oops... misformated HTML; </tr> missing between </td> and <tr>.")
        XCTAssert(result.contains("\(aircraft.registrationWithTailNumberInBrackets)</td>"),
                  "Plane \" \(aircraft.registrationWithTailNumberInBrackets)\" missing from the table.")
        XCTAssertTrue(result.contains("<td>\(lastFlightDate.militaryFormatShort)</td>"),
                      "Line for date \(lastFlightDate.militaryFormatShort) missing from the table.")
        AssertMatch(result, pattern: "<td>\(lastFlightDate.militaryFormatShort)</td><td>(.+?)</td>", expectedValue: "5.0")
    }
    
    
}
