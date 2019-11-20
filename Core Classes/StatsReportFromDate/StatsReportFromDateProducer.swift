//
//  StatsReportFromDateProducer.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-11-19.
//

import Foundation
import struct UIKit.UIEdgeInsets
import struct UIKit.CGSize

class StatsReportFromDateProducer : NSObject, NDHTMLtoPDFDelegate
{
    typealias CompletionHandler = () -> Void
    
    var urls = [URL]()
    let param : StatsReportFromDateParameters
    var html : String?
    var pdfGenerator : NDHTMLtoPDF?
    var completionHandler : CompletionHandler?
    
    init(_ param : StatsReportFromDateParameters)
    {
        self.param = param
    }
    
    func produce( then : @escaping CompletionHandler )
    {
        self.completionHandler = then
        
        let excelFormatter = ExcelFormatter()
        
        let report = StatsReportFromDate(param)
        report.generate(with: excelFormatter)
        
        excelFormatter.generateResult(filename: getFileName()) {
            url in
            if let url = url {
                self.urls.append(url)
            }
            let htmlFormatter = HtmlFormatter()
            report.generate(with: htmlFormatter)
            htmlFormatter.generateResult(filename: self.getFileName()) {
                url in
                if let url = url {
                    self.urls.append(url)
                    
                    let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
                    let pathForPDF = pathArray.first?.stringByAppendingPathComponent("\(self.getFileName()).pdf") ?? ""
                    self.pdfGenerator = NDHTMLtoPDF.createPDFWithURL(url, pathForPDF: pathForPDF, delegate:self, pageSize:CGSize(width: 612,height: 792), margins:UIEdgeInsets.init(top: 30, left: 30, bottom: 30, right: 30))
                }
                else
                {
                    then()
                }
            }
        }
    }
    
    func distributeProducts(using distributor : StatsReportFromDateDistributor)
    {
        distributor.distribute(self.urls, for: param)
    }
    
    func HTMLtoPDFDidSucceed(_ htmlToPDF: NDHTMLtoPDF)
    {
        keepGeneratedFile(htmlToPDF)
        complete()
        self.pdfGenerator = nil
    }
    
    func HTMLtoPDFDidFail(_ htmlToPDF: NDHTMLtoPDF)
    {
        complete()
        self.pdfGenerator = nil
    }
    
    private func keepGeneratedFile(_ htmlToPDF: NDHTMLtoPDF) {
        if let path = htmlToPDF.PDFpath
        {
            printLog("Succeeded PDF generation : \(path)")
            urls.append(URL(fileURLWithPath: path))
        }
        else
        {
            printLog("Succeeded PDF generation, but no file provided.")
        }
    }
    
    private func complete()
    {
        if let completionHandler = self.completionHandler
        {
            printLog("Calling completionHandler.")
            completionHandler()
        }
        else
        {
            printLog("No completion handler")
        }
    }
    
    private func getFileName() -> String
    {
        if let glidingCentre = param.glidingCentre
        {
            return "\(glidingCentre.name)-Stats-Report-\(param.startDate.militaryFormatShort)-\(param.endDate.militaryFormatShort)"
        }
        return "Regional-Stats-Report-\(param.startDate.militaryFormatShort)-\(param.endDate.militaryFormatShort)"
    }
}

