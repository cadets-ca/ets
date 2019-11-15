//
//  AttendanceRecordForPersonTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-11-14.
//

import XCTest
import CoreData
@testable import Timesheets

class AttendanceRecordForPersonTests: XCTestCase {
    var helpers = CoreDataTestSetupHelpers()
    var pilotJohnDo : Pilot!
    
    override func setUp() {
        let centre = helpers.createGlidingCentre("Middle Island")
        helpers.setDefaultCentre(centre)

        pilotJohnDo = helpers.createPilot(name: "John Do", typeOfParticipant: "COATS")
    }

    override func tearDown() {
        helpers.rollback()
    }

    func testCreateAttendanceRecordForPersonSigninPilot()
    {
        print("Pilot is signed in? \(pilotJohnDo.signedIn)")
        dataModel.createAttendanceRecordForPerson(pilotJohnDo)
        
        XCTAssertTrue(pilotJohnDo.signedIn, "The pilot must now be signed in (as per the post condition of createAttendanceRecordForPerson.")
    }

}
