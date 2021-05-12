//
//  NDHTMLtoPDF.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-06-20.
//
//

import Foundation
import UIKit
import WebKit

let kPaperSizeA4 = CGSize(width: 595,height: 842)
let kPaperSizeLetter = CGSize(width: 612,height: 792)

protocol NDHTMLtoPDFDelegate
{
    func HTMLtoPDFDidSucceed(_ htmlToPDF: NDHTMLtoPDF)
    func HTMLtoPDFDidFail(_ htmlToPDF: NDHTMLtoPDF)
}

final class NDHTMLtoPDF : UIViewController, WKNavigationDelegate
{
    var delegate: NDHTMLtoPDFDelegate?
    var PDFpath: String?
    var URL: Foundation.URL?
    var HTML: String?
    var webview: WKWebView?
    var pageSize: CGSize
    var pageMargins: UIEdgeInsets
    
    init(URL: Foundation.URL, delegate: NDHTMLtoPDFDelegate, pathForPDF PDFpath: String, pageSize: CGSize, margins pageMargins: UIEdgeInsets)
    {
        self.URL = URL
        self.delegate = delegate
        self.PDFpath = PDFpath
        self.pageMargins = pageMargins
        self.pageSize = pageSize
        
        super.init(nibName: nil, bundle: nil)
        
        if let window = UIApplication.shared.delegate?.window
        {
            window?.addSubview(view)
        }
        
        view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        view.alpha = 0.0
    }
    
    init(HTML: String, delegate: NDHTMLtoPDFDelegate, pathForPDF PDFpath: String, pageSize: CGSize, margins pageMargins: UIEdgeInsets)
    {
        self.HTML = HTML
        self.delegate = delegate
        self.PDFpath = PDFpath
        self.pageMargins = pageMargins
        self.pageSize = pageSize
        super.init(nibName: nil, bundle: nil)

        if let window = UIApplication.shared.delegate?.window
        {
            window?.addSubview(view)
        }
        
        self.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        self.view.alpha = 0.0
    }

    required init(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        webview = WKWebView(frame: view.frame)
        webview?.navigationDelegate = self
        view.addSubview(webview!)
        
        if URL != nil
        {
            webview?.load(URLRequest(url: URL!))
        }
        
        else
        {
            webview?.loadHTMLString(HTML!, baseURL:nil)
        }
    }
    
    class func createPDFWithURL(_ URL: Foundation.URL, pathForPDF PDFpath:String, delegate: NDHTMLtoPDFDelegate, pageSize: CGSize, margins pageMargins: UIEdgeInsets) -> NDHTMLtoPDF
    {
        return NDHTMLtoPDF(URL: URL, delegate: delegate, pathForPDF: PDFpath, pageSize: pageSize, margins: pageMargins)
    }
    
    class func createPDFWithHTML(_ HTML: String, pathForPDF PDFpath:String, delegate: NDHTMLtoPDFDelegate, pageSize: CGSize, margins pageMargins: UIEdgeInsets) -> NDHTMLtoPDF
    {
        return NDHTMLtoPDF(HTML: HTML, delegate: delegate, pathForPDF: PDFpath, pageSize: pageSize, margins: pageMargins)
    }
    
    func webViewDidFinishLoad(_ webView: WKWebView)
    {
        if webView.isLoading
        {
            return
        }
        
        let render = PDF()
        render.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
        let printableRect = CGRect(x: pageMargins.left, y: pageMargins.top, width: pageSize.width - pageMargins.left - pageMargins.right,
        height: pageSize.height - pageMargins.top - pageMargins.bottom)
        let paperRect = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        
        render.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        render.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
        
        let pdfData = render.printToPDF()
        let _ = try? pdfData.write(to: Foundation.URL(fileURLWithPath: PDFpath!),  options: [.atomic])
        terminateWebTask()
        delegate?.HTMLtoPDFDidSucceed(self)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
    {
        if webView.isLoading
        {
            return
        }
        
        terminateWebTask()
        delegate?.HTMLtoPDFDidFail(self)
    }
    
    func terminateWebTask()
    {
        webview?.stopLoading()
        webview?.navigationDelegate = nil
        webview?.removeFromSuperview()
        view.removeFromSuperview()
        webview = nil
    }
}

final class PDF: UIPrintPageRenderer
{
    func printToPDF() -> Data
    {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        prepare(forDrawingPages: NSMakeRange(0, numberOfPages))
        let bounds = UIGraphicsGetPDFContextBounds()
        
        for i in 0 ... numberOfPages
        {
            UIGraphicsBeginPDFPage()
            drawPage(at: i, in: bounds)
        }
        
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
}
