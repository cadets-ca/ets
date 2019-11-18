//
//  StatsReportFromDate.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-11-14.
//

import Foundation

struct StatsReportFromDateParameters
{
    let startDate : Date
    let endDate : Date
    let glidingCentre : GlidingCentre?
    let regionName : String
}

class StatsReportFromDate
{
    let startDate : Date
    let endDate : Date
    let siteSpecific : Bool
    let glidingCentre : GlidingCentre!
    var unit : String {
        return glidingCentre!.name
    }
    let regionName : String
    
    init(_ parameters : StatsReportFromDateParameters)
    {
        self.startDate = parameters.startDate
        self.endDate = parameters.endDate
        self.glidingCentre = parameters.glidingCentre
        self.siteSpecific = glidingCentre != nil
        self.regionName = parameters.regionName
    }
    
    init(_ startDate: Date, toDate endDate: Date, glidingCentre : GlidingCentre?, regionName : String)
    {
        self.startDate = startDate
        self.endDate = endDate
        self.glidingCentre = glidingCentre
        self.siteSpecific = glidingCentre != nil
        self.regionName = regionName
    }
    
    /**
     This is the new version of the statsReportFromDate.
     
     This version uses a class that implement the StatsReportFromDateGenerator protocol, whose responsibility is to structure the
     report according to the format of the file. The goal is to keep in the method only what belongs to the gathering of the data.
     
     The first part will be to extract the report variable into the HtmlStatsReportFromDateGenerator, replacing each reference to the report variable
     by a call to a method of the StatsReportFromDateGenerator protocol.
     
     The start and end of the HTML file will only appear in the "getResult" method called only at the end. At a later time, the result will be change by a generate method which will be async to allow for different type of file and algorithm.
     
     I envision a addSection(text) which, in the case of HTML report, will insert a heading (<big>) with the text passed. We can also think of a addEmptyRow to create spacing.
     
     Other methods will be created keeping in mind that at the end, we want to replace the HTML report by an Excel report.
     
     - Warning
     
     The problem to solve is that presently, the result is a String representing the HTML file (the text format) that will be tranformed into a PDF file (the binary format) using some utility class that
     depends on some kind of UI API. But the goal is to be able to have it generate an Excel spreadsheet. Which is already our binary format (in fact it is still text format - XML - but need no
     other transformation). Building the Excel file is async because of the operation required. So the generator.generate protocol method will need to be async as well. Which will change significantly the structure of the code.
     */
    func generate(with formatter: StatsReportFromDateFormater)
    {
        //Heading and number of glider flights
        guard let GC = regularFormat && dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre else{return}
        let START = Date()
        let beginningOfReport = startDate
        
        let now = Date()
        let secondsInFiveDays = -5*24*60*60
        let fiveDaysAgo = Date(timeInterval: Double(secondsInFiveDays), since: now).startOfDay
        let secondsInTwelveDays = -12*24*60*60
        let twelveDaysAgo = Date(timeInterval: Double(secondsInTwelveDays), since: now).startOfDay
        
        let gliderFlightsLastFiveDaysrequest = FlightRecord.request
        let gliderFlightsLastFiveDaysPredicate = NSPredicate(format: "\(#keyPath(FlightRecord.timeUp)) > %@ AND \(#keyPath(FlightRecord.timesheet.aircraft.gliderOrTowplane)) == 1", argumentArray: [fiveDaysAgo])
        var compoundPredicate: NSCompoundPredicate
        
        if siteSpecific
        {
            let siteSpecificPredicate = NSPredicate(format: "timesheet.glidingCentre == %@", argumentArray: [GC])
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [gliderFlightsLastFiveDaysPredicate, siteSpecificPredicate])
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [gliderFlightsLastFiveDaysPredicate])
        }
        
        gliderFlightsLastFiveDaysrequest.predicate = compoundPredicate
        let numberOfGliderFlightsInLastFiveDays: Int
        do {try numberOfGliderFlightsInLastFiveDays = dataModel.managedObjectContext.count(for: gliderFlightsLastFiveDaysrequest)}
        catch {numberOfGliderFlightsInLastFiveDays = 0}
        
        if siteSpecific
        {
            formatter.addNewSectionTitle("\(unit.uppercased()) STATS REPORT \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            formatter.addNewSectionTitle("REGIONAL STATS REPORT \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        formatter.addBlankLine()
        
        if siteSpecific
        {
            formatter.addLineOfInfoText("\(unit) glider flights last five days: \(numberOfGliderFlightsInLastFiveDays)")
        }
            
        else
        {
            formatter.addLineOfInfoText("Glider flights last five days: \(numberOfGliderFlightsInLastFiveDays)")
        }
        
        formatter.addBlankLine()
        
        // MARK: - Maintenance portion of report
        generateMaintenanceReportWithReportGenerator(formatter, glidingCentre: GC, siteSpecific: siteSpecific)
        let MAINTENANCECOMPLETED = Date()
        // MARK: End Of Maintenance Section
        
        let allFlightRecordsForReportPeriodRequest = FlightRecord.request
        let allFlightRecordsForReportPeriodPredicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND pilot != nil", argumentArray: [beginningOfReport, endDate])
        
        if siteSpecific
        {
            let siteSpecificPredicate = NSPredicate(format: "timesheet.glidingCentre == %@", argumentArray: [GC])
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [allFlightRecordsForReportPeriodPredicate, siteSpecificPredicate])
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [allFlightRecordsForReportPeriodPredicate])
        }
        
        allFlightRecordsForReportPeriodRequest.predicate = compoundPredicate
        let upTimeSortCriteria = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
        allFlightRecordsForReportPeriodRequest.sortDescriptors = [upTimeSortCriteria]
        let allFlightRecordsForReportPeriod: [FlightRecord]
        do {allFlightRecordsForReportPeriod = try dataModel.managedObjectContext.fetch(allFlightRecordsForReportPeriodRequest)}
        catch {allFlightRecordsForReportPeriod = [FlightRecord]()}
        
        var winchLaunches = 0
        var autoLaunches = 0
        var towFamFlights = 0
        var gliderFlightsBySequence = [String: Int]()
        var gliderSequenceMinutes = [String: Int]()
        var towplaneFlightsBySequence = [String: Int]()
        var towplaneSequenceMinutes = [String: Int]()
        
        var flyingDatesDictionary = [Date: GlidingDay]()
        
        /// Simply pulls the GlidingDay item for date from the flyingDatesDictionary array, otherwise inserts a new one
        ///
        /// - parameter date: Anytime on the day in question
        ///
        /// - returns: A GlidingDay object
        func statsForDay(_ date: Date) -> GlidingDay
        {
            let dateOfFlight = date.startOfDay
            var glidingDayStats: GlidingDay
            
            if let stats = flyingDatesDictionary[dateOfFlight]
            {
                glidingDayStats = stats
            }
                
            else
            {
                glidingDayStats = GlidingDay()
                flyingDatesDictionary[dateOfFlight] = glidingDayStats
            }
            
            return glidingDayStats
        }
        
        let RECORDLOOPSTART = Date()
        
        for record in allFlightRecordsForReportPeriod
        {
            switch record.timesheet.aircraft.type
            {
                case .glider:
                    let previousSequenceCount = gliderFlightsBySequence[record.flightSequence] ?? 0
                    let newCount = previousSequenceCount + 1
                    gliderFlightsBySequence[record.flightSequence] = newCount
                    let previousMinutes = gliderSequenceMinutes[record.flightSequence] ?? 0
                    gliderSequenceMinutes[record.flightSequence] = Int(record.flightLengthInMinutes) + previousMinutes
                    var glidingDayStats = statsForDay(record.timeUp)
                    let newTotal = glidingDayStats.totalGliderFlights + 1
                    glidingDayStats.totalGliderFlights = newTotal
                
                case .towplane:
                    let previousSequenceCount = towplaneFlightsBySequence[record.flightSequence] ?? 0
                    let newCount = previousSequenceCount + 1
                    towplaneFlightsBySequence[record.flightSequence] = newCount
                    let previousMinutes = towplaneSequenceMinutes[record.flightSequence] ?? 0
                    towplaneSequenceMinutes[record.flightSequence] = Int(record.flightLengthInMinutes) + previousMinutes
                    
                    if let passenger = record.passenger
                    {
                        if record.flightSequence == "Fam / PR / Wx" && passenger.typeOfParticipant == "cadet"
                        {
                            towFamFlights += 1
                            var glidingDayStats = statsForDay(record.timeUp)
                            let newTotal = glidingDayStats.totalScoutFams + 1
                            glidingDayStats.totalScoutFams = newTotal
                        }
                }
                
                case .winch:
                    winchLaunches += 1
                
                case .auto:
                    autoLaunches += 1
            }
        }
        
        let RECORDLOOPEND = Date()
        
        if siteSpecific
        {
            formatter.addNewSectionTitle("\(unit.uppercased()) NATIONAL REPORT STATS \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            formatter.addNewSectionTitle("NATIONAL REPORT STATS \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        formatter.startTable([[ReportColumn(title : ""),
                              ReportColumn(colSpan : 2, title : "Gliders"),
                              ReportColumn(colSpan : 2, title : "Tow Aircraft")],
                             [ReportColumn(title : ""),
                              ReportColumn(title : "Flights"),
                              ReportColumn(title : "Hours"),
                              ReportColumn(title : "Flights"),
                              ReportColumn(title : "Hours")]])
        
        var gliderFlightsTotal = 0
        var gliderHoursTotal = NSDecimalNumber(value: 0)
        var towplaneFlightsTotal = 0
        var towplaneHoursTotal = NSDecimalNumber(value: 0)
        var sequenceDecimal: NSDecimalNumber
        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 1, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        
        //Glider Instructor Course
        if let sequenceTotal = gliderFlightsBySequence["GIC"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["GIC"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            
            formatter.addTableRow([ReportCell(value : "GIC"),
                                  ReportCell(value : "\(sequenceTotal)"),
                                  ReportCell(value : roundedSequenceDecimal.stringWithDecimal),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true)])
        }
            
        else
        {
            formatter.addTableRow([ReportCell(value : "GIC"),
                                  ReportCell(value : "0"),
                                  ReportCell(value : "0.0"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true)])
        }
        
        //Tow Pilot Course
        if let sequenceTotal = towplaneFlightsBySequence["Tow Course"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Tow Course"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
            
            formatter.addTableRow([ReportCell(value : "TPC"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true),
                                  ReportCell(value : "\(sequenceTotal)"),
                                  ReportCell(value : roundedSequenceDecimal.stringWithDecimal)])
        }
            
        else
        {
            formatter.addTableRow([ReportCell(value : "TPC"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true),
                                  ReportCell(value : "0"),
                                  ReportCell(value : "0.0")])
        }
        
        // Conversion
        if let sequenceTotal = gliderFlightsBySequence["Conversion"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Conversion"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            
            formatter.addTableRow([ReportCell(value : "C"),
                                  ReportCell(value : "\(sequenceTotal)"),
                                  ReportCell(value : roundedSequenceDecimal.stringWithDecimal),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true)])
        }
            
        else
        {
            formatter.addTableRow([ReportCell(value : "C"),
                                  ReportCell(value : "0"),
                                  ReportCell(value : "0.0"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true)])
        }
        
        // Student Trg
        if let sequenceTotal = gliderFlightsBySequence["Student Trg"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Student Trg"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            formatter.addTableRow([ReportCell(value : "S"),
                                  ReportCell(value : "\(sequenceTotal)"),
                                  ReportCell(value : roundedSequenceDecimal.stringWithDecimal),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true)])
        }
            
        else
        {
            formatter.addTableRow([ReportCell(value : "S"),
                                  ReportCell(value : "0"),
                                  ReportCell(value : "0.0"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true)])
        }
        
        // Proficiency
        var proficiencyGliderSequence = 0
        var proficiencyGliderHours = NSDecimalNumber(0.0)
        var proficiencyTowplaneSequence = 0
        var proficiencyTowplaneHours = NSDecimalNumber(0.0)
        if let sequenceTotal = gliderFlightsBySequence["Proficiency"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Proficiency"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            
            proficiencyGliderSequence = sequenceTotal
            proficiencyGliderHours = roundedSequenceDecimal
        }
        
        if let sequenceTotal = towplaneFlightsBySequence["Proficiency"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Proficiency"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
            
            proficiencyTowplaneHours = roundedSequenceDecimal
        }
        
        formatter.addTableRow([ReportCell(value : "P"),
                              ReportCell(value : "\(proficiencyGliderSequence)"),
                              ReportCell(value : proficiencyGliderHours.stringWithDecimal),
                              ReportCell(isBlack : true),
                              ReportCell(value : proficiencyTowplaneHours.stringWithDecimal)])
        
        
        // Upgrade
        var upgradeGliderSequence = 0
        var upgradeGliderHours = NSDecimalNumber(0.0)
        var upgradeTowplaneSequence = 0
        var upgradeTowplaneHours = NSDecimalNumber(0.0)
        
        if let sequenceTotal = gliderFlightsBySequence["Upgrade"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Upgrade"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            
            upgradeGliderSequence = sequenceTotal
            upgradeGliderHours = roundedSequenceDecimal
        }
        
        if let sequenceTotal = towplaneFlightsBySequence["Upgrade"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Upgrade"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
            
            upgradeTowplaneHours = roundedSequenceDecimal
        }
        
        formatter.addTableRow([ReportCell(value : "U"),
                              ReportCell(value : "\(upgradeGliderSequence)"),
                              ReportCell(value : upgradeGliderHours.stringWithDecimal),
                              ReportCell(isBlack : true),
                              ReportCell(value : upgradeTowplaneHours.stringWithDecimal)])
        
        // Famil
        var familGliderSequence = 0
        var familGliderHours = NSDecimalNumber(0.0)
        var familTowplaneSequence = 0
        var familTowplaneHours = NSDecimalNumber(0.0)
        
        if let sequenceTotal = gliderFlightsBySequence["Famil"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Famil"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            
            familGliderSequence = sequenceTotal
            familGliderHours = roundedSequenceDecimal
        }
        
        if let sequenceTotal = towplaneFlightsBySequence["Fam / PR / Wx"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Fam / PR / Wx"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
            
            familTowplaneSequence = sequenceTotal
            familTowplaneHours = roundedSequenceDecimal
        }
        
        formatter.addTableRow([ReportCell(value : "F"),
                              ReportCell(value : "\(familGliderSequence)"),
                              ReportCell(value : familGliderHours.stringWithDecimal),
                              ReportCell(value : "\(familTowplaneSequence)"),
                              ReportCell(value : familTowplaneHours.stringWithDecimal)])
        
        // Transit
        var transitGliderSequence = 0
        var transitGliderHours = NSDecimalNumber(0.0)
        var transitTowplaneSequence = 0
        var transitTowplaneHours = NSDecimalNumber(0.0)
        
        if let sequenceTotal = gliderFlightsBySequence["Transit"]
        {
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Transit"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
            
            transitGliderSequence = sequenceTotal
            transitGliderHours = roundedSequenceDecimal
        }
        
        if let sequenceTotal = towplaneFlightsBySequence["Transit"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Transit"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
            
            transitTowplaneHours = roundedSequenceDecimal
        }
        
        formatter.addTableRow([ReportCell(value : "✗"),
                              ReportCell(value : "\(transitGliderSequence)"),
                              ReportCell(value : transitGliderHours.stringWithDecimal),
                              ReportCell(isBlack : true),
                              ReportCell(value : transitTowplaneHours.stringWithDecimal)])
        
        //Towing
        if let sequenceTotal = towplaneFlightsBySequence["Towing"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Towing"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
            
            formatter.addTableRow([ReportCell(value : "TOW"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true),
                                  ReportCell(value : roundedSequenceDecimal.stringWithDecimal)])
        }
            
        else
        {
            formatter.addTableRow([ReportCell(value : "TOW"),
                                  ReportCell(isBlack : true),
                                  ReportCell(isBlack : true),
                                  ReportCell(value : "0"),
                                  ReportCell(value : "0.0")])
        }
        
        //Totals
        formatter.addTotalRow([ReportCell(value : "Total"),
                              ReportCell(value : "\(gliderFlightsTotal)"),
                              ReportCell(value : gliderHoursTotal.stringWithDecimal),
                              ReportCell(value : "\(towplaneFlightsTotal)"),
                              ReportCell(value : towplaneHoursTotal.stringWithDecimal)])
        formatter.endTable()
        
        let winchTimesheetRequest = AircraftTimesheet.request
        let winchTimesheetRequestPredicate = NSPredicate(format: "date > %@ AND date < %@ AND aircraft.gliderOrTowplane == -1", argumentArray: [beginningOfReport, endDate])
        
        if siteSpecific
        {
            let sitePredicate = NSPredicate(format: "glidingCentre == %@",argumentArray: [GC])
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [winchTimesheetRequestPredicate, sitePredicate])
            
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [winchTimesheetRequestPredicate])
        }
        
        winchTimesheetRequest.predicate = compoundPredicate
        
        let winchTimesheets: [AircraftTimesheet]
        
        do{try winchTimesheets = dataModel.managedObjectContext.fetch(winchTimesheetRequest)}
        catch{winchTimesheets = [AircraftTimesheet]()}
        
        var winchHoursTotal = Decimal(0)
        
        for timesheet in winchTimesheets
        {
            let timeOnTimesheet = timesheet.TTSNfinal - timesheet.TTSNinitial
            winchHoursTotal = winchHoursTotal + timeOnTimesheet
        }
        
        if winchLaunches > 0
        {
            formatter.addLineOfText("\(winchLaunches) winch launches")
        }
        
        if autoLaunches > 0
        {
            formatter.addLineOfText("\(autoLaunches) auto launches")
        }
        
        let NATIONALCOMPLETED = Date()
        //MARK: End Of National Section
        //Squadron Attendance portion of report
        
        if siteSpecific
        {
            formatter.addNewSectionTitle("\(unit.uppercased()) SQUADRON ATTENDANCE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            formatter.addNewSectionTitle("SQUADRON ATTENDANCE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        let squadronCadetRequest = AttendanceRecord.request
        let cadetRequestPredicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND pilot.typeOfParticipant == %@", argumentArray: [beginningOfReport,endDate, "cadet"])
        
        let sitePredicate = NSPredicate(format: "glidingCentre == %@",argumentArray: [GC])
        
        if siteSpecific
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [cadetRequestPredicate, sitePredicate])
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [cadetRequestPredicate])
        }
        
        squadronCadetRequest.predicate = compoundPredicate
        let timeInSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.timeIn), ascending: true)
        let squadronSortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.pilot.squadron), ascending: true)
        squadronCadetRequest.sortDescriptors = [timeInSortDescriptor,squadronSortDescriptor]
        let cadetRecords: [AttendanceRecord]
        do{try cadetRecords = dataModel.managedObjectContext.fetch(squadronCadetRequest)}
        catch{cadetRecords = [AttendanceRecord]()}
        
        var totalNumberOfCadets = 0
        var totalNumberOfCadetsFlown = 0
        
        for record in cadetRecords
        {
            let startOfRecordDate = record.timeIn.startOfDay
            let stats = statsForDay(record.timeIn)
            
            let squadronNumber = Int(record.pilot.squadron)
            totalNumberOfCadets += 1
            let numberOfDualsForPersonOnTheDateOfThatRecord = record.pilot.numberOfGliderDualsOnDate(record.timeIn.startOfDay)
            stats.squadronCadetsAttended[squadronNumber] = stats.cadetsAttended(squadronNumber) + 1
            if stats.siteForSquadron[squadronNumber] == nil
            {
                stats.siteForSquadron[squadronNumber] = record.glidingCentre.name
            }
            
            if numberOfDualsForPersonOnTheDateOfThatRecord > 0
            {
                totalNumberOfCadetsFlown += numberOfDualsForPersonOnTheDateOfThatRecord
                stats.squadronCadetsFlownInGlider[squadronNumber] = stats.cadetsFlownInGlider(squadronNumber) + numberOfDualsForPersonOnTheDateOfThatRecord
            }
        }
        
        let commentRequest = GlidingDayComment.request
        let commentRequestPredicate = NSPredicate(format: "date >= %@ AND date <= %@", argumentArray: [beginningOfReport, endDate])
        
        if siteSpecific
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [commentRequestPredicate, sitePredicate])
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [commentRequestPredicate])
        }
        
        commentRequest.predicate = compoundPredicate
        var comments: [GlidingDayComment]
        do{comments = try dataModel.managedObjectContext.fetch(commentRequest)}
        catch{comments = [GlidingDayComment]()}
        
        for comment in comments
        {
            let stats = statsForDay(comment.date)
        }
        
        var arrayOfDatesFlownOrWithCadets = Array(flyingDatesDictionary.keys)
        arrayOfDatesFlownOrWithCadets.sort(by: <)
        
        formatter.startTable([[ReportColumn(widthPixel : 60, title : "Date"),
                              ReportColumn(widthPixel : 100, title : "Squadron"),
                              ReportColumn(widthPixel : 60, title : "Number of Squadron Cadets Attended"),
                              ReportColumn(widthPixel : 60, title : "Number of Squadron Cadet Glider Fams"),
                              ReportColumn(widthPixel : 60, title : "Number of Glider Flights"),
                              ReportColumn(widthPixel : 60, title : "Number of Cadet Fam Flights in Tow A/C"),
                              ReportColumn(title : "Comments")]], withAlternatingRowColor : true)
        
        for date in arrayOfDatesFlownOrWithCadets
        {
            let commentRequestPredicate2 = NSPredicate(format: "date > %@ AND date < %@", argumentArray: [date, date + (60*60*24)])
            
            if siteSpecific
            {
                compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [commentRequestPredicate2, sitePredicate])
            }
                
            else
            {
                compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [commentRequestPredicate2])
            }
            
            commentRequest.predicate = compoundPredicate
            commentRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(GlidingDayComment.date), ascending: true)]
            do{comments = try dataModel.managedObjectContext.fetch(commentRequest)}
            catch{comments = [GlidingDayComment]()}
            
            var commentsForDate = ""
            for comment in comments
            {
                if siteSpecific == false
                {
                    guard let _ = comment.glidingCentre else {continue}
                    commentsForDate += "(\(comment.glidingCentre.name)) "
                }
                
                commentsForDate += comment.comment
                if comment != comments.last
                {
                    commentsForDate += "<br>"
                }
            }
            
            let flightsAndAttenaceForDate = statsForDay(date)
            var squadronString = ""
            let sortedSquadronNumbers = flightsAndAttenaceForDate.squadronCadetsAttended.keys.sorted(by: <)
            
            if flightsAndAttenaceForDate.squadronCadetsAttended.count > 0
            {
                for squadronNumber in sortedSquadronNumbers
                {
                    squadronString += "\(squadronNumber)"
                    
                    if siteSpecific == false, let squadron = flightsAndAttenaceForDate.siteForSquadron[squadronNumber]
                    {
                        squadronString += " \(squadron)"
                    }
                    
                    if squadronNumber != sortedSquadronNumbers.last ?? 0
                    {
                        squadronString += "<br>"
                    }
                }
            }
                
            else
            {
                squadronString += "Training"
            }
            
            var squadronAttendanceString = ""
            for squadronNumber in sortedSquadronNumbers
            {
                squadronAttendanceString += "\(flightsAndAttenaceForDate.squadronCadetsAttended[squadronNumber] ?? 0)"
                
                if squadronNumber != sortedSquadronNumbers.last ?? 0
                {
                    squadronAttendanceString += "<br>"
                }
            }
            
            var squadronGliderAttendanceString = ""
            for squadronNumber in sortedSquadronNumbers
            {
                squadronGliderAttendanceString += "\(flightsAndAttenaceForDate.squadronCadetsFlownInGlider[squadronNumber] ?? 0)"
                
                if squadronNumber != sortedSquadronNumbers.last ?? 0
                {
                    squadronGliderAttendanceString += "<br>"
                }
            }
            
            formatter.addTableRow([ReportCell(value : date.militaryFormatShort),
                                  ReportCell(value : squadronString),
                                  ReportCell(value : squadronAttendanceString),
                                  ReportCell(value : squadronGliderAttendanceString),
                                  ReportCell(value : "\(flightsAndAttenaceForDate.totalGliderFlights)"),
                                  ReportCell(value : "\(flightsAndAttenaceForDate.totalScoutFams)"),
                                  ReportCell(value : commentsForDate)])
        }
        
        formatter.addTotalRow([ReportCell(value : "Total"),
                              ReportCell(),
                              ReportCell(value : "\(totalNumberOfCadets)"),
                              ReportCell(value : "\(totalNumberOfCadetsFlown)"),
                              ReportCell(value : "\(gliderFlightsTotal)"),
                              ReportCell(value : "\(towFamFlights)"),
                              ReportCell()])
        
        formatter.endTable()
        
        let SQUADRONCOMPLETED = Date()
        //MARK: End of Squadron Stats
        
        //Personnel portion of report
        if siteSpecific
        {
            formatter.addNewSectionTitle("\(unit.uppercased()) PERSONNEL STATS \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            formatter.addNewSectionTitle("PERSONNEL STATS \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        // - TODO: Start table
        formatter.startTable([[ReportColumn(title : ""),
                              ReportColumn(title : "Days Worked"),
                              ReportColumn(title : "PIC Flights"),
                              ReportColumn(title : "PIC flights /<br> day worked"),
                              ReportColumn(title : "Dual Flights"),
                              ReportColumn(title : "Dual Flights /<br>day worked")]], withAlternatingRowColor : true)
        
        let staffAttendanceRequest = AttendanceRecord.request
        let staffAttendanceRequestPredicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND participantType != %@ AND pilot != nil", argumentArray: [beginningOfReport, endDate, "cadet"])
        
        if siteSpecific
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [staffAttendanceRequestPredicate, sitePredicate])
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [staffAttendanceRequestPredicate])
        }
        
        staffAttendanceRequest.predicate = compoundPredicate
        let staffRecords: [AttendanceRecord]
        do{staffRecords = try dataModel.managedObjectContext.fetch(staffAttendanceRequest)}
        catch{staffRecords = [AttendanceRecord]()}
        
        var flightRecordsInTimePeriod = Set<FlightRecord>()
        
        if siteSpecific
        {
            for timesheet in GC.timesheets
            {
                if (beginningOfReport...endDate).contains(timesheet.date)
                {
                    flightRecordsInTimePeriod.formUnion(timesheet.flightRecords)
                }
            }
        }
            
        else
        {
            let flightRecordRequest = FlightRecord.request
            let flightRecordRequestPredicate = NSPredicate(format: "\(#keyPath(FlightRecord.timeUp)) > %@ AND \(#keyPath(FlightRecord.timeUp)) < %@ AND \(#keyPath(FlightRecord.pilot)) != nil", argumentArray: [beginningOfReport, endDate])
            flightRecordRequest.predicate = flightRecordRequestPredicate
            do{flightRecordsInTimePeriod = try Set(dataModel.managedObjectContext.fetch(flightRecordRequest))}
            catch{}
        }
        
        struct StaffStats
        {
            var daysWorked = Double(0)
            var PICflights = 0
            var dualFlights = 0
        }
        
        var staffCadetStats = StaffStats()
        var volunteerStats = StaffStats()
        var CIstats = StaffStats()
        var COATSstats = StaffStats()
        
        for record in flightRecordsInTimePeriod
        {
            guard let type = record.timesheet?.aircraft?.type, type >= .towplane else{continue}
            
            switch record.picParticipantType
            {
                case "Staff Cadet":
                    staffCadetStats.PICflights += 1
                
                case "COATS":
                    COATSstats.PICflights += 1
                
                case "Civilian Instructor":
                    CIstats.PICflights += 1
                
                case "Volunteer":
                    volunteerStats.PICflights += 1
                
                default:
                    break
            }
            
            if let dualParticipantType = record.dualParticipantType
            {
                switch dualParticipantType
                {
                    case "Staff Cadet":
                        staffCadetStats.dualFlights += 1
                    
                    case "COATS":
                        COATSstats.dualFlights += 1
                    
                    case "Civilian Instructor":
                        CIstats.dualFlights += 1
                    
                    case "Volunteer":
                        volunteerStats.dualFlights += 1
                    
                    default:
                        break
                }
            }
        }
        
        var staffCadetAttandance = [Pilot: Double]()
        
        for record in staffRecords
        {
            switch record.participantType
            {
                case "Staff Cadet":
                    let amountWorked = record.sessionType.rawValue
                    staffCadetStats.daysWorked += record.sessionType.rawValue
                    
                    if let previousNumberOfDaysWorked = staffCadetAttandance[record.pilot]
                    {
                        let newNumberOfDaysWorked = previousNumberOfDaysWorked + amountWorked
                        staffCadetAttandance[record.pilot] = newNumberOfDaysWorked
                    }
                        
                    else
                    {
                        staffCadetAttandance[record.pilot] = amountWorked
                }
                
                case "COATS":
                    COATSstats.daysWorked += record.sessionType.rawValue
                
                case "Civilian Instructor":
                    CIstats.daysWorked += record.sessionType.rawValue
                
                case "Volunteer":
                    volunteerStats.daysWorked += record.sessionType.rawValue
                
                default:
                    break
            }
        }
        
        func appendStatsFor(_ participantType: String, PICFlights: Int, dualFlights: Int, daysWorked: Double)
        {
            let PICflightsPerDay = daysWorked == 0 ? 0 : Double(PICFlights) / daysWorked
            let dualFlightsPerDay = daysWorked == 0 ? 0 : Double(dualFlights) / daysWorked
            formatter.addTableRow([ReportCell(value : participantType),
                                  ReportCell(value : daysWorked.oneDecimalStringRepresentation),
                                  ReportCell(value : "\(PICFlights)"),
                                  ReportCell(value : PICflightsPerDay.oneDecimalStringRepresentation),
                                  ReportCell(value : "\(dualFlights)"),
                                  ReportCell(value : dualFlightsPerDay.oneDecimalStringRepresentation)])
        }
        
        appendStatsFor("Staff Cadet", PICFlights: staffCadetStats.PICflights, dualFlights: staffCadetStats.dualFlights, daysWorked: staffCadetStats.daysWorked)
        appendStatsFor("Volunteer", PICFlights: volunteerStats.PICflights, dualFlights: volunteerStats.dualFlights, daysWorked: volunteerStats.daysWorked)
        appendStatsFor("CI", PICFlights: CIstats.PICflights, dualFlights: CIstats.dualFlights, daysWorked: CIstats.daysWorked)
        appendStatsFor("COATS", PICFlights: COATSstats.PICflights, dualFlights: COATSstats.dualFlights, daysWorked: COATSstats.daysWorked)
        
        formatter.endTable()
        
        let paidDays = COATSstats.daysWorked + CIstats.daysWorked
        formatter.addBlankLine()
        formatter.addLineOfText("Total paid days used \(paidDays.oneDecimalStringRepresentation)")
        
        // Start Staff Cadet Attendance
        if siteSpecific
        {
            formatter.addNewSectionTitle("\(unit.uppercased()) STAFF CADET ATTENDANCE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            formatter.addNewSectionTitle("STAFF CADET ATTENDANCE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        formatter.startTable([[ReportColumn(title : "Name"),
                              ReportColumn(title : "Squadron"),
                              ReportColumn(title : "Site"),
                              ReportColumn(title : "Days Worked")]],
                            withAlternatingRowColor : true,
                            withInformationText : "Cadets signed in less than 2 days are not shown in this report.")
        
        var cadetNames = Array(staffCadetAttandance.keys).sorted(by: {(pilot1, pilot2) in
            return pilot1.name < pilot2.name
        })
        //cadetNames.sort(by: {staffCadetAttandance[$0]! > staffCadetAttandance[$1]!})
        
        for cadet in cadetNames
        {
            if let daysWorked = staffCadetAttandance[cadet], daysWorked > 1.5
            {
                formatter.addTableRow([ReportCell(value : cadet.fullName),
                                      ReportCell(value : "\(cadet.squadron)"),
                                      ReportCell(value : cadet.glidingCentre.name),
                                      ReportCell(value : daysWorked.oneDecimalStringRepresentation)])
            }
        }
        
        formatter.endTable()
        
        if siteSpecific
        {
            formatter.addNewSectionTitle("\(unit.uppercased()) STAFF UPGRADES \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            formatter.addNewSectionTitle("STAFF UPGRADES \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        formatter.startTable([[ReportColumn(title : "Upgrade"),
                              ReportColumn(title : "Name"),
                              ReportColumn(title : "Type of Participant"),
                              ReportColumn(title : "Site")]], withAlternatingRowColor: true)
        
        let upgradeFetchRequest = Pilot.request
        var upgradeFetchRequestPredicate = NSPredicate(format: "dateOfFrontSeatFamilPilot > %@ AND dateOfFrontSeatFamilPilot < %@ AND highestGliderQual >2 ", argumentArray: [beginningOfReport, endDate])
        if siteSpecific
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [upgradeFetchRequestPredicate, sitePredicate])
        }
            
        else
        {
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [upgradeFetchRequestPredicate])
        }
        upgradeFetchRequest.predicate = compoundPredicate
        let typeOfParticipantSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.typeOfParticipant), ascending: true)
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.name), ascending: true)
        upgradeFetchRequest.sortDescriptors = [typeOfParticipantSortDescriptor,nameSortDescriptor]
        
        func executeupgradeFetchRequest(newPredicate: NSPredicate) -> [Pilot]
        {
            if siteSpecific
            {
                compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [newPredicate, sitePredicate])
            }
                
            else
            {
                compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [newPredicate])
            }
            upgradeFetchRequest.predicate = compoundPredicate
            
            do{return try dataModel.managedObjectContext.fetch(upgradeFetchRequest)}
            catch{return [Pilot]()}
        }
        
        let FSFupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfRearSeatFamilPilot > %@ AND dateOfRearSeatFamilPilot < %@ AND highestGliderQual >3", argumentArray: [beginningOfReport, endDate])
        let RSFupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderInstructorPilot > %@ AND dateOfGliderInstructorPilot < %@ AND highestGliderQual >4", argumentArray: [beginningOfReport, endDate])
        let instructorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderCheckPilot > %@ AND dateOfGliderCheckPilot < %@ AND highestGliderQual >5", argumentArray: [beginningOfReport, endDate])
        let gliderCheckPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderStandardsPilot > %@ AND dateOfGliderStandardsPilot < %@ AND highestGliderQual >6", argumentArray: [beginningOfReport, endDate])
        let gliderStandardsPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderPilotXCountry > %@ AND dateOfGliderPilotXCountry < %@", argumentArray: [beginningOfReport, endDate])
        let gliderXCountryUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Glider Xcountry")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchPilot > %@ AND dateOfWinchLaunchPilot < %@",argumentArray: [beginningOfReport, endDate])
        let winchPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Launch")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchOperator > %@ AND dateOfWinchLaunchOperator < %@", argumentArray: [beginningOfReport, endDate])
        let winchOperatorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Operator")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchInstructor > %@ AND dateOfWinchLaunchInstructor < %@", argumentArray: [beginningOfReport, endDate])
        let winchInstructorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Launch Instructor")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchRetrieveDriver > %@ AND dateOfWinchRetrieveDriver < %@", argumentArray: [beginningOfReport, endDate])
        let winchRetrieveUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Retrieve Driver")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowPilot > %@ AND dateOfTowPilot < %@ AND highestScoutQual >0", argumentArray: [beginningOfReport, endDate])
        let towPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowCheckPilot > %@ AND dateOfTowCheckPilot < %@ AND highestScoutQual >1", argumentArray: [beginningOfReport, endDate])
        let towCheckPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowStandardsPilot > %@ AND dateOfTowStandardsPilot < %@ AND highestScoutQual >2", argumentArray: [beginningOfReport, endDate])
        let towStandardsPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowPilotXCountry > %@ AND dateOfTowPilotXCountry < %@", argumentArray: [beginningOfReport, endDate])
        let towXcountryUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Tow Xcountry")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfLaunchControlOfficer > %@ AND dateOfLaunchControlOfficer < %@", argumentArray: [beginningOfReport, endDate])
        let LCOupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("LCO")})
        
        func addCellForUpgrade(_ name: String, upgradedPilots: [Pilot])
        {
            for upgradedPilot in upgradedPilots
            {
                formatter.addTableRow([ReportCell(value : name),
                                      ReportCell(value : upgradedPilot.fullName),
                                      ReportCell(value : upgradedPilot.typeOfParticipantStringWithSquadronForCadets),
                                      ReportCell(value : upgradedPilot.glidingCentre?.name ?? "")])
            }
        }
        
        addCellForUpgrade("Front Seat Fam", upgradedPilots: FSFupgrades)
        addCellForUpgrade("Rear Seat Fam", upgradedPilots: RSFupgrades)
        addCellForUpgrade("Gliding Instructor", upgradedPilots: instructorUpgrades)
        addCellForUpgrade("Glider Check Pilot", upgradedPilots: gliderCheckPilotUpgrades)
        addCellForUpgrade("Glider Standards Pilot", upgradedPilots: gliderStandardsPilotUpgrades)
        addCellForUpgrade("Glider Xcountry", upgradedPilots: gliderXCountryUpgrades)
        addCellForUpgrade("Winch Launch Pilot", upgradedPilots: winchPilotUpgrades)
        addCellForUpgrade("Winch Launch Operator", upgradedPilots: winchOperatorUpgrades)
        addCellForUpgrade("Winch Launch Instructor", upgradedPilots: winchInstructorUpgrades)
        addCellForUpgrade("Winch Retrieve Driver", upgradedPilots: winchRetrieveUpgrades)
        addCellForUpgrade("Tow Pilot", upgradedPilots: towPilotUpgrades)
        addCellForUpgrade("Tow Check Pilot", upgradedPilots: towCheckPilotUpgrades)
        addCellForUpgrade("Tow Standards Pilot", upgradedPilots: towStandardsPilotUpgrades)
        addCellForUpgrade("Tow Pilot X-Country", upgradedPilots: towXcountryUpgrades)
        addCellForUpgrade("LCO", upgradedPilots: LCOupgrades)
        
        formatter.endTable()
        
        let PERSONNELCOMPLETED = Date()
        //MARK: End of Personnel Stats
        
        var maintenance = MAINTENANCECOMPLETED - START
        var national = NATIONALCOMPLETED - MAINTENANCECOMPLETED
        var squadron = SQUADRONCOMPLETED - NATIONALCOMPLETED
        var personnel = PERSONNELCOMPLETED - SQUADRONCOMPLETED
        var totalTime = PERSONNELCOMPLETED - START
        var recordLoopTime = RECORDLOOPEND - RECORDLOOPSTART
        
        maintenance *= 1000
        national *= 1000
        squadron *= 1000
        personnel *= 1000
        totalTime *= 1000
        recordLoopTime *= 1000
        
        let maintenancePercent = 100*maintenance/totalTime
        let nationalPercent = 100*national/totalTime
        let squadronPercent = 100*squadron/totalTime
        let personnelPercent = 100*personnel/totalTime
        let recordLoopPercent = 100*recordLoopTime/totalTime
        
        print("The total time is \(Int(totalTime)) milliseconds")
        print("It takes \(Int(maintenance)) milliseconds for maintenance, \(Int(national)) milliseconds for national stats, \(Int(squadron)) milliseconds for squadron stats, and \(Int(personnel)) milliseconds for personnel stats.")
        print("The time is spent \(Int(maintenancePercent)) percent for maintenance, \(Int(nationalPercent)) percent for national stats, \(Int(squadronPercent)) percent for squadron stats, and \(Int(personnelPercent)) percent for personnel stats.")
        print("The record loop uses \(Int(recordLoopPercent)) percent of the total time")
        
        //MARK: - Beginning of Aircraft Usage
        
        let vehicleFetchRequest = AircraftEntity.request
        var vehicles = try! dataModel.managedObjectContext.fetch(vehicleFetchRequest)
        vehicles.sort(by: {numericSearch($0.tailNumber, right: $1.tailNumber)})
        
        class GliderData
        {
            let glider: AircraftEntity
            
            private(set) var transitFlights: Int = 0
            private(set) var familFlights: Int = 0
            private(set) var profFlights: Int = 0
            private(set) var upgradeFlights: Int = 0
            private(set) var studentFlights: Int = 0
            
            private var transitMinutes: Double = 0
            private var familMinutes: Double = 0
            private var profMinutes: Double = 0
            private var upgradeMinutes: Double = 0
            private var studentMinutes: Double = 0
            
            private(set) var transitHours: Decimal = 0
            private(set) var familHours: Decimal = 0
            private(set) var profHours: Decimal = 0
            private(set) var studentHours: Decimal = 0
            private(set) var upgradeHours: Decimal = 0
            private(set) var totalHours: Decimal = 0
            
            
            init(glider: AircraftEntity, startDate: Date = Date.distantPast, endDate: Date = Date.distantFuture)
            {
                self.glider = glider
                let flightRecordFetchRequest = FlightRecord.request
                flightRecordFetchRequest.predicate = NSPredicate(format: "timesheet.aircraft == %@ AND timeUp > %@ AND timeUp < %@", argumentArray: [glider, startDate, endDate])
                let flights = try! dataModel.managedObjectContext.fetch(flightRecordFetchRequest)
                
                for flight in flights
                {
                    guard let sequence = GliderSequence(rawValue: flight.flightSequence) else {continue}
                    switch  sequence
                    {
                        case .Famil:
                            familFlights += 1
                            familMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Transit:
                            transitFlights += 1
                            transitMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Proficiency:
                            profFlights += 1
                            profMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Upgrade:
                            upgradeFlights += 1
                            upgradeMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .StudentTrg:
                            studentFlights += 1
                            studentMinutes += Double(flight.flightLengthInMinutes)
                        
                        default:
                            profFlights += 1
                            profMinutes += Double(flight.flightLengthInMinutes)
                    }
                }
                
                let behavior = NSDecimalNumberHandler(roundingMode: .plain, scale: 1, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                
                familHours = Decimal(familMinutes/60)
                familHours = (familHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                transitHours = Decimal(transitMinutes/60)
                transitHours = (transitHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                profHours = Decimal(profMinutes/60)
                profHours = (profHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                studentHours = Decimal(studentMinutes/60)
                studentHours = (studentHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                upgradeHours = Decimal(upgradeMinutes/60)
                upgradeHours = (upgradeHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                totalHours = familHours + transitHours + profHours + upgradeHours + studentHours
            }
        }
        
        class TowplaneData
        {
            let towplane: AircraftEntity
            
            private(set) var familFlights: Int = 0
            
            private var towingMinutes: Double = 0
            private var transitMinutes: Double = 0
            private var familMinutes: Double = 0
            private var profMinutes: Double = 0
            private var towCourseMinutes: Double = 0
            private var upgradeMinutes: Double = 0
            private var maintenanceMinutes: Double = 0
            
            private(set) var towingHours: Decimal = 0
            private(set) var transitHours: Decimal = 0
            private(set) var familHours: Decimal = 0
            private(set) var profHours: Decimal = 0
            private(set) var towCourseHours: Decimal = 0
            private(set) var upgradeHours: Decimal = 0
            private(set) var maintenanceHours: Decimal = 0
            private(set) var totalHours: Decimal = 0
            
            init(towplane: AircraftEntity, startDate: Date = Date.distantPast, endDate: Date = Date.distantFuture)
            {
                self.towplane = towplane
                let flightRecordFetchRequest = FlightRecord.request
                flightRecordFetchRequest.predicate = NSPredicate(format: "timesheet.aircraft == %@ AND timeUp > %@ AND timeUp < %@", argumentArray: [towplane, startDate, endDate])
                let flights = try! dataModel.managedObjectContext.fetch(flightRecordFetchRequest)
                
                for flight in flights
                {
                    guard let sequence = TowplaneSequence(rawValue: flight.flightSequence) else {continue}
                    switch  sequence
                    {
                        case .FamPRWx:
                            familFlights += 1
                            familMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Transit:
                            transitMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Proficiency:
                            profMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Upgrade:
                            upgradeMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Towing:
                            towingMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .TowCourse:
                            towCourseMinutes += Double(flight.flightLengthInMinutes)
                        
                        case .Maintenance:
                            maintenanceMinutes += Double(flight.flightLengthInMinutes)
                    }
                }
                
                let behavior = NSDecimalNumberHandler(roundingMode: .plain, scale: 1, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
                
                familHours = Decimal(familMinutes/60)
                familHours = (familHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                transitHours = Decimal(transitMinutes/60)
                transitHours = (transitHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                profHours = Decimal(profMinutes/60)
                profHours = (profHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                upgradeHours = Decimal(upgradeMinutes/60)
                upgradeHours = (upgradeHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                towingHours = Decimal(towingMinutes/60)
                towingHours = (towingHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                towCourseHours = Decimal(towCourseMinutes/60)
                towCourseHours = (towCourseHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                maintenanceHours = Decimal(maintenanceMinutes/60)
                maintenanceHours = (maintenanceHours as NSDecimalNumber).rounding(accordingToBehavior: behavior) as Decimal
                
                totalHours = familHours + transitHours + profHours + upgradeHours + towingHours + towCourseHours + maintenanceHours
            }
        }
        
        class WinchData
        {
            let winch: AircraftEntity
            
            private(set) var flights: Int = 0
            private(set) var hours: Decimal = 0
            
            init(winch: AircraftEntity, startDate: Date = Date.distantPast, endDate: Date = Date.distantFuture)
            {
                self.winch = winch
                let timesheetFetchRequest = AircraftTimesheet.request
                timesheetFetchRequest.predicate = NSPredicate(format: "aircraft == %@ AND date > %@ AND date < %@", argumentArray: [winch, startDate, endDate])
                let timesheets = try! dataModel.managedObjectContext.fetch(timesheetFetchRequest)
                
                for timesheet in timesheets
                {
                    let time = timesheet.TTSNfinal - timesheet.TTSNinitial
                    hours += time
                    flights += timesheet.flightRecords.count
                }
            }
        }
        
        var gliders = [GliderData]()
        var towplanes = [TowplaneData]()
        var winches = [WinchData]()
        
        for vehicle in vehicles
        {
            switch vehicle.type
            {
                case .glider:
                    gliders.append(GliderData(glider: vehicle, startDate: beginningOfReport, endDate: endDate))
                
                case .towplane:
                    towplanes.append(TowplaneData(towplane: vehicle, startDate: beginningOfReport, endDate: endDate))
                
                case .winch:
                    winches.append(WinchData(winch: vehicle, startDate: beginningOfReport, endDate: endDate))
                
                default:
                    break
            }
        }
        
        formatter.addNewSectionTitle("GLIDER USAGE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        
        formatter.startTable([[ReportColumn(colSpan : 2, title : ""),
                              ReportColumn(colSpan : 5, title : "Glider Flights"),
                              ReportColumn(colSpan : 5, title : "Glider Hours"),
                              ReportColumn(colSpan : 2, title : "")],
                             [ReportColumn(colSpan : 2, title : "Gliders"),
                              ReportColumn(title : "Transit"),
                              ReportColumn(title : "Famil"),
                              ReportColumn(title : "Prof"),
                              ReportColumn(title : "Student"),
                              ReportColumn(title : "Upgrade"),
                              ReportColumn(title : "Transit"),
                              ReportColumn(title : "Famil"),
                              ReportColumn(title : "Prof"),
                              ReportColumn(title : "Student"),
                              ReportColumn(title : "Upgrade"),
                              ReportColumn(title : "Time Flown"),
                              ReportColumn(title : "Current TTSN")]], withAlternatingRowColor : true)
        
        for glider in gliders
        {
            guard glider.totalHours > 0 else {continue}
            
            glider.glider.updateTTSN()
            
            formatter.addTableRow([ReportCell(value : glider.glider.registration),
                                  ReportCell(value : glider.glider.tailNumber),
                                  ReportCell(value : "\(glider.transitFlights)"),
                                  ReportCell(value : "\(glider.familFlights)"),
                                  ReportCell(value : "\(glider.profFlights)"),
                                  ReportCell(value : "\(glider.studentFlights)"),
                                  ReportCell(value : "\(glider.upgradeFlights)"),
                                  ReportCell(value : glider.transitHours.stringWithDecimal),
                                  ReportCell(value : glider.familHours.stringWithDecimal),
                                  ReportCell(value : glider.profHours.stringWithDecimal),
                                  ReportCell(value : glider.studentHours.stringWithDecimal),
                                  ReportCell(value : glider.upgradeHours.stringWithDecimal),
                                  ReportCell(value : glider.totalHours.stringWithDecimal),
                                  ReportCell(value : glider.glider.currentTimesheet!.TTSNfinal.stringWithDecimal)])
        }
        
        formatter.endTable()
        
        formatter.addNewSectionTitle("TOWPLANE USAGE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        
        formatter.startTable([[ReportColumn(colSpan : 2, title : ""),
                              ReportColumn(colSpan : 7, title : "Scout Hours"),
                              ReportColumn(title : "Scout Flights"),
                              ReportColumn(colSpan : 2, title : "")],
                             [ReportColumn(colSpan : 2, title : "Towplanes"),
                              ReportColumn(title : "Transit"),
                              ReportColumn(title : "Towing"),
                              ReportColumn(title : "TPC"),
                              ReportColumn(title : "Maintenance"),
                              ReportColumn(title : "Prof"),
                              ReportColumn(title : "Upgrade"),
                              ReportColumn(title : "Fam"),
                              ReportColumn(title : "Fam"),
                              ReportColumn(title : "Time Flown"),
                              ReportColumn(title : "Current TTSN")]], withAlternatingRowColor: true)
        
        for towplane in towplanes
        {
            guard towplane.totalHours > 0 else {continue}
            towplane.towplane.updateTTSN()
            
            formatter.addTableRow([ReportCell(value : towplane.towplane.registration),
                                  ReportCell(value : towplane.towplane.tailNumber),
                                  ReportCell(value : towplane.transitHours.stringWithDecimal),
                                  ReportCell(value : towplane.towingHours.stringWithDecimal),
                                  ReportCell(value : towplane.towCourseHours.stringWithDecimal),
                                  ReportCell(value : towplane.maintenanceHours.stringWithDecimal),
                                  ReportCell(value : towplane.profHours.stringWithDecimal),
                                  ReportCell(value : towplane.upgradeHours.stringWithDecimal),
                                  ReportCell(value : towplane.familHours.stringWithDecimal),
                                  ReportCell(value : "\(towplane.familFlights)"),
                                  ReportCell(value : towplane.totalHours.stringWithDecimal),
                                  ReportCell(value : towplane.towplane.currentTimesheet!.TTSNfinal.stringWithDecimal)])
        }
        formatter.endTable()
        
        formatter.addNewSectionTitle("WINCH USAGE \(beginningOfReport.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        
        formatter.startTable([[ReportColumn(colSpan : 2, title : ""),
                              ReportColumn(title : "Current TTSN"),
                              ReportColumn(title : "Hours"),
                              ReportColumn(title : "Flights")]], withAlternatingRowColor: true)
        
        for winch in winches
        {
            guard winch.flights > 0 else {continue}
            winch.winch.updateTTSN()
            
            formatter.addTableRow([ReportCell(value : winch.winch.registration),
                                  ReportCell(value : winch.winch.tailNumber),
                                  ReportCell(value : winch.winch.currentTimesheet!.TTSNfinal.stringWithDecimal),
                                  ReportCell(value : winch.hours.stringWithDecimal),
                                  ReportCell(value : "\(winch.flights)")])
        }
        
        formatter.endTable()
        
        if siteSpecific
        {
            formatter.addNewSectionTitle("ACTIVE STAFF CONTACT INFO")
            
            let pilotRequest = Pilot.request
            pilotRequest.predicate = NSPredicate(format: "inactive == NO AND glidingCentre == %@ AND (highestGliderQual > 0 OR highestScoutQual > 0)", dataModel.glidingCentre)
            let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.fullName), ascending: true)
            pilotRequest.sortDescriptors = [nameSortDescriptor]
            let pilots = try! dataModel.managedObjectContext.fetch(pilotRequest)
            
            for pilot in pilots
            {
                guard pilot.email.count > 0 else{continue}
                formatter.addText(pilot.email + ", ")
            }
        }
    }
    
    func generateMaintenanceReportWithReportGenerator(_ generator : StatsReportFromDateFormater, glidingCentre GC : GlidingCentre, siteSpecific : Bool)
    {
        generator.addTitle("MAINTENANCE REPORT")
        let twelveDaysAgo = Calendar.current.date(byAdding: Calendar.Component.day, value: -12, to: Date())!.startOfDay
        
        let allVehicleRequest = AircraftEntity.request
        let allAircraft: [AircraftEntity]
        do {try allAircraft = dataModel.managedObjectContext.fetch(allVehicleRequest)}
        catch {allAircraft = [AircraftEntity]()}
        
        var aircraftMostRecentlyUsedAtCurrentGC = Set<AircraftEntity>()
        
        for aircraft in allAircraft
        {
            guard aircraft.type != .auto else {continue}
            guard let timesheet = aircraft.currentTimesheet else {continue}
            
            if siteSpecific, timesheet.glidingCentre === GC, timesheet.date - twelveDaysAgo > 0, timesheet.flightRecords.count > 0
            {
                aircraftMostRecentlyUsedAtCurrentGC.insert(aircraft)
            }
                
            else
            {
                if timesheet.date - twelveDaysAgo > 0, timesheet.flightRecords.count > 0
                {
                    aircraftMostRecentlyUsedAtCurrentGC.insert(aircraft)
                }
            }
            
            // TODO: What is the scenario where timesheet.flightRecords.count is 0 and we want to enter the following block? Please comment.
            if timesheet.flightRecords.count == 0
            {
                let timesheetsLastTwelveDaysRequest = AircraftTimesheet.request
                let timesheetsLastTwelveDaysPredicate = NSPredicate(format: "aircraft == %@ AND date > %@", argumentArray: [aircraft, twelveDaysAgo])
                let compoundPredicate: NSCompoundPredicate
                
                if siteSpecific
                {
                    let siteSpecificPredicate = NSPredicate(format: "glidingCentre == %@", argumentArray: [GC])
                    compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timesheetsLastTwelveDaysPredicate, siteSpecificPredicate])
                }
                    
                else
                {
                    compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timesheetsLastTwelveDaysPredicate])
                }
                
                timesheetsLastTwelveDaysRequest.predicate = compoundPredicate
                let timesheetsLastTwelveDays: [AircraftTimesheet]
                do {try timesheetsLastTwelveDays = dataModel.managedObjectContext.fetch(timesheetsLastTwelveDaysRequest)}
                catch {timesheetsLastTwelveDays = [AircraftTimesheet]()}
                
                for sheet in timesheetsLastTwelveDays
                {
                    if sheet.flightRecords.count > 0
                    {
                        aircraftMostRecentlyUsedAtCurrentGC.insert(aircraft)
                        break
                    }
                }
            }
        }
        
        let aircraftOrderedByTailNumber = Array(aircraftMostRecentlyUsedAtCurrentGC).sorted(by: numericSearch)
        
        switch (aircraftOrderedByTailNumber.count, siteSpecific)
        {
            case (0, true):
                generator.addLineOfText("No timesheets found for \(unit) in the past two weeks.")
            
            case (0, false):
                generator.addLineOfText("No timesheets found in the past two weeks.")
            
            default:
                generator.startTable([[ReportColumn(widthPercent: 15, title: "Vehicle"),
                                       ReportColumn(widthPercent: 30, title: "Issues"),
                                       ReportColumn(widthPercent: 10, title: "Date"),
                                       ReportColumn(widthPercent: 10, title: "Air Time"),
                                       ReportColumn(widthPercent: 10, title: "Ground Launches"),
                                       ReportColumn(widthPercent: 9, title: "Final TTSN"),
                                       ReportColumn(widthPercent: 8, title: "TNI"),
                                       ReportColumn(widthPercent: 8, title: "TTNI")]])
        }
        
        var last7Days = [Date]()
        var comps = DateComponents()
        for i in -6...0
        {
            comps.day = i
            let date = Calendar.current.date(byAdding: comps, to:Date())!.startOfDay
            last7Days.append(date)
        }
        
        for aircraft in aircraftOrderedByTailNumber
        {
            let TTNI = aircraft.TTNI.stringWithDecimal
            let timesheetsLastSevenDaysrequest = AircraftTimesheet.request
            let timesheetsLastSevenDaysPredicate = NSPredicate(format: "aircraft == %@ AND date > %@", argumentArray: [aircraft, last7Days.first!])
            var compoundPredicate: NSCompoundPredicate
            
            if siteSpecific
            {
                let sitePredicate = NSPredicate(format: "glidingCentre == %@",argumentArray: [GC])
                compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timesheetsLastSevenDaysPredicate, sitePredicate])
            }
                
            else
            {
                compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timesheetsLastSevenDaysPredicate])
            }
            
            timesheetsLastSevenDaysrequest.predicate = compoundPredicate
            let dateSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: true)
            timesheetsLastSevenDaysrequest.sortDescriptors = [dateSortDescriptor]
            let timesheetsLastFiveDays: [AircraftTimesheet]
            do {timesheetsLastFiveDays = try dataModel.managedObjectContext.fetch(timesheetsLastSevenDaysrequest)}
            catch {timesheetsLastFiveDays = [AircraftTimesheet]()}
            
            for date in last7Days
            {
                comps.day = 1
                let endOfDay = gregorian.date(byAdding: comps, to:date) ?? Date()
                
                var TTSNend: Decimal?
                var TTSNstart: Decimal?
                var groundLaunches = 0
                
                for timesheet in timesheetsLastFiveDays
                {
                    guard timesheet.date >= date else {continue}
                    guard timesheet.date < endOfDay else {break}
                    
                    if TTSNstart == nil
                    {
                        TTSNstart = timesheet.TTSNinitial
                    }
                    
                    TTSNend = timesheet.TTSNfinal
                    
                    for flightRecord in timesheet.flightRecords
                    {
                        if aircraft.type == .glider,
                            let launcherType = flightRecord.connectedAircraftRecord?.timesheet.aircraft.type,
                            launcherType < .towplane
                        {
                            groundLaunches += 1
                        }
                    }
                }
                
                // build the list of cell
                var cells = [ReportCell]()
                if date == last7Days.first
                {
                    cells.append(contentsOf: [ReportCell(rowSpan : last7Days.count, value : aircraft.registrationWithTailNumberInBrackets),
                                              ReportCell(rowSpan : last7Days.count, value : issuesString(from: aircraft.maintenanceItems, withSeparator: "<br>")),
                                              ReportCell(value : date.militaryFormatShort)])
                }
                else
                {
                    cells.append(ReportCell(value : date.militaryFormatShort))
                }
                
                if TTSNstart == nil
                {
                    cells.append(contentsOf: [ReportCell(value : "Not Flown"),
                                              ReportCell(value : "\(groundLaunches)"),
                                              ReportCell(value : ""),
                                              ReportCell(value : "")])
                }
                else
                {
                    if let TTSNstart = TTSNstart, let TTSNend = TTSNend
                    {
                        let timeForDay = TTSNend - TTSNstart
                        let hoursToNextInspection = aircraft.TTNI - (TTSNend as Decimal)
                        
                        cells.append(contentsOf: [ReportCell(value : timeForDay.stringWithDecimal),
                                                  ReportCell(value : "\(groundLaunches)"),
                                                  ReportCell(value : TTSNend.stringWithDecimal),
                                                  ReportCell(value : hoursToNextInspection.stringWithDecimal)])
                    }
                    else
                    {
                        cells.append(contentsOf: [ReportCell(value : "ERROR!"),
                                                  ReportCell(value : "\(groundLaunches)"),
                                                  ReportCell(value : ""),
                                                  ReportCell(value : "")])
                    }
                }
                
                if date == last7Days.first
                {
                    cells.append(ReportCell(rowSpan : last7Days.count, value : TTNI, vAlign: .bottom))
                }
                
                generator.addTableRow(cells)
            }
        }
        
        if aircraftOrderedByTailNumber.count > 0
        {
            generator.endTable()
        }
    }

    private func issuesString(from maintenanceEvents : Set<MaintenanceEvent>, withSeparator separator : String) -> String
    {
        var issues = ""
        
        for (index,issue) in maintenanceEvents.enumerated()
        {
            if index > 0
            {
                issues += separator
            }
            
            issues += "\(issue.comment) (\(issue.date.militaryFormatShort))"
        }
        
        return issues
    }

}

final class GlidingDay
{
    var squadronCadetsAttended = [Int: Int]()
    var siteForSquadron = [Int: String]()
    var squadronCadetsFlownInGlider = [Int: Int]()
    var totalGliderFlights = 0
    var totalScoutFams = 0
    
    func cadetsAttended(_ squadron: Int) -> Int
    {
        if let numberAttended = squadronCadetsAttended[squadron]
        {
            return numberAttended
        }
            
        else
        {
            squadronCadetsAttended[squadron] = 0
            squadronCadetsFlownInGlider[squadron] = 0
            return 0
        }
    }
    
    func cadetsFlownInGlider(_ squadron: Int) -> Int
    {
        return squadronCadetsFlownInGlider[squadron] ?? 0
    }
}
