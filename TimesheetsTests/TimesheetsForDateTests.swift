//
//  TimesheetsForDateTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-11-23.
//

import XCTest
@testable import Timesheets

class TimesheetsForDateTests: XCTestCase {

    let helpers = CoreDataTestSetupHelpers()

    var pilotJohnDo : Pilot!
    var centre : GlidingCentre!
    
    override func setUp() {
        centre = helpers.createGlidingCentre("Middle Island")
        helpers.setDefaultCentre(centre)
        
        pilotJohnDo = helpers.createPilot(name: "John Do", typeOfParticipant: "COATS")
    }

    override func tearDown() {
        helpers.rollback()
    }

    func testTimesheetsReport() {
        let now = Calendar.current.date(from: DateComponents(year: 2015, month: 11, day: 30, hour: 13, minute: 43))!
        
        // arrange
        let aircraft = helpers.createTowPlane(registration: "123", tailNumber: "123")
        let timesheet = helpers.createTimesheet(aircraft, now)
        let timesheet2 = helpers.createTimesheet(aircraft, now)
        let towFlight = helpers.createFlight(aircraft, timesheet, startingOn: Calendar.current.date(byAdding: .hour, value: -1, to: now)!, forMinutes: 10)
        _ = helpers.createFlight(aircraft, timesheet2, startingOn: Calendar.current.date(byAdding: .hour, value: -2, to: now)!, forMinutes: 10)

        let towSolo = helpers.createTowPlane(registration: "ALONE", tailNumber: "8888")
        let towSoloTimesheet = helpers.createTimesheet(towSolo, now)
        var startingOn: Date = Calendar.current.date(byAdding: .hour, value: -11, to: now)!
        for i in 1...90
        {
            var sequence: TowplaneSequence
            switch (i % 7)
            {
                case 0:
                    sequence = TowplaneSequence.FamPRWx
                case 1:
                    sequence = TowplaneSequence.Maintenance
                case 2:
                    sequence = TowplaneSequence.Proficiency
                case 3:
                    sequence = TowplaneSequence.TowCourse
                case 4:
                    sequence = TowplaneSequence.Towing
                case 5:
                    sequence = TowplaneSequence.Transit
                case 6:
                    sequence = TowplaneSequence.Upgrade
                default:
                    sequence = TowplaneSequence.FamPRWx
            }
            _ = helpers.createFlight(towSolo, towSoloTimesheet, startingOn: startingOn, forMinutes: 10 /* 4 hours */, sequence: sequence)
            startingOn = Calendar.current.date(byAdding: .minute, value: 12, to: startingOn)!
        }
        
        let glider = helpers.createGlider(registration: "GL1", tailNumber: "111")
        let gliderTimesheet = helpers.createTimesheet(glider, now)
        for _ in 1...60
        {
            _ = helpers.createGliderFlight(glider, gliderTimesheet, startingOn: Calendar.current.date(byAdding: .hour, value: -1, to: now)!,
                                           forMinutes: 20, withPilot: pilotJohnDo, towByFlight: towFlight)
        }
        
        let auto = helpers.createAutoTow()
        let autoTimesheet = helpers.createTimesheet(auto, now)
        let autoStartAt: Date = Calendar.current.date(byAdding: .hour, value: -2, to: now)!
        let autoFlight = helpers.createFlight(auto, autoTimesheet, startingOn: autoStartAt, forMinutes: 5)
        _ = helpers.createGliderFlight(glider, gliderTimesheet, startingOn: autoStartAt, forMinutes: 20,
                                       sequence: GliderSequence.Proficiency, towByFlight: autoFlight)

        let winch = helpers.createWinchTow(registration: "WINCH", tailNumber: "#1")
        let winchTimesheet = helpers.createTimesheet(winch, now)
        let winchStartAt: Date = Calendar.current.date(byAdding: .hour, value: -3, to: now)!
        let winchFlight = helpers.createFlight(winch, winchTimesheet, startingOn: winchStartAt, forMinutes: 5)
        _ = helpers.createGliderFlight(glider, gliderTimesheet, startingOn: winchStartAt, forMinutes: 25, towByFlight: winchFlight)
        
        // act
        
        // Old version of the timesheet report...
        // We are keeping it until we are sure the new is good
        let report = ReportGenerator()
        report.unit = centre.name    // needed to show the current site (Gliding Unit)
        report.regionName = "SOUTH"  // needed to show the region
        let result = report.generateTimesheetsForDate(now, true)
        attachResultAsHtml(data: result, name: "timesheets.html")
        
        // new timesheet report.
        let param = TimesheetsForDateParameters(dateOfTimesheets: now, glidingCentre: centre, regionName: "SOUTH", includeChangeLog: false)
        let timesheetForDate = TimesheetsForDate(param)
        let formatter = HtmlFormatter()
        timesheetForDate.generate(with: formatter)
        let newResult = formatter.result()
        attachResultAsHtml(data: newResult, name: "newTimesheets.html")
        
        let expectation = self.expectation(description: "Generate")
        var rcvdUrl : URL?
        let excelFormatter = ExcelFormatter()
        timesheetForDate.generate(with: excelFormatter)
        excelFormatter.generateResult(filename: "timesheets-excel")
        {
            (url) in
            rcvdUrl = url
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        // assert
        // what should I assert for... ?
        XCTAssert(newResult.contains("2 of 2"), "There should be a section where there is a 2nd page of a 2 pages section.")
        XCTAssert(newResult.contains("3 of 3"), "There should be a section where there is a 3rd page of a 3 pages section.")
        // must manually check if the page break happens at the right place. They are all managed by CSS now.
        if let url = rcvdUrl
        {
            attachResult(content: url, name: url.lastPathComponent)
        }
        else
        {
            XCTFail("Did not received a valid URL from the Excel formatter.")
        }
    }
    
    func testTransitInReport()
    {
        // TODO: Need to change the data to make it more realistic!
        let now = Calendar.current.date(from: DateComponents(year: 2015, month: 11, day: 30, hour: 13, minute: 43))!
        let transitRoute = "YUL"
        
        // Arrange
        let towplane = helpers.createTowPlane(registration: "TOW", tailNumber: "123")
        let timesheet = helpers.createTimesheet(towplane, now)

        let towFlight = helpers.createFlight(towplane, timesheet, startingOn: Calendar.current.date(byAdding: .hour, value: -1, to: now)!, forMinutes: 10, sequence: TowplaneSequence.Towing )
        towFlight.transitRoute = "XYZ"  // this should not appear anywhere
        
        let glider = helpers.createGlider(registration: "GLIDER", tailNumber: "000")
        let gliderTimesheet = helpers.createTimesheet(glider, now)
        let connectedFlight = helpers.createGliderFlight(glider, gliderTimesheet, startingOn: Calendar.current.date(byAdding: .hour, value: -3, to: now)!, forMinutes: 120, sequence: GliderSequence.Transit, towByFlight: towFlight)
        connectedFlight.transitRoute = transitRoute
        
        // Act
        // ... for comparison
        let report = ReportGenerator()
        report.unit = centre.name    // needed to show the current site (Gliding Unit)
        report.regionName = "SOUTH"  // needed to show the region
        let result = report.generateTimesheetsForDate(now, false)
        attachResultAsHtml(data: result, name: "oldTimesheets.html")

        // ... used for assert below
        let param = TimesheetsForDateParameters(dateOfTimesheets: now, glidingCentre: centre, regionName: "SOUTH", includeChangeLog: false)
        let timesheetForDate = TimesheetsForDate(param)
        let formatter = HtmlFormatter()
        timesheetForDate.generate(with: formatter)
        let newResult = formatter.result()
        attachResultAsHtml(data: newResult, name: "newTimesheets.html")

        // ... for manual testing purpose
        let expectation = self.expectation(description: "Generate")
        let excelFormatter = ExcelFormatter()
        timesheetForDate.generate(with: excelFormatter)
        excelFormatter.generateResult({url in
            if let url = url
            {
                self.attachResult(content: url, name: "excelNewTimesheets")
            }
            expectation.fulfill() // this expectation fulfilling will let the test complete (see below waitForExpectation)
        })
        
        // Assert
        let towplaneExpectedSequence = "\(TowplaneSequence.Towing.abbreviation) \(transitRoute)"
        XCTAssert(newResult.contains(towplaneExpectedSequence), "Was expecting sequence \(towplaneExpectedSequence)... none found.")
        let gliderExpectedSequence = "\(GliderSequence.Transit.abbreviation) \(transitRoute)"
        XCTAssert(newResult.contains(gliderExpectedSequence), "Was expecting sequence \(gliderExpectedSequence)... none found.")
        
        // necessary to ensure the Excel version is also properly attached to the test result
        waitForExpectations(timeout: 10, handler: nil)
    }
}
