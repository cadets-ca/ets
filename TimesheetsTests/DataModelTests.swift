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

    func testGetExistingGlidingCentreReturnTheOneWeCreatedInSetup() throws {
        let gc = dataModel.getGlidingCentre(forName : "Test1")

        // A gliging centre does not have much to check if it is indeed what we are looking. That's why, in the
        // setup method above, we attached a pilot to the center, so we can check both the name and the attached pilot
        // in our assertion.
        XCTAssertEqual(gc.name, "Test1")
        XCTAssertEqual(gc.pilots.first, pilotOnGlidingCentreTest1, "Gliding Centre Test1 is the one having 1 pilot")
    }

    func testGetEmptyGlidingCentreReturnTheFirstGlidingCentre() throws {
        // This test is to confirm we get the gliding centre identified as the first gliding centre when
        // we have no names. The getGlidingCentre [should] guarantee the gliding centre return in that circumtance
        // is the same as what is returned by getFirstGlidingCentre (what ever that gliging centre is).
        let gc = dataModel.getGlidingCentre(forName: "")

        XCTAssertEqual(gc.name, dataModel.getFirstGlidingCentre(using: dataModel.managedObjectContext).name, "The default gliding centre is the first in ascending name order. In our test Gimli comes before Test1")
    }

    func testGetAllGlidingCentre() throws {
        // The method getGlidingCentres is there mainly for validation purpose (not a best practice but given the
        // situation, the best I could come up with).
        let gcs = dataModel.getGlidingCentres()

        XCTAssertTrue(gcs.contains(where: { (gc) in gc.name == "Test1"}))
    }

}
