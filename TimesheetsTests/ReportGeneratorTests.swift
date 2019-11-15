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
    var helpers = CoreDataTestSetupHelpers()
    var context: NSManagedObjectContext!
    var centre: GlidingCentre!
    var anotherCenter : GlidingCentre!
    var pilotJoBlack: Pilot!
    var pilotJohnDo: Pilot!
    var staffCadetPilot: Pilot!
    var staffCadetPilot2: Pilot!
    var cadet: Pilot!

    class Handler : ReportFormaterDelegate
    {
        var success = false
        let group : XCTestExpectation!
        var url : URL?
        
        init(_ group : XCTestExpectation)
        {
            self.group = group
        }
        
        func success(_ url: URL) {
            print("success : \(url)")
            self.url = url
            success = true
            group.fulfill()
        }
        
        func fail(_ error: String) {
            print(error)
            success = false
            group.fulfill()
        }
    }

    override func setUp()
    {
        
        dataModel.viewPreviousRecords = true
        dataModel.dateToViewRecords = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        regularFormat = true
        dataModel.regionName = "South"
        centre = helpers.createGlidingCentre("Middle Island")
        anotherCenter = helpers.createGlidingCentre("Pelee Island")

        context = dataModel.managedObjectContext
        helpers.setDefaultCentre(centre)

        dataModel.glidingCentre = centre
        dataModel.previousRecordsGlidingCentre = centre // -TODO: need to confirm if that need to be set.
        
        pilotJoBlack = helpers.createPilot(name: "Jo Black", typeOfParticipant: "COATS")
        dataModel.createAttendanceRecordForPerson(pilotJoBlack)
        helpers.setDefaultPilot(pilotJoBlack)
        
        pilotJohnDo = helpers.createPilot(name: "John Do", typeOfParticipant: "COATS")

        staffCadetPilot = helpers.createStaffCadet(name: "Glider Pilot 1", squadron: 444)
        dataModel.createAttendanceRecordForPerson(staffCadetPilot)
        
        staffCadetPilot2 = helpers.createStaffCadet(name: "Glider Pilot 2", squadron: 618)
        dataModel.createAttendanceRecordForPerson(staffCadetPilot2)

        cadet = helpers.createCadet(name: "A Cadet", squadron: 999)
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
        helpers.rollback()
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
        let forDate = Date()
        let generator = StatsReportFromDate(forDate, toDate: forDate, glidingCentre: dataModel.glidingCentre, regionName: dataModel.regionName!)
        let formatter = HtmlStatsReportFromDateFormater()
        generator.statsReportFromDate(for: formatter)
        let result = formatter.result()
        
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

        let towPlane1 = helpers.createTowPlane(registration: "REG#1", tailNumber: "123")
//        _ = createTowPlane(registration: "REG#2", tailNumber: "3")

        let lastFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-1), to: Date())!
        var timesheet = helpers.createTimesheet(towPlane1, lastFlightDate)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: lastFlightDate, forMinutes: 300)
        
        towPlane1.updateTTSN() // important to updateTTSN after each timesheet created with its flight. Otherwise the time is not adding up properly for the report...

        let middleFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-2), to: Date())!
        timesheet = helpers.createTimesheet(towPlane1, middleFlightDate)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: middleFlightDate, forMinutes: 25, sequence: .Proficiency)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: middleFlightDate, forMinutes: 15, sequence: .Towing)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: middleFlightDate, forMinutes: 65, sequence: .Upgrade)

        towPlane1.updateTTSN()

        let previousFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-3), to: Date())!
        timesheet = helpers.createTimesheet(towPlane1, previousFlightDate)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: previousFlightDate, forMinutes: 5, sequence: .Maintenance)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: previousFlightDate, forMinutes: 20, sequence: .FamPRWx)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: previousFlightDate, forMinutes: 30, sequence: .Transit)
        
        towPlane1.updateTTSN()

        // FIXME: total of 460 minutes in 7 flights... only 6 flights are totalized, but all the minutes are there....
        
        let glider = helpers.createGlider(registration: "Glider", tailNumber: "333")
        let maintenanceEvent = helpers.createMaintenance(for: glider,
                          on: Calendar.current.date(byAdding: Calendar.Component.month, value: -1, to: Date())!,
                          withComment: "Maintenance pour \"\(glider.registrationWithTailNumberInBrackets)\".")
        let maintenanceEvent2 = helpers.createMaintenance(for: glider,
                                                 on: Calendar.current.date(byAdding: Calendar.Component.month, value: -2, to: Date())!,
                                                 withComment: "Something broke on \"\(glider.registrationWithTailNumberInBrackets)\".")
        
        //
        let gliderTakeOffDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-4), to: Date())!
        
        //
        helpers.createLaunch(glider: glider, launcher: towPlane1, takeOffDate: gliderTakeOffDate, withPilot: staffCadetPilot)
        // - TODO: Create another launch for another towplane
        
        // FIXME: total of 480 minutes in 8 flights... only 7 flights are totalized, but all the minutes are there....

        // AUTO LAUNCH
        let gliderLaunchWithAuto = helpers.createGlider(registration: "GliderFromGround", tailNumber: "GCTMT")
        let autoLauncher = helpers.createAutoTow()
        helpers.createLaunch(glider: gliderLaunchWithAuto, launcher: autoLauncher, takeOffDate: gliderTakeOffDate, withPilot: staffCadetPilot)

        // 2 WINCH LAUNCHes
        let gliderLaunchWithWinch = helpers.createGlider(registration: "GliderFromWinch1", tailNumber: "AAAAH")
        let winchLauncher = helpers.createWinchTow(registration: "WINCH", tailNumber: "#1")
        helpers.createLaunch(glider: gliderLaunchWithWinch, launcher: winchLauncher, takeOffDate: gliderTakeOffDate, withPilot: staffCadetPilot)
        let gliderLaunchWithWinch2 = helpers.createGlider(registration: "GliderFromWinch2", tailNumber: "OOOOH")
        let winchLauncher2 = helpers.createWinchTow(registration: "WINCH", tailNumber: "#2")
        helpers.createLaunch(glider: gliderLaunchWithWinch2, launcher: winchLauncher2, takeOffDate: gliderTakeOffDate, withPilot: staffCadetPilot)

        // Upgrade
        let staffUpgradeFrontSeat = helpers.createPilot(name: "Upgrade Pilot 1", typeOfParticipant: "COATS")
        staffUpgradeFrontSeat.dateOfFrontSeatFamilPilot = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        staffUpgradeFrontSeat.highestGliderQual = 3
        let staffUpgradeRearSeat = helpers.createStaffCadet(name: "Upgrade Pilot 2",squadron: 613)
        staffUpgradeRearSeat.dateOfRearSeatFamilPilot = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        staffUpgradeRearSeat.highestGliderQual = 4

        let staffUpgradeRearSeat2 = helpers.createStaffCadet(name: "Upgrade Pilot 3",squadron: 121)
        staffUpgradeRearSeat2.dateOfRearSeatFamilPilot = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        staffUpgradeRearSeat2.highestGliderQual = 4
        staffUpgradeRearSeat2.glidingCentre = anotherCenter

        // When
        let reportDate = Date()
        let generator = ReportGenerator()
        generator.unit = dataModel.glidingCentre.name
        let startDate: Date = reportDate - (5*24*60*60)
        let endDate = reportDate
        
        let result = generator.statsReportFromDate(startDate, toDate: endDate, true)
        let htmlFormater = HtmlStatsReportFromDateFormater()
        let statsReport = StatsReportFromDate(startDate, toDate: endDate, glidingCentre: centre, regionName: dataModel.regionName!)
        statsReport.statsReportFromDate(for: htmlFormater)
        let result2 = htmlFormater.result()
        
        // TODO: The following few lines save values to test later. There is something that modify the properties in the related entities between line 471 and 483. That occured after update to Catalina / XCode Version 11.2 (11B52).
        let towPlane1RegistrationWithTailNumberInBrackets = towPlane1.registrationWithTailNumberInBrackets
        let maintenanceEventComment = maintenanceEvent.comment
        let maintenanceEvent2Comment = maintenanceEvent2.comment
        let gliderLaunchWithAutoRegistrationWithTailNumberInBrackets = gliderLaunchWithAuto.registrationWithTailNumberInBrackets
        log("towPlane1: \(towPlane1.registrationWithTailNumberInBrackets)")

        // ... generate an Excel version of the report and attach it to the test result. This is for visual validation.
        let excelFormater = ExcelStatsReportFromDateFormater()
        statsReport.statsReportFromDate(for: excelFormater)
        let expectation = self.expectation(description: "Excel")
        let handler = Handler(expectation)
        excelFormater.generate(delegate: handler)
        waitForExpectations(timeout: 10, handler: nil)
        if let url = handler.url {
            attachResult(content: url, name: "result")
        }
        log("towPlane1: \(towPlane1.registrationWithTailNumberInBrackets)")

        // Then
        // We start to replace the sync generation by an async generation
        // of the content.
        attachResultAsHtml(data: result, name: "report-\(reportDate).html")
        attachResultAsHtml(data: result2, name: "report2-\(reportDate).html")
        
        XCTAssertFalse(result.contains("</tr><td"), "Oops... misformated HTML; <tr> missing between </tr> and <td>.")
        XCTAssertFalse(result.contains("</td><tr"), "Oops... misformated HTML; </tr> missing between </td> and <tr>.")
        XCTAssertFalse(result.contains("</table></table>"), "Oops... misformated HTML; multiple </table> together.")
        
        XCTAssert(result.contains("\(towPlane1RegistrationWithTailNumberInBrackets)</td>"),
                  "Plane \" \(towPlane1.registrationWithTailNumberInBrackets)\" missing from the table.")
        XCTAssertTrue(result.contains("<td>\(lastFlightDate.militaryFormatShort)</td>"),
                      "Line for date \(lastFlightDate.militaryFormatShort) missing from the table.")
        let aircraftRegWithTailNumberForRegEx = towPlane1RegistrationWithTailNumberInBrackets.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
        AssertMatch(result, pattern: "<tr><td.+?>\(aircraftRegWithTailNumberForRegEx)</td>.+?<td>\(lastFlightDate.militaryFormatShort)</td><td>(.+?)</td>", expectedValue: "5.0")
        XCTAssertTrue(result.contains(maintenanceEventComment), "Oops... \"\(maintenanceEventComment)\" not found.")
        XCTAssertTrue(result.contains(maintenanceEvent2Comment), "Oops... \"\(maintenanceEvent2Comment)\"not found.")
        let registrationWithTailNumberInBracketsForRegEx = gliderLaunchWithAutoRegistrationWithTailNumberInBrackets.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
        AssertMatch(result, pattern: "<tr><td[^>]+?>\(registrationWithTailNumberInBracketsForRegEx)</td>.+?</tr><tr>.+?</tr><tr><td>.+?</td><td>.+?</td><td>(.+?)</td>",
            expectedValue: "1")
        AssertMatch(result, pattern: "(.) winch launches", expectedValue: "2")
        AssertMatch(result, pattern: "(.) auto launches", expectedValue: "1")
    }
    
    func testStatsReportFromDateWithAsyncGenerateCallImplemented()
    {
        let expectation = self.expectation(description: "Generate")
                
        // Given
        let towPlane1 = helpers.createTowPlane(registration: "REG#1", tailNumber: "123")
        _ = helpers.createTowPlane(registration: "REG#2", tailNumber: "3")
        
        let lastFlightDate = Calendar.current.date(byAdding: Calendar.Component.day, value: Int(-1), to: Date())!
        let timesheet = helpers.createTimesheet(towPlane1, lastFlightDate)
        _ = helpers.createFlight(towPlane1, timesheet, startingOn: lastFlightDate, forMinutes: 300)
        
        towPlane1.updateTTSN() // important to updateTTSN after each timesheet created with its flight. Otherwise the time is not adding up properly for the report...

        // When
        let reportDate = Date()
        let report = ReportGenerator()
        report.unit = dataModel.glidingCentre.name
        let startDate = reportDate - (5*24*60*60)
        let endDate = reportDate
        let formatter = ExcelStatsReportFromDateFormater()
        let statsReport = StatsReportFromDate(startDate, toDate: endDate, glidingCentre: centre, regionName: dataModel.regionName!)
        statsReport.statsReportFromDate(for: formatter)
        
        let handler = Handler(expectation)
        formatter.generate(delegate: handler)

        // Then
        waitForExpectations(timeout: 5, handler: {arg in
            print("DONE")
        })

        print("After notify")
        XCTAssertTrue(handler.success)
        if let url = handler.url {
            attachResult(content: url, name: "result")
        }
    }
}
