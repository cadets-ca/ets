//
//  HtmlStatsReportFromDate.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-10-08.
//

import Foundation

struct ReportColumn
{
    var widthPercent : Int? = nil
    var widthPixel : Int? = nil
    var colSpan : Int? = nil
    var title : String
}

struct ReportCell
{
    var rowSpan : Int = 1
    var value : String = ""
    var isBlack : Bool = false
    var vAlign : VAlign? = nil
}

enum VAlign: String { case bottom, top, middle }

class HtmlStatsReportFromDate
{
    let BG_ALTERNATECOLOR = "#E3E3E3"
    let BG_FILLEDCELL = "#000000"
    let BG_HEADER = "#CCCCCC"
    let BG_FOOTER = "#CCCCCC"

    let startDate : Date
    let endDate : Date
    let siteSpecific : Bool
    var report : String = ""
    var isGray = false
    var isAlternatingRowColor = false
    
    init(_ startDate: Date, toDate endDate: Date, _ siteSpecific: Bool = false)
    {
        self.startDate = startDate
        self.endDate = endDate
        self.siteSpecific = siteSpecific
    }
    
    func addTitle(_ title : String)
    {
        report += "<big>\(title)</big><br>"
    }
    
    func addNewSectionTitle(_ title : String)
    {
        report += "<P CLASS='pagebreakhere'>"
        report += "<big>\(title)</big><br>"
        report += "</P>"
    }
    
    func addBlankLine()
    {
        report += "<br>"
    }
    
    func addLineOfInfoText(_ info : String)
    {
        report += "<b>\(info)</b><br>"
    }
    
    func addLineOfText(_ text : String)
    {
        report += text + "<br>"
    }
    
    func addText(_ text : String)
    {
        report += text
    }
    
    func startTable(_ columnsSet : [ReportColumn]..., withAlternatingRowColor : Bool = false, withInformationText : String? = nil)
    {
        isAlternatingRowColor = withAlternatingRowColor
        isGray = false
        report += "<table border='1'>"
        if let withInformationText = withInformationText
        {
            report += "\(withInformationText)<br>"
        }
        for columns in columnsSet
        {
            report += "<tr bgcolor='\(BG_HEADER)'>"
            for column in columns
            {
                if let widthPercent = column.widthPercent
                {
                    report += "<th width ='\(widthPercent)%'>\(column.title)</th>"
                }
                else if let widthPixel = column.widthPixel
                {
                    report += "<th width='\(widthPixel)'>\(column.title)</th>"
                }
                else if let colSpan = column.colSpan
                {
                    report += "<th colspan='\(colSpan)'>\(column.title)</th>"
                }
                else
                {
                    report += "<th>\(column.title)</th>"
                }
            }
            report += "</tr>"
        }
    }
    
    func addTableRow(_ cells : [ReportCell])
    {
        report += isGray ? "<tr bgcolor='\(BG_ALTERNATECOLOR)'>" : "<tr>"
        
        for cell in cells
        {
            report += "<td"
            if cell.isBlack
            {
                report += " bgcolor='\(BG_FILLEDCELL)'></td>"
            }
            else
            {
                if let vAlign = cell.vAlign
                {
                    report += " valign='\(vAlign.rawValue)'"
                }
                if cell.rowSpan != 1
                {
                    report += " rowspan ='\(cell.rowSpan)'"
                }
                report += ">\(cell.value)</td>"
            }
        }
        
        report += "</tr>"
        
        isGray = isAlternatingRowColor ? isGray != isAlternatingRowColor : false
    }
    
    func addTotalRow(_ cells : [ReportCell])
    {
        report += "<tr bgcolor='\(BG_FOOTER)'>"
        
        for cell in cells
        {
            report += "<th"
            if cell.isBlack
            {
                report += " bgcolor='\(BG_FILLEDCELL)'></th>"
            }
            else
            {
                if let vAlign = cell.vAlign
                {
                    report += " valign='\(vAlign.rawValue)'"
                }
                if cell.rowSpan != 1
                {
                    report += " rowspan ='\(cell.rowSpan)'"
                }
                report += ">\(cell.value)</th>"
            }
        }

        report += "</tr>"
    }
    
    func endTable()
    {
        report += "</table>"
    }
    
    func result() -> String
    {
        return "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always}</STYLE><style type='text/css'>td{font-size:8pt;font-family:Helvetica}</style><style type='text/css'>th{font-size:10pt;font-family:Helvetica}</style><title>Stats Report</title></head><body>" +
            report +
        "</body></html>"
    }
}
