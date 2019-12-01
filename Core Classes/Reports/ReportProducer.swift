//
//  StatsReportFromDateProducer.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-11-19.
//

import Foundation
import struct UIKit.UIEdgeInsets
import struct UIKit.CGSize

/**
 Protocol to be implemented by any reports.
 */
protocol Report : SubjectProvider
{
    func generate(with formatter: ReportFormatter)
}

/**
 The producer has the responsibility to take a report and generate it to any format it sees fit.
 
 Once the report is generated in the formats required, it will call the CompletionHandler. This call will likely happen on a different thread then the one where the report was originally generated.
 
 It is important to note this class is an accumulator of result files generated from the same Report class: the same instance should not be used to produce two different report, while that could absolutely be possible.
 */
class ReportProducer : NSObject, NDHTMLtoPDFDelegate
{
    typealias CompletionHandler = ([URL]) -> Void
    
    private var urls = [URL]()
    private var pdfGenerator : NDHTMLtoPDF?
    private var completionHandler : CompletionHandler?
    
    func produce( report : Report, then : @escaping CompletionHandler )
    {
        self.completionHandler = then
        
        let excelFormatter = ExcelFormatter()
        report.generate(with: excelFormatter)
        
        excelFormatter.generateResult(filename: report.getSubject()) {
            url in
            if let url = url {
                self.urls.append(url)
            }
            let htmlFormatter = HtmlFormatter()
            report.generate(with: htmlFormatter)
            htmlFormatter.generateResult(filename: report.getSubject()) {
                url in
                if let url = url {
                    self.urls.append(url)
                    
                    let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
                    let pathForPDF = pathArray.first?.stringByAppendingPathComponent("\(report.getSubject()).pdf") ?? ""
                    self.pdfGenerator = NDHTMLtoPDF.createPDFWithURL(url, pathForPDF: pathForPDF, delegate:self, pageSize:CGSize(width: 612,height: 792), margins:UIEdgeInsets.init(top: 30, left: 30, bottom: 30, right: 30))
                }
                else
                {
                    then(self.urls)
                }
            }
        }
    }
    
    // MARK: - NDHTMLtoPDFDelegate protocol implementation
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
    
    // MARK: - private utility functions
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
            completionHandler(urls)
        }
        else
        {
            printLog("No completion handler")
        }
    }
}

