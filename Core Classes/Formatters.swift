//
//  HtmlStatsReportFromDate.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-10-08.
//

import Foundation
import ExcelExport

struct ReportColumn
{
    var widthPercent : Int? = nil
    var widthPixel : Int? = nil
    var colSpan : Int? = nil
    var title : String
}

struct ReportCell
{
    var rowSpan : Int? = nil
    var value : String = ""
    var isBlack : Bool = false
    var vAlign : VAlign? = nil
}

enum VAlign: String { case bottom, top, middle }

/// This Delegate protocol imply that it ties to the Generator, that only exist in
///  the form of StatsReportFromDateGenerator... Maybe there will be a Generator protocol
///  at a later time.
protocol ReportFormaterDelegate
{
    func success(_ url : URL)
    func fail(_ error : String)
}

protocol StatsReportFromDateFormater
{
    func addTitle(_ title : String)
    func addNewSectionTitle(_ title : String)
    func addBlankLine()
    func addLineOfInfoText(_ info : String)
    func addLineOfText(_ text : String)
    func addText(_ text : String)

    func startTable(_ columnsSet : [[ReportColumn]])
    func startTable(_ columnsSet : [[ReportColumn]], withAlternatingRowColor : Bool)
    func startTable(_ columnsSet : [[ReportColumn]], withAlternatingRowColor : Bool, withInformationText : String?)
    func addTableRow(_ cells : [ReportCell])
    func addTotalRow(_ cells : [ReportCell])
    func endTable()
    
    func result() -> String
    func generate(delegate : ReportFormaterDelegate)
}

extension StatsReportFromDateFormater
{
    func startTable(_ columnsSet : [[ReportColumn]])
    {
        self.startTable(columnsSet, withAlternatingRowColor: false, withInformationText: nil)
    }

    func startTable(_ columnsSet : [[ReportColumn]], withAlternatingRowColor : Bool)
    {
        self.startTable(columnsSet, withAlternatingRowColor: withAlternatingRowColor, withInformationText: nil)
    }
}

class HtmlStatsReportFromDateFormater: StatsReportFromDateFormater
{
    let BG_ALTERNATECOLOR = "#E3E3E3"
    let BG_FILLEDCELL = "#000000"
    let BG_HEADER = "#CCCCCC"
    let BG_FOOTER = "#CCCCCC"

    var report : String = ""
    var isGray = false
    var isAlternatingRowColor = false
    
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
    
    func startTable(_ columnsSet : [[ReportColumn]], withAlternatingRowColor : Bool, withInformationText : String?)
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
                if cell.rowSpan != nil && cell.rowSpan != 1
                {
                    report += " rowspan ='\(cell.rowSpan!)'"
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
                if cell.rowSpan != nil && cell.rowSpan != 1
                {
                    report += " rowspan ='\(cell.rowSpan!)'"
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
    
    func generate(delegate: ReportFormaterDelegate) {
        export{url in
            if let url = url {
                delegate.success(url)
            } else {
                delegate.fail("Cannot create file!")
            }
        }
    }
    
    private func export(_ done: @escaping (URL?)->Void) {
        DispatchQueue.global(qos: .background).async {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("result.html")
            do {
                try self.result().write(to: url, atomically: true, encoding: .utf8)
                DispatchQueue.main.async{ done(url) }
            } catch {
                DispatchQueue.main.async{ done(nil) }
            }
        }
    }

}

class ExcelStatsReportFromDateFormater: StatsReportFromDateFormater
{
    let BG_ALTERNATECOLOR = "#E3E3E3"
    let BG_FILLEDCELL = "#000000"
    let BG_HEADER = "#CCCCCC"
    let BG_FOOTER = "#CCCCCC"
    
    var report : String = ""
    var isGray = false
    var isAlternatingRowColor = false

    var rowsOnCurrentSheet = [ExcelRow]()
    var titleCurrentSheet : String? = nil
    var sheets = [ExcelSheet]()
        
    func addTitle(_ title: String)
    {
        let cells = [ExcelCell(title, [TextAttribute.font([TextAttribute.FontStyle.bold])])]
        rowsOnCurrentSheet.append(ExcelRow(cells))
    }
    
    func addNewSectionTitle(_ title: String)
    {
        endPreviousSectionAndResetAccumulator()
    
        addSectionTitleToWorksheet(title)

        setSectionTitle(title)
    }
    
    func addBlankLine()
    {
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell("")]))
    }
    
    func addLineOfInfoText(_ info: String)
    {
        let cells = [ExcelCell(info)]
        rowsOnCurrentSheet.append(ExcelRow(cells))
    }
    
    func addLineOfText(_ text: String)
    {
        let cells = [ExcelCell(text)]
        rowsOnCurrentSheet.append(ExcelRow(cells))
    }
    
    func addText(_ text: String)
    {
        let cells = [ExcelCell(text)]
        rowsOnCurrentSheet.append(ExcelRow(cells))
    }
    
    func startTable(_ columnsSet: [[ReportColumn]], withAlternatingRowColor: Bool, withInformationText: String?)
    {
        isAlternatingRowColor = withAlternatingRowColor
        isGray = false

        let bgColor = Color(hex: BG_HEADER)!
        
        if let text = withInformationText
        {
            var colSpan = 0
            for columns in columnsSet
            {
                colSpan = colSpan < columns.count ? columns.count : colSpan
            }
            rowsOnCurrentSheet.append(ExcelRow([ExcelCell(text, [], .string, colspan: colSpan)]))
        }
        
        for columns in columnsSet
        {
            var cells = [ExcelCell]()
            for column in columns
            {
                let colSpan = (column.colSpan ?? 1) - 1
                cells.append(ExcelCell(fix(column.title), [TextAttribute.backgroundColor(bgColor)], .string, colspan: colSpan))
            }
            rowsOnCurrentSheet.append(ExcelRow(cells))
        }
    }
    
    func addTableRow(_ cells: [ReportCell])
    {
        var excelCells = [ExcelCell]()
        for cell in cells
        {
            var attribs = [TextAttribute]()
            if cell.isBlack
            {
                attribs.append(TextAttribute.backgroundColor(.black))
            }
            else if isGray
            {
                attribs.append(TextAttribute.backgroundColor(Color(hex: BG_ALTERNATECOLOR)!))
            }
            
            // TODO: Need to add rowspan as well as colSpan...
            let rowSpan : Int? = (cell.rowSpan != nil) ? cell.rowSpan! - 1 : nil
            excelCells.append(ExcelCell(fix(cell.value), attribs, .string, colspan: nil, rowspan: rowSpan))
        }
        rowsOnCurrentSheet.append(ExcelRow(excelCells))
        
        isGray = isAlternatingRowColor ? isGray != isAlternatingRowColor : false
    }
    
    func addTotalRow(_ cells: [ReportCell])
    {
        var excelCells = [ExcelCell]()
        for cell in cells
        {
            var attribs = [TextAttribute]()
            if cell.isBlack
            {
                attribs.append(TextAttribute.backgroundColor(.black))
            }
            else
            {
                attribs.append(TextAttribute.backgroundColor(Color(hex: BG_FOOTER)!))
            }
            
            // TODO: Need to add rowspan as well as colSpan...
            excelCells.append(ExcelCell(cell.value, attribs, .string))
        }
        rowsOnCurrentSheet.append(ExcelRow(excelCells))
    }
    
    func endTable()
    {
    }
    
    func result() -> String
    {
        return ""
    }
    
    func generate(delegate: ReportFormaterDelegate) {
        endPreviousSectionAndResetAccumulator()
        
        // generate the file
        ExcelExport.export(sheets, fileName: "report", done: {url in
            if let url = url {
                delegate.success(url)
            } else {
                delegate.fail("Could not write to file!")
            }
        })
    }
    
    private func endPreviousSectionAndResetAccumulator()
    {
        if let title = titleCurrentSheet {
            sheets.append(ExcelSheet(rowsOnCurrentSheet, name: title))
            
            // clear accumulators
            rowsOnCurrentSheet = [ExcelRow]()
        }
    }
    
    private func addSectionTitleToWorksheet(_ title: String)
    {
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell("")]))
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell(title, [TextAttribute.font([TextAttribute.FontStyle.bold])])]))
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell("")]))
    }
    
    private func setSectionTitle(_ title: String)
    {
        titleCurrentSheet = title
    }
    
    private func fix(_ value : String) -> String
    {
        return value.replacingOccurrences(of: "<br>", with: "&#10;")
    }
}
