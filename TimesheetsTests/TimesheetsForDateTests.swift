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

    func testOldReport() {
        let now = Calendar.current.date(from: DateComponents(year: 2015, month: 11, day: 30, hour: 13, minute: 43))!
        
        // arrange
        let aircraft = helpers.createTowPlane(registration: "123", tailNumber: "123")
        let timesheet = helpers.createTimesheet(aircraft, now)
        let towFlight = helpers.createFlight(aircraft, timesheet, startingOn: Calendar.current.date(byAdding: .hour, value: -1, to: now)!, forMinutes: 10)
        
        let towSolo = helpers.createTowPlane(registration: "ALONE", tailNumber: "8888")
        let towSoloTimesheet = helpers.createTimesheet(towSolo, now)
        var startingOn: Date = Calendar.current.date(byAdding: .hour, value: -11, to: now)!
        for _ in 1...60
        {
            _ = helpers.createFlight(towSolo, towSoloTimesheet, startingOn: startingOn, forMinutes: 10 /* 4 hours */)
            startingOn = Calendar.current.date(byAdding: .minute, value: 12, to: startingOn)!
        }
        
        let glider = helpers.createGlider(registration: "GL1", tailNumber: "111")
        let gliderTimesheet = helpers.createTimesheet(glider, now)
        _ = helpers.createGliderFlight(glider, gliderTimesheet, startingOn: Calendar.current.date(byAdding: .hour, value: -1, to: now)!, forMinutes: 20, withPilot: pilotJohnDo, towByFlight: towFlight)

        let auto = helpers.createAutoTow()
        let autoTimesheet = helpers.createTimesheet(auto, now)
        let autoStartAt: Date = Calendar.current.date(byAdding: .hour, value: -2, to: now)!
        let autoFlight = helpers.createFlight(auto, autoTimesheet, startingOn: autoStartAt, forMinutes: 5)
        helpers.createGliderFlight(glider, gliderTimesheet, startingOn: autoStartAt, forMinutes: 20, towByFlight: autoFlight)

        let winch = helpers.createWinchTow(registration: "WINCH", tailNumber: "#1")
        let winchTimesheet = helpers.createTimesheet(winch, now)
        let winchStartAt: Date = Calendar.current.date(byAdding: .hour, value: -3, to: now)!
        let winchFlight = helpers.createFlight(winch, winchTimesheet, startingOn: winchStartAt, forMinutes: 5)
        helpers.createGliderFlight(glider, gliderTimesheet, startingOn: winchStartAt, forMinutes: 25, towByFlight: winchFlight)
        
        // act
        let report = ReportGenerator()
        report.unit = centre.name    // needed to show the current site (Gliding Unit)
        report.regionName = "SOUTH"  // needed to show the region
        let result = report.generateTimesheetsForDate(now, true)
        //try? result.write(toFile: "timesheets.html", atomically: true, encoding: .utf8)
        attachResultAsHtml(data: result, name: "timesheets.html")
        
        // assert
        
    }

}
