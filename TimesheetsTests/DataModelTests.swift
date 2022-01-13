//
//  DataModelTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2022-01-12.
//

import XCTest
@testable import Timesheets

class DataModelTests: XCTestCase {
    var helpers = CoreDataTestSetupHelpers()
    var pilotOnGlidingCentreTest1 : Pilot?

    override func setUpWithError() throws {

        helpers.setDefaultCentre( helpers.createGlidingCentre("Test1"))
        //_ = helpers.createGlidingCentre("Another")

        pilotOnGlidingCentreTest1 = helpers.createPilot(name: "Test", typeOfParticipant: "COATS")
        dataModel.createAttendanceRecordForPerson(pilotOnGlidingCentreTest1!)

        dataModel.dateToViewRecords = Date().midnight + (-60*60*24)
    }

    override func tearDownWithError() throws {
        helpers.rollback()
    }

    func testGetGlidingCentreForName() throws {
        let gc = dataModel.getGlidingCentre(forName : "XYZ")

        XCTAssertEqual(gc.name, "XYZ")
    }

    func testGetExistingGlidingCentre() throws {
        let gc = dataModel.getGlidingCentre(forName : "Test1")

        XCTAssertEqual(gc.name, "Test1")
        XCTAssertEqual(gc.pilots.first, pilotOnGlidingCentreTest1, "Gliding Centre Test1 is the one having 1 pilot")
    }

    func testGetEmptyGlidingCentre() throws {
        let gc = dataModel.getGlidingCentre(forName: "")

        XCTAssertEqual(gc.name, "Gimli", "The default gliding centre is the first in ascending name order. In our test Gimli comes before Test1")
    }

    func testGetAllGlidingCentre() throws {
        let gcs = dataModel.getGlidingCentres()

        XCTAssertEqual(gcs.count, 2, "If the numbre of Gliding Centres is not 2, that means there have been changes to the data. The two Gliding Centres should be Gimli and Test1. Need investigation: \(gcs)")
    }

}
