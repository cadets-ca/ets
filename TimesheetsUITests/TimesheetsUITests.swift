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
    override func setUp()
    {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    func testAddAircraft()
    {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.tabBars.buttons["Aircraft"].tap()
        
        app.navigationBars["Aircraft"].buttons["Add"].tap()
        
        let vehicles = app.tables.matching(identifier: "List of Vehicles").cells
        
        for vehicle in 0 ..< vehicles.count
        {
            vehicles.element(boundBy: vehicle).tap()
        }
        
        app.navigationBars["Add Aircraft"].buttons["Done"].tap()
        
//        let vehicleOnField = app.tables.matching(identifier: "Aircraft on Field").cells
        
//        while vehicleOnField.count > 0
//        {
//            let rowToRemove = vehicleOnField.count > 5 ? UInt(arc4random_uniform(5)) : 0
//            vehicleOnField.element(boundBy: rowToRemove).swipeLeft()
//            vehicleOnField.element(boundBy: rowToRemove).buttons["Remove"].tap()
//        }
        
        app.navigationBars["Aircraft"].buttons["Add"].tap()
        
        app.tables["List of Vehicles"].cells["GCLD"].tap()
        app.tables["List of Vehicles"].cells["FFDR"].tap()
        app.tables["List of Vehicles"].cells["GOBW"].tap()
        app.tables["List of Vehicles"].cells["GRFQ"].tap()
        app.tables["List of Vehicles"].cells["GRVH"].tap()
        app.tables["List of Vehicles"].cells["GMOG"].tap()
        app.tables["List of Vehicles"].cells["GSSV"].tap()
        app.tables["List of Vehicles"].cells["GQNQ"].tap()
    }
    
    func scratch()
    {
        
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
}
