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
class ReportGeneratorTests: XCTestCase {
    let centerName = "Test"
    
    var context: NSManagedObjectContext!
    var center: GlidingCentre!
    
    override func setUp() {
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
        dataModel.regionName = "NORTH"
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
        result.forEach { distinctResult[$0.typeOfParticipant] = (distinctResult[$0.typeOfParticipant] ?? 0) + 1 }
        print("Number of distinct value is \(distinctResult.count)")
        for value in distinctResult {
            print("typeOfParticipant \(value)")
        }
    }

    // MARK: - Tests for createAttendanceRecordForPerson
    // TODO: Move this section into its own test file.
    func testCreateAttendanceRecordForPersonSigninPilot() {
        let pilot = Pilot(context: context)
        pilot.name = "John Do"
        pilot.address = "22 Rita"
        pilot.aniversaryOfGliderAPC = Date()
        pilot.aniversaryOfTowAPC = Date()
        pilot.typeOfParticipant = "Tow"
        
        print("Pilot is signed in? \(pilot.signedIn)")
        _ = dataModel.createAttendanceRecordForPerson(pilot)
        
        XCTAssertTrue(pilot.signedIn, "The pilot must now be signed in (as per the post condition of createAttendanceRecordForPerson.")
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
        generator.unit = dataModel.glidingCentre.name // FIXME: Find out why need to set both the generator unit AND pass the parameter siteSpecific=true
        let forDate = Date()
        let result = generator.statsReportFromDate(forDate, toDate: forDate, true)
        
        XCTAssertTrue(result.contains(dataModel.glidingCentre.name), "Our challenge, if we accept it, is to find how we display the centre name instead of the title REGIONAL REPORT.")
    }
            
    // TODO: Never never forget to have some fun on the road to improvement!
    func testStatsReportFromDateIncludeAircraftInReport() {
        // Given

        // When
        
        // Then
                
    }
}
