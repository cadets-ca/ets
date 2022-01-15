//
//  CloudKitControllerTests.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2022-01-05.
//

import XCTest
@testable import Timesheets

class CloudKitControllerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    func testPartitionArrayWithDefaultSize()
    {
        let input = Array(repeating: 1, count: 20)

        let result = CloudKitController.partitionArray(input)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.reduce(0, {$0 + $1.count}), input.count)
    }

    func testPartitionArrayWithSmallerSize()
    {
        let size = 10
        let input = Array(repeating: 1, count: 20)

        let result = CloudKitController.partitionArray(input, by: size)

        checkNumberOfPartitionOk(result, input, size)
        checkTotalNumberOfElementMatch(result, input)
    }

    func testPartitionArrayDoNotMissElement()
    {
        let size = 2
        let input = [1,2,3,4,5,6,7,8,9,10]

        let result = CloudKitController.partitionArray(input, by: size)

        checkNumberOfPartitionOk(result, input, size)
        checkTotalNumberOfElementMatch(result, input)
        XCTAssertEqual(result[0][1], 2)
        XCTAssertEqual(result[1][0], 3)
        XCTAssertEqual(result[4][1], 10)
    }

    func checkNumberOfPartitionOk<T>(_ result : [[T]], _ input : [T], _ size : Int)
    {
        XCTAssertEqual(result.count, Int(ceil(Double(input.count) / Double(size))))
    }

    func checkTotalNumberOfElementMatch<T>(_ result : [[T]], _ input : [T])
    {
        XCTAssertEqual(result.reduce(0, {$0 + $1.count}), input.count)
    }

}
