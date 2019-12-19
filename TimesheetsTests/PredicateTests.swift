//
//  PredicateTests.swift
//  TimesheetsTests
//
//  Created by Ferland JCH Hugues on 2019-12-19.
//

import Timesheets
import Foundation
import XCTest

class PredicateTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBetweenDates() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let endOfDay = Calendar.current.date(byAdding: .nanosecond, value: -60, to: startOfNextDay)!
        let endOfPreviousDay = Calendar.current.date(byAdding: .nanosecond, value: -60, to: startOfDay)!

        let dateArray = [startOfDay,
                         Calendar.current.date(byAdding: .hour, value: 12, to: startOfDay),
                         endOfPreviousDay,
                         startOfNextDay,
                         endOfDay]
        let predicate = NSPredicate(format: "SELF >= %@ AND SELF < %@", argumentArray: [startOfDay, startOfNextDay])
        
        print("Date Array: \(dateArray) will be filtered for dates between \(startOfDay) and \(endOfDay) inclusively.")
        let filteredArray = dateArray.filter {predicate.evaluate(with:$0) }
        print("Filtered Date Array: \(filteredArray)")
        XCTAssert(filteredArray.contains(startOfDay))
        XCTAssert(filteredArray.contains(endOfDay))
        XCTAssert(!filteredArray.contains(startOfNextDay))
        XCTAssert(!filteredArray.contains(endOfPreviousDay))
    }
}
