//
//  StatsReportFromDateDistributor.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-11-19.
//

import Foundation
import protocol MessageUI.MFMailComposeViewControllerDelegate
import class MessageUI.UIViewController
import class MessageUI.MFMailComposeViewController
import class MessageUI.UIActivityViewController
import class MessageUI.UIActivity
import enum MessageUI.MFMailComposeResult
import struct UIKit.CGRect
import func MobileCoreServices.UTTypeCreatePreferredIdentifierForTag
import func MobileCoreServices.UTTypeCopyPreferredTagWithClass
import var MobileCoreServices.kUTTagClassFilenameExtension
import var MobileCoreServices.kUTTagClassMIMEType

class StatsReportFromDateDistributor : NSObject
{
    private let parentControler : UIViewController?
    private var urls = [URL]()
    private var param : StatsReportFromDateParameters!
    
    class EmailDistributor : StatsReportFromDateDistributor, MFMailComposeViewControllerDelegate
    {
        static private var myself : EmailDistributor?
        static private var picker : MFMailComposeViewController!
        
        override func distribute(_ urls : [URL], for param : StatsReportFromDateParameters)
        {
            EmailDistributor.myself = self
            self.param = param
            self.urls.append(contentsOf: urls)
            
            let picker = MFMailComposeViewController()
            picker.mailComposeDelegate = self
            picker.setSubject(getSubject())
            picker.setToRecipients(getRecipients())
            for url in urls
            {
                if url.pathExtension == "html"
                {
                    picker.setMessageBody(getBody(url), isHTML: true)
                }
                else
                {
                    picker.addAttachmentData((try? Data(contentsOf: url))!, mimeType: getMimeType(for: url), fileName: getFileName(for: url))
                }
            }
            present(picker)
            EmailDistributor.picker = picker
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
        {
            printLog("During mailComposeController: \(result) , \(String(describing: error))")
            controller.presentingViewController?.dismiss(animated: true, completion: nil)
            for url in urls
            {
                do
                {
                    try FileManager.default.removeItem(at: url)
                }
                catch
                {
                    printLog("An error happened!!! \(error)")
                }
            }
            EmailDistributor.myself = nil
            EmailDistributor.picker = nil
        }
        
        private func getSubject() -> String
        {
            var subjectPrefix = ""
            if let centre = self.param.glidingCentre
            {
                subjectPrefix = "\(centre.name) "
            }
            let subjectLine = "\(subjectPrefix)Stats Report \(param.startDate.militaryFormatShort) to \(param.endDate.militaryFormatShort)"
            return subjectLine
        }
        
        private func getRecipients() -> [String]
        {
            return UserDefaults().statsAddressRecipients
        }
        
        private func getFileName(for url : URL) -> String
        {
            if let glidingCentre = param.glidingCentre
            {
                return "\(glidingCentre.name)-Stats-Report-\(param.startDate.militaryFormatShort)-\(param.endDate.militaryFormatShort).\(url.pathExtension)"
            }
            return "Regional-Stats-Report-\(param.startDate.militaryFormatShort)-\(param.endDate.militaryFormatShort).\(url.pathExtension)"
        }
        
        private func getBody(_ url : URL) -> String
        {
            let printWarning = "<b><FONT COLOR='FF0000'>This report is attached as a PDF for easy printing. Please print the attachment, do not print this email message directly.</b></FONT><br><br>"
            let html = (try? String(contentsOf: url)) ?? ""
            return "\(printWarning)\(html)"
        }
        
        private func getMimeType(for url : URL) -> String
        {
            let ext = url.pathExtension as CFString
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, nil)?.takeUnretainedValue(),
                let mimeUTI = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeUnretainedValue()
            {
                return mimeUTI as String
            }
            return ""
        }
    }
    
    class ActivityDistributor : StatsReportFromDateDistributor
    {
        static private var myself : ActivityDistributor?
        private var activity : UIActivityViewController!
        
        override func distribute(_ urls : [URL], for param : StatsReportFromDateParameters)
        {
            activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            activity.title = "ACGP ETS - Share Files"
            activity.completionWithItemsHandler = self.activityCompleted
            if let popOver = activity.popoverPresentationController
            {
                popOver.sourceView = parentControler!.view
                let rect = parentControler!.view.frame
                popOver.sourceRect = CGRect(x: (rect.maxX + rect.minX) / 2, y: rect.minY, width: 10, height: 10)
            }
            present(activity)
            ActivityDistributor.myself = self
        }
        
        private func activityCompleted(_ activityType : UIActivity.ActivityType?, _ completed : Bool, _ returnedItems : [Any]?, _ error : Error?) -> Void
        {
            printLog("Activity completed \(String(describing: activityType)), completed: \(completed), any error? \(String(describing: error))")
            activity = nil
            ActivityDistributor.myself = nil
        }
    }
    
    required init(_ viewController : UIViewController?)
    {
        self.parentControler = viewController
    }
    
    func distribute(_ urls : [URL], for param : StatsReportFromDateParameters)
    {
        // this function must be overriden by subclass of StatsReportFromDateDistributor
    }
    
    private func present(_ viewControler : UIViewController)
    {
        if regularFormat
        {
            printLog("Presenting distribution controler for regularFormat (iPad).")
            parentControler!.dismiss(animated: true, completion: {
                () in
                self.parentControler!.present(viewControler, animated: true, completion: nil)
            })
        }
        else
        {
            printLog("Presenting distribution view controler for regularFormat (iPad).")
            UIViewController.presentOnTopmostViewController(viewControler)
        }
    }
    
    static func getDistributor(withParentView viewController : UIViewController?) -> StatsReportFromDateDistributor
    {
        if MFMailComposeViewController.canSendMail()
        {
            return EmailDistributor(viewController)
        }
        else
        {
            return ActivityDistributor(viewController)
        }
    }
    
}
