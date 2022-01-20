//
//  TimesheetsUITests.swift
//  TimesheetsUITests
//
//  Created by Paul Kirvan on 2015-08-11.
//
//

import XCTest

// This test currently only works with specific combination of iPhone and MacOS:
// - iPhone 8 (14.3) on MacOs 10.15 (used on GitHub)
// - iPhone 8 (15.2) on MacOS 11.6.2
class TimesheetsUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()

        XCUIDevice.shared.orientation = .portrait

        continueAfterFailure = false
    }

    override func tearDown() {

        super.tearDown()
    }

    func testNewVersion() {

        ETS()
            .launch()
            .showPilotsTab()
                .showPilotOptions()
                    .startSigningPilot()
                        .startAddNewPilot()
                            .fillInTestPilot(pilotFirstName : "Julie", pilotLastName : "Test")
                            .done()
                        .back()
                    .done()
                .assertTestPilotExists(withExpectedName : "Test, Julie")

    }

    class ETS {
        var app : XCUIApplication

        init() {
            app = XCUIApplication()
        }

        func launch() -> ETS {
            app.launch()
            return self
        }

        func showPilotsTab() -> ETS.PilotsTab {
            app.tabBars["Tab Bar"].buttons["Pilots"].tap()
            return PilotsTab(app)
        }

        class PilotsTab {
            var app : XCUIApplication

            init(_ app : XCUIApplication) {
                self.app = app
            }

            func showPilotOptions() -> PilotsOptions {
                app.navigationBars["Pilots"].buttons["Share"].tap()
                return PilotsOptions(app)
            }

            func assertTestPilotExists(withExpectedName expectedName : String) {
                XCTAssertTrue(app.tables.cells.staticTexts[expectedName].exists, "Test user \(expectedName) does not display in the list of signed in pilots.")
            }
        }

        class PilotsOptions {
            var app : XCUIApplication

            init(_ app : XCUIApplication) {
                self.app = app
            }

            func startSigningPilot() -> SignInPilot {
                let tablesQuery = app.tables
                tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Sign in Pilot"]/*[[".cells.staticTexts[\"Sign in Pilot\"]",".staticTexts[\"Sign in Pilot\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
                return SignInPilot(app)
            }

            func done() -> PilotsTab {
                app.navigationBars["Pilot Options"].buttons["Done"].tap()
                return PilotsTab(app)
            }
        }

        class SignInPilot {
            var app : XCUIApplication

            init(_ app : XCUIApplication) {
                self.app = app
            }

            func startAddNewPilot() -> NewPilot {
                let addPilotNavigationBar = app.navigationBars["Add Pilot"]
                addPilotNavigationBar.buttons["Add"].tap()
                return NewPilot(app)
            }

            func back() -> PilotsOptions {
                let addPilotNavigationBar = app.navigationBars["Add Pilot"]
                addPilotNavigationBar.buttons["Pilot Options"].tap()
                return PilotsOptions(app)
            }
        }

        class NewPilot {
            var app : XCUIApplication
            init(_ app : XCUIApplication) {
                self.app = app
            }

            func fillInTestPilot(pilotFirstName : String, pilotLastName : String) -> NewPilot {
                let lastName = app.tables.cells.containing(.staticText, identifier:"Last Name").textFields["Type Name Here"]
                lastName.tap()
                lastName.typeText(pilotLastName)
                let firstName = app.tables.cells.containing(.staticText, identifier:"First Name").textFields["Type Name Here"]
                firstName.tap()
                firstName.typeText(pilotFirstName)

                let emailAddress = app.tables.textFields["Type Address Here"]
                emailAddress.tap()
                emailAddress.typeText("t@t.com")

                let squadron = app.tables.textFields["Type Squadron Here"]
                squadron.tap()
                squadron.typeText("613")

                return self
            }

            func done() -> SignInPilot {
                let doneButton = app.navigationBars["Test"].buttons["Done"]
                doneButton.tap()
                return SignInPilot(app)
            }
        }
    }

}
