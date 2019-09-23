//
//  ReportTransmitter.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-09-21.
//

import Foundation
import MessageUI

class ReportTransmitter: NSObject {
    public class func create() -> ReportTransmitter {
        if MFMailComposeViewController.canSendMail() {
            return EmailReportTransmitter()
        }
        return NullReportTransmitter()
    }
    
    
}

class EmailReportTransmitter: ReportTransmitter, MFMailComposeViewControllerDelegate {
    
}

class NullReportTransmitter: ReportTransmitter {
    
}
