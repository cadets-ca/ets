//
//  TimesheetsUITests.swift
//  TimesheetsUITests
//
//  Created by Paul Kirvan on 2015-08-11.
//
//

import XCTest

class TimesheetsUITests: XCTestCase
{
    var app: XCUIApplication!
    
    override func setUp()
    {
        super.setUp()

        XCUIDevice.shared.orientation = .portrait

        // Put setup code here. This method is called before the invocation of each test method in the class.
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSomething() {
                
    }
}
