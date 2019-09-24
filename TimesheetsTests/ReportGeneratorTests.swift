//
//  TimesheetsTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-09-23.
//

import XCTest
@testable import Timesheets

/// This test class will be used to compare actual output for report to new output. The major goal is to refactor report generation to allow testing and separate
/// reporting, data extract, and sharing of reporting results
class ReportGeneratorTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testReportGeneratorResultIsHTML() {
        let generator = ReportGenerator()
        
        let result = generator.generateTimesheetsForDate(Date())
        
        XCTAssert(result.hasPrefix("<html>"), "This is not html?")
        XCTAssert(result.hasSuffix("</html>"), "This is not html?")
    }
    
    func testReportGeneratorContainsFlight() {
        
    }

}
