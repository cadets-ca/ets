//
//  TimesheetsForDate.swift
//  Timesheets
//
//  Created by Hugues Ferland on 2019-11-30.
//

import Foundation

struct TimesheetsForDateParameters : RecipientAndSubjectProvider
{
    let dateOfTimesheets : Date
    let glidingCentre : GlidingCentre?
    let regionName : String
    let includeChangeLog : Bool
    
    var unit : String
    {
        return getGlidingCenterNameToUse()
    }

    func getSubject() -> String {
        return "\(getDateOfTimesheets()) \(getGlidingCenterNameToUse()) Timesheets"
    }
    
    func getRecipients() -> [String] {
        return UserDefaults().timesheetsAddressRecipients
    }
    
    private func getDateOfTimesheets() -> String
    {
        //let dateOfTimesheets = viewPreviousRecords ? dateToViewRecords : Date()
        let militaryFormat = DateFormatter()
        militaryFormat.dateFormat = "dd-MMMM-yyyy"
        militaryFormat.timeZone = TimeZone.current
        return militaryFormat.string(from: dateOfTimesheets)
    }
    
    private func getGlidingCenterNameToUse() -> String {
        return glidingCentre?.name ?? "Unknown Gliding Center"
    }
}

class TimesheetsForDate : Report
{
    private let param : TimesheetsForDateParameters
    private var dateToCreateRecords : Date!
    private var currentAircraftRegistration : String!
    private var currentAircraftCommonName : String!
    private var vehicleType : VehicleType!
    
    private lazy var gliderSequenceList: [String] =
        {
            if let myfile = Bundle.main.path(forResource: "GliderSequences", ofType:"plist")
            {
                return NSArray(contentsOfFile:myfile) as? [String] ?? [String]()
            }
                
            else
            {
                return [String]()
            }
    }()
    
    private lazy var towplaneSequenceList: [String] =
        {
            if let myfile = Bundle.main.path(forResource: "TowplaneSequences", ofType:"plist")
            {
                return NSArray(contentsOfFile:myfile) as? [String] ?? [String]()
            }
                
            else
            {
                return [String]()
            }
            
    }()

    init(_ param : TimesheetsForDateParameters)
    {
        self.param = param
    }

    func generate(with formatter: ReportFormatter)
    {
        formatter.setReportTitle("Gliding Timesheets")

        // TODO: How to include pagination using maximum number of lines in table. Just for the HTML/PDF report though. Don't make sense in other context...
        
        // TODO: must find out what this dateToCreateRecords really used for?
        dateToCreateRecords = param.dateOfTimesheets

        let beginningOfDay = param.dateOfTimesheets.midnight
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: beginningOfDay)!
        
        let request = AircraftTimesheet.request
        request.predicate = NSPredicate(format: "date > %@ AND date < %@ AND glidingCentre.name == %@", argumentArray: [beginningOfDay, endOfDay, param.unit])
        let tailNumberSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.aircraft.tailNumber), ascending: true)
        let dateSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: true)
        request.sortDescriptors = [tailNumberSortDescriptor, dateSortDescriptor]
        
        var timesheets = try! dataModel.managedObjectContext.fetch(request)
        timesheets = timesheets.filter{$0.flightRecords.count > 0}
        timesheets.sort(by: <)
        
        var scoutSequenceHours = [String: [String: Int]]()
        var scoutSequenceFlights = [String: [String: Int]]()
        var gliderSequenceHours = [String: [String: Int]]()
        var gliderSequenceFlights = [String: [String: Int]]()
        
        var winchTimesheets = [AircraftTimesheet]()
        var autoTimesheets = [AircraftTimesheet]()
        
        for timesheet in timesheets
        {
            var currentAircraftSequenceHours = [String: Int]()
            var currentAircraftSequenceFlights = [String: Int]()
            
            switch timesheet.aircraft.type
            {
                case .winch:
                    winchTimesheets.append(timesheet)
                    continue
                
                case .auto:
                    autoTimesheets.append(timesheet)
                    continue
                
                default:
                    break
            }
            
            let records = Array(timesheet.flightRecords).sorted {$0.timeUp < $1.timeUp}

            currentAircraftRegistration = timesheet.aircraft.registrationWithTailNumberInBrackets
            currentAircraftCommonName = "\(timesheet.aircraft.tailNumber)<br>\(timesheet.aircraft.registration)"
            
            // This code is for when there are multiple timesheets for a given aircraft on a given day
            var entryNumber = 1
            var fullEntryName = currentAircraftCommonName!
            
            while (gliderSequenceHours[fullEntryName] != nil || scoutSequenceHours[fullEntryName] != nil)
            {
                entryNumber += 1
                fullEntryName  = currentAircraftCommonName + " Entry \(entryNumber)"
            }
            
            currentAircraftCommonName = fullEntryName
            
            vehicleType = timesheet.aircraft.type
            
            startTimesheet(formatter)
            
            for recordBeingExamined in records
            {
                //starts a new row for the new entry
                var cells = [ReportCell]()

                if param.includeChangeLog
                {
                    cells.append(ReportCell(value: recordBeingExamined.recordID.hoursAndMinutes))
                }

                cells.append(ReportCell(value: recordBeingExamined.pilot?.fullName ?? ""))
                
                if vehicleType == .glider
                {
                    cells.append(ReportCell(value: recordBeingExamined.flightSequence == "Student Trg" ? "✓" : ""))
                }
                
                cells.append(ReportCell(value: recordBeingExamined.passenger?.fullName ?? ""))

                if vehicleType == .glider
                {
                    cells.append(ReportCell(value: recordBeingExamined.flightSequence == "Student Trg" ? "✓" : ""))
                }
                
                cells.append(contentsOf: [ReportCell(value: recordBeingExamined.timeUp.hoursAndMinutes),
                                          ReportCell(value: recordBeingExamined.timeDown == Date.distantFuture ? "?" : recordBeingExamined.timeDown.hoursAndMinutes),
                                          ReportCell(value: String(fromMinutes: Double(recordBeingExamined.flightLengthInMinutes))),
                                          ReportCell(value: sequence(recordBeingExamined, vehicleType)),
                                          ReportCell(value: recordBeingExamined.connectedAircraftRecord?.timesheet.aircraft.tailNumber ?? "")])
                
                formatter.addTableRow(cells)
                
                // The following code is for keeping track of the times by sequence
                
                if let sequenceFlightCountForCurrentAircraft = currentAircraftSequenceFlights[recordBeingExamined.flightSequence]
                {
                    currentAircraftSequenceFlights[recordBeingExamined.flightSequence] = sequenceFlightCountForCurrentAircraft + 1
                    let previousHours = currentAircraftSequenceHours[recordBeingExamined.flightSequence] ?? 0
                    let currentFlightTime = Int(recordBeingExamined.flightLengthInMinutes)
                    currentAircraftSequenceHours[recordBeingExamined.flightSequence] = previousHours + currentFlightTime
                }
                    
                else
                {
                    currentAircraftSequenceHours[recordBeingExamined.flightSequence] = Int(recordBeingExamined.flightLengthInMinutes)
                    currentAircraftSequenceFlights[recordBeingExamined.flightSequence] = 1
                }
                
            }
            
            //ends the timesheet if all the flights for that aircraft have been printed
            formatter.endTable()
            formatter.endPaginatedSection()
            
            currentAircraftSequenceHours["TTSNstart"] = timesheet.TTSNinitial.minutesFromHours
            currentAircraftSequenceHours["TTSNend"] = timesheet.TTSNfinal.minutesFromHours

            if vehicleType == .glider
            {
                gliderSequenceHours[currentAircraftCommonName] = currentAircraftSequenceHours
                gliderSequenceFlights[currentAircraftCommonName] = currentAircraftSequenceFlights
            }
                
            else
            {
                scoutSequenceHours[currentAircraftCommonName] = currentAircraftSequenceHours
                scoutSequenceFlights[currentAircraftCommonName] = currentAircraftSequenceFlights
            }
            
            if param.includeChangeLog
            {
                formatter.addNewSectionTitle("CHANGE LOG")
                formatter.startTable([[
                    ReportColumn(title: "Record ID"),
                    ReportColumn(title: "Edit Time"),
                    ReportColumn(title: "Editor Name"),
                    ReportColumn(title: "Editor License"),
                    ReportColumn(title: "Edit Description")]])
                
                let logComponents = timesheet.history.components(separatedBy: "*****")
                
                if logComponents.count < 5
                {
                    formatter.addTableRow([ReportCell(colSpan: 5, value: "No changes recorded after the original date of entry.")])
                }
                    
                else
                {
                    
                    var edits = [editInfo]()
                    
                    for i in stride(from: 0, to: logComponents.count, by: 5)
                    {
                        if i + 4 >= logComponents.count
                        {
                            continue
                        }
                        
                        edits.append(editInfo(data: Array(logComponents[i...(i+4)])))
                    }
                    
                    for edit in edits
                    {
                        formatter.addTableRow([ReportCell(value: edit.recordID),
                                               ReportCell(value: edit.editTime),
                                               ReportCell(value: edit.editor),
                                               ReportCell(value: edit.license),
                                               ReportCell(value: edit.description)])
                    }
                }

                formatter.endTable()
            }
        }
        
        if gliderSequenceHours.count > 0
        {
            timesheetSummaryForType(formatter, "Glider", for: .glider, withHours: &gliderSequenceHours, andFlights: &gliderSequenceFlights)
        }
        
        if scoutSequenceHours.count > 0
        {
            timesheetSummaryForType(formatter, "Towplane", for: .towplane, withHours: &scoutSequenceHours, andFlights: &scoutSequenceFlights)
        }
        
        if winchTimesheets.count > 0
        {
            winchSummaryFromTimesheets(formatter, winchTimesheets)
        }
        
        if autoTimesheets.count > 0
        {
            autoSummaryFromTimesheets(formatter, autoTimesheets)
        }
    }
    
    func getSubject() -> String
    {
        return param.getSubject()
    }
    
    private func startTimesheet(_ formatter: ReportFormatter, page: Int = 1)
    {
        formatter.startPaginatedSection()
        formatter.startRepeatingPart()
        timesheetTitle(formatter)
        timesheetHeader(formatter, page: page)
        timesheetStart(formatter)
        formatter.endRepeatingPart({formatter in formatter.endTable()})
    }
    
    private func timesheetTitle(_ formatter: ReportFormatter)
    {
        let type = vehicleType == .glider ? "GLIDER" : "TOWPLANE"
        
        formatter.addNewSectionTitle("\(param.regionName) REGION \(type) FLYING TIMES")
    }
    
    private func timesheetHeader(_ formatter: ReportFormatter, page: Int)
    {
        formatter.startTable([[ReportColumn(colSpan: 3, title: "A/C Reg: \(currentAircraftRegistration!)"),
                               ReportColumn(colSpan: 3, title: "Date: \(dateToCreateRecords.militaryFormatLong)"),
                               ReportColumn(colSpan: 3, title: "Sheet: {{currentPage}} of {{numberOfPage}}"),
                               ReportColumn(colSpan: 3, title: "Gliding Unit: \(param.unit)")]])
        formatter.endTable()
        formatter.addBlankLine()
    }
    
    private func timesheetStart(_ formatter: ReportFormatter)
    {
        var columns = [ReportColumn]()
        
        if param.includeChangeLog
        {
            columns.append(contentsOf: [ReportColumn(title: "Record<br>ID")])
        }
        
        if vehicleType == .glider
        {
            columns.append(contentsOf: [ReportColumn(title: "Pilot"),
                                        ReportColumn(title: "Inst<br>Auth"),
                                        ReportColumn(title: "Student /<Br>Passenger"),
                                        ReportColumn(title: "Student<br>Ack"),
                                        ReportColumn(title: "Time<Br>Up"),
                                        ReportColumn(title: "Time<Br>Down"),
                                        ReportColumn(title: "Air<Br>Time"),
                                        ReportColumn(title: "Sequence"),
                                        ReportColumn(title: "Launch<br>Vehicle")
            ])
        }
        else
        {
            columns.append(contentsOf: [ReportColumn(title: "Pilot"),
                                        ReportColumn(title: "Student /<Br>Passenger"),
                                        ReportColumn(title: "Time<Br>Up"),
                                        ReportColumn(title: "Time<Br>Down"),
                                        ReportColumn(title: "Air<Br>Time"),
                                        ReportColumn(title: "Sequence"),
                                        ReportColumn(title: "Glider<br>Towed")
            ])
        }
        
        formatter.startTable([columns])
    }

    private func endTimesheet(_ formatter: ReportFormatter)
    {
        formatter.endTable()
    }
    
    private func sequence(_ flight: FlightRecord, _ vehicleType : VehicleType) -> String
    {
        var text = sequenceAbbrev(flight.flightSequence, vehicleType)
        if flight.flightSequence == "Transit"
        {
            text += " \(flight.transitRoute)"
        }
        
        if let connectedRoute = flight.connectedAircraftRecord?.transitRoute,
            flight.connectedAircraftRecord?.flightSequence == "Transit"
        {
            text += " \(connectedRoute)"
        }
        
        return text
    }
    
    private func sequenceAbbrev(_ sequenceName : String, _ vehicleType : VehicleType) -> String
    {
        if vehicleType == .glider
        {
            if let sequence = GliderSequence(rawValue: sequenceName)
            {
                return sequence.abbreviation
            }
            else
            {
                return sequenceName
            }
        }
        else if let sequence = TowplaneSequence(rawValue: sequenceName)
        {
            return sequence.abbreviation
        }
            
        return sequenceName
    }
    
    private func timesheetSummaryForType(_ formatter : ReportFormatter, _ towplaneGlider: String, for vehicleType: VehicleType, withHours hours: inout [String: [String: Int]], andFlights flights: inout [String: [String: Int]])
    {
        //create the summary table and headers
        let vehicleTypeName = vehicleType == .glider ? "Glider" : "Towplane"
        formatter.addNewSectionTitle("\(param.regionName) REGION \(vehicleTypeName.uppercased()) SUMMARY \(dateToCreateRecords.militaryFormatLong.uppercased())")
        
        let aircraftIdents = Array(hours.keys).sorted(by: numericSearch)
        
        var summaryHeaderRow1 = [ReportColumn]()
        var summaryHeaderRow2 = [ReportColumn]()
        summaryHeaderRow1.append(ReportColumn(rowSpan: 2, title: "Sequence"))

        for ident in aircraftIdents
        {
            summaryHeaderRow1.append(ReportColumn(colSpan: 2, title: ident))
            summaryHeaderRow2.append(contentsOf: [ReportColumn(title: "Flights"),
                                         ReportColumn(title: "Hours")])
        }
        
        if aircraftIdents.count > 1
        {
            summaryHeaderRow1.append(ReportColumn(colSpan: 2, title: "All \(vehicleTypeName)s"))
            summaryHeaderRow2.append(contentsOf: [ReportColumn(title: "Flights"),
                                         ReportColumn(title: "Hours")])
        }
        
        formatter.startTable([summaryHeaderRow1, summaryHeaderRow2])
        
        //create the summary data
        addTotalForAircraftHours(&hours, andFlights: &flights)
        addTotalForType(vehicleTypeName, withHours: &hours, andFlights: &flights)
        
        guard let minutesTotals = hours["Total"] else
        {
            let colSpan = 1 + aircraftIdents.count * 2 + (aircraftIdents.count > 1 ? 2 : 0)
            formatter.addTableRow([ReportCell(colSpan: colSpan, value: "No total hours computed.")])
            formatter.endTable()
            return
        }
        
        for (sequenceKey, minutes) in minutesTotals
        {
            if (sequenceKey != "Total") && (sequenceKey != "TTSNstart") && (sequenceKey != "TTSNend")
            {
                var cells = [ReportCell]()
                cells.append(ReportCell(value: sequenceAbbrev(sequenceKey, vehicleType)))
                
                for ident in aircraftIdents
                {
                    if let flightValue = flights[ident]?[sequenceKey]
                    {
                        let formattedHours = String(fromMinutes: Double(hours[ident]![sequenceKey]!))
                        cells.append(contentsOf: [ReportCell(value: "\(flightValue)"),
                                                  ReportCell(value: formattedHours.decimalHoursValue)])
                    }
                        
                    else
                    {
                        cells.append(contentsOf: [ReportCell(value: "0"),
                                                  ReportCell(value: "0.0")])
                    }
                }
                
                if aircraftIdents.count > 1
                {
                    let formattedHours = String(fromMinutes: Double(minutes))
                    let flights = flights["Total"]![sequenceKey] ?? 0
                    cells.append(contentsOf: [ReportCell(value: "\(flights)"),
                                              ReportCell(value: formattedHours.decimalHoursValue)])
                }
                formatter.addTableRow(cells)
            }
        }
        
        var ttsnStartRow = [ReportCell]()
        ttsnStartRow.append(ReportCell(value: "TTSN Start"))
        
        for ident in aircraftIdents
        {
            let hourText = String(fromMinutes: Double(hours[ident]!["TTSNstart"]!))
            ttsnStartRow.append(contentsOf: [ReportCell(value: ""), ReportCell(value: hourText.decimalHoursValue)])
        }
        
        if aircraftIdents.count > 1
        {
            ttsnStartRow.append(ReportCell(colSpan: 2, value: ""))
        }
        
        formatter.addTotalRow(ttsnStartRow)
        
        var totalRow = [ReportCell]()
        totalRow.append(ReportCell(value: "Total"))
        
        for ident in aircraftIdents
        {
            let flightTotal = flights[ident]!["Total"] ?? 0
            let hourTotal = String(fromMinutes: Double(hours[ident]!["Total"]!))
            totalRow.append(contentsOf: [ReportCell(value: "\(flightTotal)"),
                                         ReportCell(value: hourTotal.decimalHoursValue)])
        }
        
        if aircraftIdents.count > 1
        {
            let flightTotal = flights["Total"]!["Total"] ?? 0
            let hourTotal = String(fromMinutes: Double(hours["Total"]!["Total"]!))
            totalRow.append(contentsOf: [ReportCell(value: "\(flightTotal)"),
                                         ReportCell(value: hourTotal.decimalHoursValue)])
        }
        formatter.addTotalRow(totalRow)
        
        var ttsnEndRow = [ReportCell]()
        ttsnEndRow.append(ReportCell(value: "TTSN End"))
        
        for ident in aircraftIdents
        {
            let hourTotal = String(fromMinutes: Double(hours[ident]!["TTSNend"]!))
            ttsnEndRow.append(contentsOf: [ReportCell(value: ""), ReportCell(value: hourTotal.decimalHoursValue)])
        }
        
        if aircraftIdents.count > 1
        {
            ttsnEndRow.append(ReportCell(colSpan: 2, value: ""))
        }
        formatter.addTotalRow(ttsnEndRow)
        formatter.endTable()
        formatter.addBlankLine()
        formatter.addBlankLine()
    }

    private func addTotalForAircraftHours(_ hours: inout [String: [String: Int]], andFlights flights: inout [String: [String: Int]])
    {
        func roundToDecimal(_ minutes: Int) -> Int
        {
            let modulus = minutes % 60
            let closestDecimal: Int
            switch modulus
            {
                case 0..<3:
                    closestDecimal = 0
                
                case 3..<9:
                    closestDecimal = 6
                
                case 9..<15:
                    closestDecimal = 12
                
                case 15..<21:
                    closestDecimal = 18
                
                case 21..<27:
                    closestDecimal = 24
                
                case 27..<33:
                    closestDecimal = 30
                
                case 33..<39:
                    closestDecimal = 36
                
                case 39..<45:
                    closestDecimal = 42
                
                case 45..<51:
                    closestDecimal = 48
                
                case 51..<57:
                    closestDecimal = 54
                
                default:
                    closestDecimal = 60
            }
            
            let adjustment = closestDecimal - modulus
            
            return minutes + adjustment
        }
        
        for (ident, aircraftData) in flights
        {
            let total = aircraftData.values.reduce(0, +)
            flights[ident]!["Total"] = total
        }
        
        for (ident, aircraftData) in hours
        {
            var totalMinutes = 0
            var sumOfSequences = 0
            
            for (sequence, minutes) in aircraftData
            {
                if (sequence == "TTSNstart") || (sequence == "TTSNend")
                {
                    continue
                }
                
                for (sequence, minutes) in aircraftData
                {
                    hours[ident]![sequence] = roundToDecimal(minutes)
                }
                
                totalMinutes += minutes
            }
            
            totalMinutes = roundToDecimal(totalMinutes)
            hours[ident]?["Total"] = totalMinutes
            
            for (sequence, minutes) in aircraftData
            {
                if (sequence == "TTSNstart") || (sequence == "TTSNend")
                {
                    continue
                }
                
                sumOfSequences += roundToDecimal(minutes)
            }
            
            let discrepancy = sumOfSequences - totalMinutes
            
            if discrepancy != 0
            {
                var largestSequence = ""
                var largestSequenceValue = 0
                
                for (sequence, _) in aircraftData
                {
                    if (sequence == "TTSNstart") || (sequence == "TTSNend") || (sequence == "Total")
                    {
                        continue
                    }
                    
                    if aircraftData[sequence]! > largestSequenceValue
                    {
                        largestSequenceValue = aircraftData[sequence] ?? 0
                        largestSequence = sequence
                    }
                }
                
                hours[ident]?[largestSequence] = largestSequenceValue - discrepancy
            }
        }
    }
    
    private func addTotalForType(_ towplaneGlider: String, withHours hours: inout [String: [String: Int]], andFlights flights: inout [String: [String: Int]])
    {
        var typeFlightTotals = [String: Int]()
        var typeHourTotals = [String: Int]()
        var flightCount = 0
        var minuteCount = 0
        
        let sequenceList = towplaneGlider == "Glider" ? gliderSequenceList : towplaneSequenceList
        
        for sequence in sequenceList
        {
            flightCount = 0
            minuteCount = 0
            for (ident, aircraftData) in flights
            {
                if let flightsOfSequenceForAircraft = aircraftData[sequence]
                {
                    flightCount += flightsOfSequenceForAircraft
                    
                    guard let aircraftHours = hours[ident] else {return}
                    guard let hoursOfSequenceForAircraft = aircraftHours[sequence] else {return}
                    minuteCount += hoursOfSequenceForAircraft
                }
            }
            
            if flightCount > 0
            {
                typeFlightTotals[sequence] = flightCount
                typeHourTotals[sequence] = minuteCount
            }
        }
        
        flightCount = typeFlightTotals.values.reduce(0, +)
        minuteCount = typeHourTotals.values.reduce(0, +)
        
        typeFlightTotals["Total"] = flightCount
        typeHourTotals["Total"] = minuteCount
        
        flights["Total"] = typeFlightTotals
        hours["Total"] = typeHourTotals
    }

    private func autoSummaryFromTimesheets(_ formatter: ReportFormatter, _ timesheets: [AircraftTimesheet])
    {
        //create the summary table and headers
        formatter.addNewSectionTitle("\(param.regionName) REGION AUTO SUMMARY \(dateToCreateRecords.militaryFormatLong.uppercased())")
        
        var autoRow1 = [ReportColumn]()
        var autoRow2 = [ReportColumn]()
        autoRow1.append(ReportColumn(title: ""))
        autoRow2.append(ReportColumn(title: "Launches" ))
        
        for sheet in timesheets
        {
            autoRow1.append(ReportColumn(title: sheet.aircraft.tailNumber))
            autoRow2.append(ReportColumn(title: "\(sheet.flightRecords.count)"))
        }
        
        formatter.startTable([autoRow1, autoRow2])
        formatter.endTable()
        formatter.addBlankLine()
        formatter.addBlankLine()
    }
    
    private func winchSummaryFromTimesheets(_ formatter: ReportFormatter, _ timesheets: [AircraftTimesheet])
    {
        //create the summary table and headers
        formatter.addNewSectionTitle("\(param.regionName) REGION WINCH SUMMARY \(dateToCreateRecords.militaryFormatLong.uppercased())")
        
        var winchRow1 = [ReportColumn]()
        var winchRow2 = [ReportColumn]()
        var winchRow3 = [ReportColumn]()
        var winchRow4 = [ReportColumn]()
        var winchRow5 = [ReportColumn]()
        winchRow1.append(ReportColumn(title: ""))
        winchRow2.append(ReportColumn(title: "TTSN Start"))
        winchRow3.append(ReportColumn(title: "Hours"))
        winchRow4.append(ReportColumn(title: "TTSN End"))
        winchRow5.append(ReportColumn(title: "Launches"))

        for sheet in timesheets
        {
            winchRow1.append(ReportColumn(title: sheet.aircraft.tailNumber))
            winchRow2.append(ReportColumn(title: sheet.TTSNinitial.stringWithDecimal))
            let hoursUsed = sheet.TTSNfinal - sheet.TTSNinitial
            winchRow3.append(ReportColumn(title: hoursUsed.stringWithDecimal))
            winchRow4.append(ReportColumn(title: sheet.TTSNfinal.stringWithDecimal))
            winchRow5.append(ReportColumn(title: "\(sheet.flightRecords.count)"))
        }

        formatter.startTable([winchRow1, winchRow2, winchRow3, winchRow4, winchRow5])
        formatter.endTable()
        formatter.addBlankLine()
        formatter.addBlankLine()
    }

}

fileprivate struct editInfo
{
    let recordID: String
    let editTime: String
    let editor: String
    let license: String
    let description: String
    
    init(data: [String])
    {
        recordID = data[0]
        editTime = data[1]
        editor = data[2]
        license = data[3]
        description = data[4]
    }
}
