//
//  XCTestExtensions.swift
//  TimesheetsTests
//
//  Created by Hugues Ferland on 2019-10-03.
//

import Foundation
import XCTest

extension XCTest {
    func AssertMatch(_ content: String, pattern: String, expectedValue: String, file: StaticString = #file, line: UInt = #line)
    {
        do
        {
            // We create the regular expression that might fail...
            let regEx = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            // We find the first match for the given regular expression in the complete content...
            if let match = regEx.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.count)),
                match.numberOfRanges >= 2,
                let stringMatchedRange = Range(match.range, in: content),
                let valueFoundRange = Range(match.range(at: 1), in: content)
            {
                let stringMatched = content[stringMatchedRange]
                let valueFound = content[valueFoundRange]
                XCTAssertTrue( String(valueFound) == expectedValue,
                               """
                    Found value of \"\(valueFound)\" in \"\(stringMatched)\" that don't match the expected value of \"\(expectedValue).\".
                    Using the pattern \"\(pattern)\"
                    """, file: file, line: line)
            }
            else
            {
                XCTFail("Nothing match \"\(pattern)\" or no capture group defined.", file: file, line: line)
            }
        }
        catch let error as NSError
        {
            XCTFail("The test is not valid because of an error in the pattern \"\(pattern)\"; \(error.localizedRecoverySuggestion ?? error.description)", file: file, line: line)
        }
    }
    
    func log(_ msg: String, file: StaticString = #file, line: UInt = #line)
    {
        print("#\(line) : \(msg)")
    }
}

extension XCTestCase
{
    var isAttachmentAvailable : Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    /**
     This method attach the `data` as an html content to the current test.
     */
    func attachResultAsHtml(data: String, name: String)
    {
        if self.isAttachmentAvailable
        {
            let attachment = XCTAttachment(data: data.data(using: .utf16)!, uniformTypeIdentifier: "html")
            attachment.name = name
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }
    
    /**
     This method attach the content pointed to by the URL to the current test.
     */
    func attachResult(content: URL, name: String)
    {
        if self.isAttachmentAvailable
        {
            let attachment = XCTAttachment(contentsOfFile: content)
            attachment.name = name
            attachment.lifetime = .keepAlways
            self.add(attachment)
        }
    }
}
