//
//  HtmlStatsReportFromDate.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-10-08.
//

import Foundation
import ExcelExport

private let VAR_CURRENT_PAGE = "{{currentPage}}"
private let VAR_NUMBER_OF_PAGE = "{{numberOfPage}}"

fileprivate func replaceCurrentPage(with page : Int, in value : String) -> String
{
    var newValue = value
    if let varRange = newValue.range(of: VAR_CURRENT_PAGE)
    {
        newValue.replaceSubrange(varRange, with: "\(page)")
    }
    return newValue
}

fileprivate func replaceNumberOfPage(with numberOfPage : Int, in value : String) -> String
{
    var newValue = value
    if let varRange = newValue.range(of: VAR_NUMBER_OF_PAGE)
    {
        newValue.replaceSubrange(varRange, with: "\(numberOfPage)")
    }
    return newValue
}

struct ReportColumn
{
    
    var widthPercent : Int? = nil
    var widthPixel : Int? = nil
    var colSpan : Int? = nil
    var rowSpan : Int? = nil
    var title : String
}

struct ReportCell
{
    var rowSpan : Int? = nil
    var colSpan : Int? = nil
    var value : String = ""
    var isBlack : Bool = false
    var vAlign : VAlign? = nil
}

enum VAlign: String { case bottom, top, middle }

/// This Delegate protocol imply that it ties to the Generator, that only exist in
///  the form of StatsReportFromDateGenerator... Maybe there will be a Generator protocol
///  at a later time.
protocol ReportFormatterDelegate
{
    func success(_ url : URL)
    func fail(_ error : String)
}

protocol ReportFormatter
{
    func setReportTitle(_ title : String)
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
    func startPaginatedSection()
    func startRepeatingPart()
    func endRepeatingPart(_ todoBeforeNextPage : @escaping (ReportFormatter) -> Void)
    func endPaginatedSection()

    func result() -> String
    // TODO: my goal is to valiate which one is best and remove the unwanted one between generateResult(delegate) and generateResult(handler).
    func generateResult(filename : String, _ delegate : ReportFormatterDelegate)
    func generateResult(filename : String, _ handler : @escaping (URL?)->Void)
}

extension ReportFormatter
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

class HtmlFormatter: ReportFormatter
{
    let BG_ALTERNATECOLOR = "#E3E3E3"
    let BG_FILLEDCELL = "#000000"
    let BG_HEADER = "#CCCCCC"
    let BG_FOOTER = "#CCCCCC"

    private var report : String = ""
    private var isGray = false
    private var isAlternatingRowColor = false
    private var pageCount = 0 // used for page break not on first report page.
    
    private var title = ""
    
    // Following variables are used for paginated section
    private var currentPage = 0
    private var numberOfRowPerPage = 35
    private var currentNumberOfRow = 0
    private var todoBeforeNextPage : ((ReportFormatter) -> Void)!
    
    private var reportBeforePaginatedSection = ""
    private var repeatingPart = ""

    func setReportTitle(_ title : String)
    {
        self.title = title
    }
    
    func addTitle(_ title : String)
    {
        report += "<big>\(title)</big><br>"
    }
    
    func addNewSectionTitle(_ title : String)
    {
        report += pageCount == 0 ? "<P>" : "<P CLASS='pagebreakhere'>"
        report += "<big>\(title)</big><br>"
        report += "</P>"
        pageCount += 1        
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
                report += "<th"
                if let widthPercent = column.widthPercent
                {
                    report += " width ='\(widthPercent)%'"
                }
                else if let widthPixel = column.widthPixel
                {
                    report += " width='\(widthPixel)'"
                }
                if let colSpan = column.colSpan
                {
                    report += " colspan='\(colSpan)'"
                }
                if let rowSpan = column.rowSpan
                {
                    report += " rowspan='\(rowSpan)'"
                }
                report += ">\(column.title)</th>"
            }
            report += "</tr>"
        }
    }
    
    func addTableRow(_ cells : [ReportCell])
    {
        pageBreakIfNeeded()

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
                if let rowSpan = cell.rowSpan,
                    rowSpan != 1
                {
                    report += " rowspan='\(cell.rowSpan!)'"
                }
                if let colSpan = cell.colSpan
                {
                    report += " colspan='\(colSpan)'"
                }
                report += ">\(cell.value)</td>"
            }
        }
        
        report += "</tr>"
        
        currentNumberOfRow += 1
        
        isGray = isAlternatingRowColor ? isGray != isAlternatingRowColor : false
    }
    
    func addTotalRow(_ cells : [ReportCell])
    {
        pageBreakIfNeeded()

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
                if let rowSpan = cell.rowSpan,
                    rowSpan != 1
                {
                    report += " rowspan ='\(cell.rowSpan!)'"
                }
                if let colSpan = cell.colSpan
                {
                    report += " colspan='\(colSpan)'"
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

    func startPaginatedSection()
    {
        // TODO: create a mecanism to keep what repeat on each page and keep the page numbering
        // TODO: numbering mecanism will use variable to replace text in cells
        // TODO: currentPage and numberOfPage
        currentPage = 1
        currentNumberOfRow = 0
    }
    
    func startRepeatingPart()
    {
        // TODO: remember the portion that need to be repeated on each page.
        reportBeforePaginatedSection = report
        report = ""
    }
    
    func endRepeatingPart(_ todoBeforeNextPage : @escaping (ReportFormatter) -> Void)
    {
        self.todoBeforeNextPage = todoBeforeNextPage
        repeatingPart = report
        
        // This is the FIRST time we add the repeating part in the report
        report = replaceCurrentPage(with: currentPage, in: repeatingPart)
    }
    
    func endPaginatedSection()
    {
        // The report var contains only the section paginated.
        // So we first replace all occurences of VAR_NUMBER_OF_PAGE
        report = report.replacingOccurrences(of: VAR_NUMBER_OF_PAGE, with: "\(currentPage)")
        // Then we take the section before the paginated section began and append the current paginatedSection (report)
        report = reportBeforePaginatedSection + report
    }
    
    func result() -> String
    {
        return "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always}</STYLE><style type='text/css'>td{font-size:8pt;font-family:Helvetica}</style><style type='text/css'>th{font-size:10pt;font-family:Helvetica}</style><title>\(self.title)</title></head><body>" +
            report +
        "</body></html>"
    }
    
    func generateResult(filename : String = "report", _ delegate: ReportFormatterDelegate)
    {
        export(filename: filename){url in
            if let url = url {
                delegate.success(url)
            } else {
                delegate.fail("Cannot create file!")
            }
        }
    }
    
    func generateResult(filename : String = "report", _ handler : @escaping (URL?)->Void)
    {
        export(filename: filename, handler)
    }
    
    private func export(filename : String, _ done: @escaping (URL?)->Void) {
        DispatchQueue.global(qos: .background).async {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("\(filename).html")
            do {
                try self.result().write(to: url, atomically: true, encoding: .utf16)
                DispatchQueue.main.async{ done(url) }
            } catch {
                DispatchQueue.main.async{ done(nil) }
            }
        }
    }
    
    private func pageBreakIfNeeded()
    {
        if currentNumberOfRow > 0 && (currentNumberOfRow % numberOfRowPerPage) == 0
        {
            todoBeforeNextPage(self)
            currentPage += 1
            report += replaceCurrentPage(with: currentPage, in: repeatingPart)
            isGray = false
        }
    }

}

class ExcelFormatter: ReportFormatter
{
    let BG_ALTERNATECOLOR = "#E3E3E3"
    let BG_FILLEDCELL = "#000000"
    let BG_HEADER = "#CCCCCC"
    let BG_FOOTER = "#CCCCCC"
    let WORKSHEET_TITLE_MAX_LENGTH = 30
    
    var isGray = false
    var isAlternatingRowColor = false

    private var title = ""
    private var rowsOnCurrentSheet = [ExcelRow]()
    private var titleCurrentSheet : String? = nil
    private var sheets = [ExcelSheet]()
    private var sheetsTitle : Set<String> = []
    
    func setReportTitle(_ title : String)
    {
        self.title = title
    }

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
                let rowSpan : Int? = (column.rowSpan != nil) ? column.rowSpan! - 1 : nil
                let colSpan : Int? = (column.colSpan != nil) ? column.colSpan! - 1 : nil
                var title = fix(column.title)
                title = replaceCurrentPage(with: 1, in: title)
                title = replaceNumberOfPage(with: 1, in: title)
                cells.append(ExcelCell(title, [TextAttribute.backgroundColor(bgColor)], .string, colspan: colSpan, rowspan: rowSpan))
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
            let colSpan : Int? = (cell.colSpan != nil) ? cell.colSpan! - 1 : nil
            excelCells.append(ExcelCell(fix(cell.value), attribs, .string, colspan: colSpan, rowspan: rowSpan))
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
            
            let rowSpan : Int? = (cell.rowSpan != nil) ? cell.rowSpan! - 1 : nil
            let colSpan : Int? = (cell.colSpan != nil) ? cell.colSpan! - 1 : nil
            excelCells.append(ExcelCell(cell.value, attribs, .string, colspan: colSpan, rowspan: rowSpan))
        }
        rowsOnCurrentSheet.append(ExcelRow(excelCells))
    }
    
    func endTable()
    {
    }

    func startPaginatedSection()
    {
        // Nothing to do, not supported.
    }
    
    func startRepeatingPart()
    {
        // Nothing to do, not supported.
    }
    
    func endRepeatingPart(_ todoBeforeNextPage : @escaping (ReportFormatter) -> Void)
    {
        // Nothing to do, not supported.
    }
    
    func endPaginatedSection()
    {
        // Nothing to do, not supported.
    }

    func result() -> String
    {
        return ""
    }
    
    func generateResult(filename : String = "report", _ delegate: ReportFormatterDelegate) {
        endPreviousSectionAndResetAccumulator()
        
        // generate the file
        ExcelExport.export(sheets, fileName: filename, done: {url in
            if let url = url {
                delegate.success(url)
            } else {
                delegate.fail("Could not write to file!")
            }
        })
    }
    
    func generateResult(filename : String = "report", _ handler : @escaping (URL?) -> Void)
    {
        endPreviousSectionAndResetAccumulator()
        
        ExcelExport.export(sheets, fileName: filename, done: handler)
    }
    
    private func endPreviousSectionAndResetAccumulator()
    {
        if let title = titleCurrentSheet {
            sheets.append(ExcelSheet(rowsOnCurrentSheet, name: createUniqueWorksheetTitle(title)))
            
            // clear accumulators
            rowsOnCurrentSheet = [ExcelRow]()
        }
    }

    var firstPartOffset = 20
    var suffixLength = 7
    var truncatedInfix = "..."
    
    private func createUniqueWorksheetTitle(_ title: String) -> String
    {
        var resultTitle = title
        
        if title.count >= WORKSHEET_TITLE_MAX_LENGTH
        {
            resultTitle = String(title[..<title.index(title.startIndex, offsetBy: firstPartOffset)]) + "..." + title.suffix(suffixLength)
        }
        
        var (inserted, _) = sheetsTitle.insert(resultTitle)
        var suffixNumber = 1
        
        while !inserted
        {
            if firstPartOffset > 6
            {
                firstPartOffset -= 1
                suffixLength += 1
            }
            else
            {
                suffixNumber += 1
            }
            resultTitle = String(title[..<title.index(title.startIndex, offsetBy: firstPartOffset)]) + "..." + title.suffix(suffixLength)
            if suffixNumber > 1
            {
                let suffix = "-\(suffixNumber)"
                resultTitle.replaceSubrange(resultTitle.range(of: resultTitle.suffix(suffix.count), options: .backwards)!, with: suffix)
            }
            (inserted, _) = sheetsTitle.insert(resultTitle)
        }
        
        return resultTitle
    }
    
    private func addSectionTitleToWorksheet(_ title: String)
    {
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell("")]))
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell(title, [TextAttribute.font([TextAttribute.FontStyle.bold])], .string, colspan: 10)]))
        rowsOnCurrentSheet.append(ExcelRow([ExcelCell("")]))
    }
    
    private func setSectionTitle(_ title: String)
    {
        titleCurrentSheet = title
    }
    
    private func fix(_ value : String) -> String
    {
        return value.replacingOccurrences(of: "<br>", with: "&#10;",options: .caseInsensitive)
    }
}
