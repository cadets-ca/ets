//
//  ReportGenerator.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-08.
//
//

import Foundation
import UIKit
import CoreData

final class ReportGenerator
{
    class func newInstance() -> ReportGenerator
    {
        return ReportGenerator()
    }
    
    var unit: String!
    var regionName: String!
    
    var regionNameString: String
    {
        get
        {
            if regionName == "PRAIRIE"
            {
                return "NORTHWEST"
            }
                
            else
            {
                return regionName ?? ""
            }
        }
    }
    
    lazy var sheetNumber = 1
    lazy var maxNumberOfFlightsIfSummaryOnSamePage = 10
    lazy var lineNumber = 0
    lazy var towplaneOrGlider = VehicleType.glider
    lazy var greyRow = false
    lazy var currentAircraftRegistration: String = ""
    lazy var currentAircraftCommonName: String = ""
    lazy var dateToCreateRecords = Date()
    
    lazy var gliderSequenceList: [String] =
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
    
    lazy var towplaneSequenceList: [String] =
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
    
    var sequenceList = [String]()
    
    // TODO: Remove GlidingDay once not used anymore in the file
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
    
    //MARK: - Top Level Methods
    func generatePilotLogsForDate(_ date: Date) -> (HTML: String, emailAddresses: [String])
    {
        var htmlString = "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always; margin: 1.5cm;}</STYLE><STYLE TYPE='text/css'>P.firstpage {margin: 1.5cm;}</STYLE><title>Pilot Logs</title></head><body><P CLASS='firstpage'>"
        
        let voidReturn = ("", [String]())
        guard let records = (regularFormat && dataModel.viewPreviousRecords) ? dataModel.previousRecordsController?.fetchController : dataModel.recordAreaController?.fetchController else {return voidReturn}
        
        var namesOfPilotsWhoFlew = Set<Pilot>()
        
        for record in records.fetchedObjects ?? [FlightRecord]()
        {
            let pilot = record.pilot!
            
            if (pilot.gliderQual >= .student) || (pilot.towQual >= .towPilot)
            {
                namesOfPilotsWhoFlew.insert(pilot)
            }
            
            guard let passenger = record.passenger else {continue}
            if (passenger.gliderQual >= .student) || (passenger.towQual >= .towPilot)
            {
                namesOfPilotsWhoFlew.insert(passenger)
            }
        }
        
        let pilotNames = Array(namesOfPilotsWhoFlew).sorted {$0.name < $1.name}
        
        let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
        let midnight = date.midnight
        let tonightAtMidnight = midnight + 86400
        
        let hoursMinutes = DateFormatter()
        hoursMinutes.dateFormat = "HHmm"
        hoursMinutes.timeZone = TimeZone.current
        
        var emailAddresses = [String]()
        
        for pilot in pilotNames
        {
            if pilot.email != ""
            {
                emailAddresses.append(pilot.email)
            }
            
            greyRow = false
            htmlString += "<big>\(pilot.fullName.uppercased()) FLYING TIMES</big><br>"
            addPilotTableToString(&htmlString)
            
            let request = FlightRecord.request
            request.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND (pilot == %@ OR passenger == %@)", argumentArray: [midnight, tonightAtMidnight,pilot, pilot])
            request.sortDescriptors = [timeUpSortDescriptor]
            let pilotsFlights = try! dataModel.managedObjectContext.fetch(request)
            
            var numberOfWinchLaunches = 0
            var numberOfAutoLaunches = 0
            
            for record in pilotsFlights
            {
                if record.timesheet.aircraft.type == .winch
                {
                    numberOfWinchLaunches += 1
                    continue
                }
                
                if record.timesheet.aircraft.type == .auto
                {
                    numberOfAutoLaunches += 1
                    continue
                }
                
                beginHTMLtableRow(&htmlString)
                
                var aircraftName = record.timesheet.aircraft.tailNumber
                
                var launchMethodString = ""
                
                if let connectedAircraftRecord = record.connectedAircraftRecord
                {
                    switch connectedAircraftRecord.timesheet.aircraft.type
                    {
                        case .towplane:
                            launchMethodString = " Air Tow"
                        
                        case .winch:
                            launchMethodString = " Winch"
                        
                        case .glider:
                            launchMethodString = ""
                        
                        case .auto:
                            launchMethodString = " Auto Tow"
                    }
                }
                
                if record.timesheet.aircraft.registration == record.timesheet.aircraft.tailNumber
                {
                    if launchMethodString != ""
                    {
                        aircraftName += " (\(launchMethodString))"
                    }
                }
                    
                else
                {
                    aircraftName += " (\(record.timesheet.aircraft.registration)\(launchMethodString))"
                }
                
                addTableCellToHTMLcode(&htmlString, withText: aircraftName)
                addTableCellToHTMLcode(&htmlString, withText: record.pilot.fullName)
                
                let passengerString: String
                
                if let passenger = record.passenger, (passenger.typeOfParticipant == "cadet")
                {
                    passengerString = "\(passenger.fullName) (\(passenger.squadron) RCACS)"
                }
                    
                else
                {
                    passengerString = record.passenger?.fullName ?? ""
                }
                
                addTableCellToHTMLcode(&htmlString, withText: passengerString)
                
                let upTime = hoursMinutes.string(from: record.timeUp)
                let downTime: String
                
                downTime = record.timeDown == Date.distantFuture ? "?" : hoursMinutes.string(from: record.timeDown)
                
                addTableCellToHTMLcode(&htmlString, withText: upTime)
                addTableCellToHTMLcode(&htmlString, withText: downTime)
                addTableCellToHTMLcode(&htmlString, withText: String(fromMinutes: Double(record.flightLengthInMinutes)))
                
                var text = record.flightSequence
                
                if text == "Transit"
                {
                    text += " "
                    text += record.transitRoute
                }
                
                addTableCellToHTMLcode(&htmlString, withText:text)
                endHTMLtableRow(&htmlString)
            }
            
            htmlString += "</table>"
            
            if numberOfWinchLaunches > 0
            {
                htmlString += "<br>\(numberOfWinchLaunches) winch launch"
                
                if numberOfWinchLaunches > 1
                {
                    htmlString += "es"
                }
            }
            
            if numberOfAutoLaunches > 0
            {
                htmlString += "<br>\(numberOfAutoLaunches) auto launch"
                
                if numberOfAutoLaunches > 1
                {
                    htmlString += "es"
                }
            }
            
            htmlString += "<P CLASS='pagebreakhere'><br>"
        }
        
        htmlString += "</body></html>"
        try? htmlString.write(toFile: saveFilePath(), atomically: true, encoding: String.Encoding.unicode)
        
        return (htmlString, emailAddresses)
    }
    
    func personalLogBookForPilot(_ pilot: Pilot, fromDate startDate: Date, toDate endDate:Date) -> String
    {
        var reportHeaders = "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always; margin: 1.5cm;}</STYLE><STYLE TYPE='text/css'>P.firstpage {margin: 1.5cm;}</STYLE><title>Pilot Logs</title></head><body><P CLASS='firstpage'>"
        var gliderLogBook = ""
        var towplaneLogBook = ""
        
        let recordFetchRequest = FlightRecord.request
        recordFetchRequest.predicate = NSPredicate(format: "(%K == %@ OR %K == %@) AND %K > %@ AND %K < %@", argumentArray: [#keyPath(FlightRecord.pilot), pilot, #keyPath(FlightRecord.passenger), pilot, #keyPath(FlightRecord.timeUp), startDate, #keyPath(FlightRecord.timeUp), endDate])
        let timeUpSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending: true)
        recordFetchRequest.sortDescriptors = [timeUpSortDescriptor]
        let flightRecords = try! dataModel.managedObjectContext.fetch(recordFetchRequest)
        
        gliderLogBook += "<big>\(pilot.fullName.uppercased()) GLIDER LOG BOOK \(startDate.militaryFormatShort.uppercased()) to \(endDate.militaryFormatShort.uppercased())</big>"
        gliderLogBook += "<table border='1'>"
        
        gliderLogBook.appendTableRow(header: true)
        {
            var gliderHeader = tableHeaderCell(headerText: "Date")
            gliderHeader += tableHeaderCell(headerText: "Gliding Centre")
            gliderHeader += tableHeaderCell(headerText: "Aircraft")
            gliderHeader += tableHeaderCell(headerText: "Launch Method")
            gliderHeader += tableHeaderCell(headerText: "Pilot")
            gliderHeader += tableHeaderCell(headerText: "Passenger")
            gliderHeader += tableHeaderCell(headerText: "PIC")
            gliderHeader += tableHeaderCell(headerText: "Dual")
            gliderHeader += tableHeaderCell(headerText: "Instructor")
            gliderHeader += tableHeaderCell(headerText: "Sequence")
            
            return gliderHeader
        }
        
        towplaneLogBook += "<big>\(pilot.fullName.uppercased()) TOW AIRCRAFT LOG BOOK \(startDate.militaryFormatShort.uppercased()) to \(endDate.militaryFormatShort.uppercased())</big>"
        towplaneLogBook += "<table border='1'>"
        towplaneLogBook.appendTableRow(header: true)
        {
            var towplaneHeader = tableHeaderCell(headerText: "Date")
            towplaneHeader += tableHeaderCell(headerText: "Gliding Centre")
            towplaneHeader += tableHeaderCell(headerText: "Aircraft")
            towplaneHeader += tableHeaderCell(headerText: "Pilot")
            towplaneHeader += tableHeaderCell(headerText: "Passenger")
            towplaneHeader += tableHeaderCell(headerText: "PIC")
            towplaneHeader += tableHeaderCell(headerText: "Dual")
            towplaneHeader += tableHeaderCell(headerText: "Sequence")
            towplaneHeader += tableHeaderCell(headerText: "Tows")
            
            return towplaneHeader
        }
        
        var blockEntry = false
        var blockEntryUpTime = Date()
        var blockEntryDownTime = Date()
        var blockEntryPilot: Pilot? = pilot
        var blockEntryPassenger: Pilot? = pilot
        var blockEntrySequence = ""
        var blockEntryTows = 0
        var blockEntryGlidingCentre: GlidingCentre?
        var blockEntryAircraft: AircraftEntity?
        let blockEntryMargin = 60*15 as Double //Tow entries are blocked if one landing to the next take-off is less than 15 minutes
        
        var totalGliderPICtime = 0
        var totalGliderDualTime = 0
        var totalGliderInstructorTime = 0
        
        var totalTowPICtime = Decimal(0)
        var totalTowDualTime = Decimal(0)
        var totalTows = 0
        
        var towplaneRowShouldBeShaded = false
        var gliderRowShouldBeShaded = false
        
        func completeTowAircraftBlockEntry()
        {
            towplaneLogBook.appendTableRow(shading: towplaneRowShouldBeShaded)
            {
                towplaneRowShouldBeShaded = !towplaneRowShouldBeShaded
                var entryText = tableCell(text: blockEntryUpTime.militaryFormatShort)
                entryText += tableCell(text: blockEntryGlidingCentre?.name)
                entryText += tableCell(text: blockEntryAircraft?.registrationWithTailNumberInBrackets)
                entryText += tableCell(text: blockEntryPilot?.fullName)
                entryText += tableCell(text: blockEntryPassenger?.fullName)
                
                let blockDurationInHours = (blockEntryDownTime - blockEntryUpTime) / 3600
                let shiftFlightTime = Decimal(round(blockDurationInHours * 10) / 10)
                
                if blockEntryPilot === pilot
                {
                    entryText += tableCell(text: shiftFlightTime.stringWithDecimal)
                    entryText += tableCell()
                    totalTowPICtime += shiftFlightTime
                }
                    
                else
                {
                    entryText += tableCell()
                    entryText += tableCell(text: shiftFlightTime.stringWithDecimal)
                    totalTowDualTime += shiftFlightTime
                }
                
                entryText += tableCell(text: blockEntrySequence)
                
                totalTows += blockEntryTows
                entryText += tableCell(text: "\(blockEntryTows)")
                
                return entryText
            }
        }
        
        for record in flightRecords
        {
            if record.timesheet?.aircraft?.type == .glider
            {
                if blockEntry
                {
                    completeTowAircraftBlockEntry()
                    blockEntry = false
                    blockEntryTows = 0
                }
                
                gliderLogBook.appendTableRow(shading: gliderRowShouldBeShaded)
                {
                    gliderRowShouldBeShaded = !gliderRowShouldBeShaded
                    var entryText = tableCell(text: record.timeUp.militaryFormatShort)
                    entryText += tableCell(text: record.timesheet!.glidingCentre!.name)
                    entryText += tableCell(text: record.timesheet!.aircraft!.registrationWithTailNumberInBrackets)
                    
                    switch record.connectedAircraftRecord?.timesheet?.aircraft?.type
                    {
                        case let type where type == .towplane:
                            entryText += tableCell(text: "Air Tow")
                        
                        case let type where type == .winch:
                            entryText += tableCell(text: "Winch")
                        
                        default:
                            entryText += tableCell(text: "Auto Tow")
                    }
                    
                    entryText += tableCell(text: record.pilot!.fullName)
                    
                    let passengerString: String?
                    
                    if let passenger = record.passenger, passenger.typeOfParticipant == "cadet"
                    {
                        let squadron = String(Int(passenger.squadron)) 
                        passengerString = passenger.fullName + " (\(squadron) RCACS)"
                    }
                        
                    else
                    {
                        passengerString = record.passenger?.fullName
                    }
                    
                    entryText += tableCell(text: passengerString)
                    let flightTimeString = String(fromMinutes: Double(record.flightLengthInMinutes))
                    
                    if record.passenger === pilot
                    {
                        entryText += tableCell()
                        entryText += tableCell(text: flightTimeString)
                        totalGliderDualTime += Int(record.flightLengthInMinutes)
                        entryText += tableCell()
                    }
                        
                    else if (pilot.gliderQual > .rearSeatFamil) && (record.flightSequence != "Famil") && (record.flightSequence != "Maintenance")
                    {
                        entryText += tableCell()
                        entryText += tableCell()
                        entryText += tableCell(text: flightTimeString)
                        totalGliderInstructorTime += Int(record.flightLengthInMinutes)
                    }
                        
                    else
                    {
                        entryText += tableCell(text: flightTimeString)
                        entryText += tableCell()
                        entryText += tableCell()
                        totalGliderPICtime += Int(record.flightLengthInMinutes)
                    }
                    
                    if record.flightSequence == "Transit"
                    {
                        entryText += tableCell(text: "\(record.flightSequence) (\(record.transitRoute))")
                    }
                        
                    else
                    {
                        entryText += tableCell(text: record.flightSequence)
                    }
                    
                    return entryText
                }
            }
            
            if record.timesheet?.aircraft?.type == .towplane
            {
                func beginBlockEntry()
                {
                    blockEntry = true
                    blockEntryUpTime = record.timeUp
                    blockEntryDownTime = record.timeDown
                    blockEntryPilot = record.pilot
                    blockEntryPassenger = record.passenger
                    blockEntryGlidingCentre = record.timesheet.glidingCentre
                    blockEntryAircraft = record.timesheet.aircraft
                }
                
                if blockEntry && ((record.timeUp - blockEntryDownTime > blockEntryMargin) || (record.pilot !== blockEntryPilot) || (record.passenger !== blockEntryPassenger) || (record.flightSequence != blockEntrySequence) || (record.timesheet.aircraft !== blockEntryAircraft))
                {
                    
                    completeTowAircraftBlockEntry()
                    
                    blockEntryTows = 0
                    beginBlockEntry()
                    
                    if record.flightSequence == "Transit"
                    {
                        blockEntrySequence = record.flightSequence + " (\(record.transitRoute))"
                    }
                        
                    else
                    {
                        blockEntrySequence = record.flightSequence
                    }
                    
                    if record.flightSequence == "Towing"
                    {
                        blockEntryTows += 1
                    }
                }
                    
                else if blockEntry
                {
                    blockEntryDownTime = record.timeDown
                    if record.flightSequence == "Towing"
                    {
                        blockEntryTows += 1
                    }
                }
                    
                else
                {
                    beginBlockEntry()
                    
                    if record.flightSequence == "Transit"
                    {
                        blockEntrySequence = record.flightSequence + " (\(record.transitRoute))"
                    }
                        
                    else
                    {
                        blockEntrySequence = record.flightSequence
                    }
                    
                    if record.flightSequence == "Towing"
                    {
                        blockEntryTows += 1
                    }
                }
            }
        }
        
        if blockEntry
        {
            towplaneLogBook.appendTableRow(shading: towplaneRowShouldBeShaded)
            {
                towplaneRowShouldBeShaded = !towplaneRowShouldBeShaded
                var entryText = tableCell(text: blockEntryUpTime.militaryFormatShort)
                entryText += tableCell(text: blockEntryGlidingCentre?.name)
                
                let aircraftName = blockEntryAircraft?.registrationWithTailNumberInBrackets
                entryText += tableCell(text: aircraftName)
                entryText += tableCell(text: blockEntryPilot?.fullName)
                entryText += tableCell(text: blockEntryPassenger?.fullName)
                
                let blockDurationInHours = (blockEntryDownTime - blockEntryUpTime) / 3600
                let shiftFlightTime = Decimal(round(blockDurationInHours * 10) / 10)
                
                if blockEntryPilot === pilot
                {
                    entryText += tableCell(text: shiftFlightTime.stringWithDecimal)
                    entryText += tableCell()
                    totalTowPICtime += shiftFlightTime
                }
                    
                else
                {
                    entryText += tableCell()
                    entryText += tableCell(text: shiftFlightTime.stringWithDecimal)
                    totalTowDualTime += shiftFlightTime
                }
                
                entryText += tableCell(text: blockEntrySequence)
                
                let totalTowsString = "\(blockEntryTows)"
                totalTows += blockEntryTows
                entryText += tableCell(text: totalTowsString)
                
                return entryText
            }
        }
        
        let totalGliderPICstring = String(fromMinutes: Double(totalGliderPICtime))
        let totalGliderDualString = String(fromMinutes: Double(totalGliderDualTime))
        let totalGliderInstructorString = String(fromMinutes: Double(totalGliderInstructorTime))
        
        gliderLogBook.appendTableRow(header: true)
        {
            var gliderLogBookHeaderText = tableHeaderCell()
            gliderLogBookHeaderText += tableHeaderCell()
            gliderLogBookHeaderText += tableHeaderCell()
            gliderLogBookHeaderText += tableHeaderCell()
            gliderLogBookHeaderText += tableHeaderCell()
            gliderLogBookHeaderText += tableHeaderCell()
            gliderLogBookHeaderText += tableHeaderCell(headerText: totalGliderPICstring)
            gliderLogBookHeaderText += tableHeaderCell(headerText: totalGliderDualString)
            gliderLogBookHeaderText += tableHeaderCell(headerText: totalGliderInstructorString)
            gliderLogBookHeaderText += tableHeaderCell()
            
            return gliderLogBookHeaderText
        }
        
        gliderLogBook += "</table>"
        
        towplaneLogBook.appendTableRow(header: true)
        {
            var towLogBookHeaderText = tableHeaderCell()
            towLogBookHeaderText += tableHeaderCell()
            towLogBookHeaderText += tableHeaderCell()
            towLogBookHeaderText += tableHeaderCell()
            towLogBookHeaderText += tableHeaderCell()
            towLogBookHeaderText += tableHeaderCell(headerText: totalTowPICtime.stringWithDecimal)
            towLogBookHeaderText += tableHeaderCell(headerText: totalTowDualTime.stringWithDecimal)
            towLogBookHeaderText += tableHeaderCell()
            towLogBookHeaderText += tableHeaderCell(headerText: "\(totalTows)")
            
            return towLogBookHeaderText
        }
        
        towplaneLogBook += "</table>"
        
        reportHeaders += gliderLogBook
        reportHeaders += "<P CLASS='pagebreakhere'>"
        reportHeaders += towplaneLogBook
        
        try? reportHeaders.write(toFile: saveFilePath(), atomically: true, encoding: String.Encoding.unicode)
        
        return reportHeaders
    }
    
    func generatePTRreport() -> String
    {
        let GC = (regularFormat && dataModel.viewPreviousRecords) ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre
        
        var report = "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always; margin: 1.5cm;}</STYLE><STYLE TYPE='text/css'>P.firstpage {margin: 1.5cm;}</STYLE><title>Pilot Logs</title></head><body><P CLASS='firstpage'>"
        
        let yearAgo = Date() + -1*365*24*60*60
        let now = Date()
        let distantPast = Date.distantPast
        
        let pilotFetchRequest = Pilot.request
        pilotFetchRequest.predicate = NSPredicate(format: "glidingCentre == %@ AND inactive == NO AND typeOfParticipant != %@ AND typeOfParticipant != %@", GC!, "cadet", "guest")
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.name), ascending: true)
        pilotFetchRequest.sortDescriptors = [nameSortDescriptor]
        let sortedPilots = try! dataModel.managedObjectContext.fetch(pilotFetchRequest)
        
        report += "<big>\(unit!.uppercased()) PTR REPORT \(now.militaryFormatLong.uppercased())</big><br>"
        report += "<table border='1'><P CLASS='firstpage'>"
        report += "<tr bgcolor='#CCCCCC'><th rowspan='2'>Name</th><th rowspan='2'>Type of<br>Participant</th><th rowspan='2'>Cadet Age<br>Out Date</th><th rowspan='2'>Squadron</th><th rowspan='2'>Medical<br>Expiry</th><th colspan='14'>Gliding</th><th colspan='4'>Winch</th><th colspan='8'>Tow Aircraft</th></tr>"
        report += "<tr bgcolor='#CCCCCC'><th>Glider<br>License</th><th>FSF</th><th>RSF</th><th>Instructor</th><th>Check</th><th>Standards</th><th>X-Country</th><th>Current<br>Until</th><th>APC Date</th><th>FI Expiry</th><th>Glider PIC</th><th>Glider Dual</th><th>Glider<br>Instructor</th><th>Flights Last<br>365 Days</th><th>Winch<br>Pilot</th><th>Winch<br>Operator</th><th>Winch<br>Instructor</th><th>Retrieve</th><th>Power<br>License</th><th>Tow Pilot</th><th>X-Country</th><th>Check</th><th>Standards</th><th>Current<br>Until</th><th>APC Date</th><th>Flights Last<br>365 Days</th></tr>"
        
        let threeMonthsFromNow = now + Double(90*24*60*60)
        let oneMonthFromNow = now + Double(30*24*60*60)
        
        for pilot in sortedPilots
        {
            if (pilot.name == "")
            {
                continue
            }
            
            let stats365 = pilot.flyingStatsFromDate(yearAgo, toDate:now)
            let allTimeStats = pilot.flyingStatsFromDate(distantPast, toDate:now)
            
            beginHTMLtableRow(&report)
            addTableCellToHTMLcode(&report, withText: pilot.fullName)
            addTableCellToHTMLcode(&report, withText: pilot.typeOfParticipant)
            
            switch (pilot.typeOfParticipant, pilot.ageOutDate)
            {
                case ("Staff Cadet", Date.distantPast):
                    addTableCellToHTMLcode(&report, withText: "?", andTextColor: .red)
                
                case ("Staff Cadet", Date.distantPast ..< now):
                    addTableCellToHTMLcode(&report, withText: pilot.ageOutDate.militaryFormatShort, andTextColor: .red)
                
                case ("Staff Cadet", now ..< threeMonthsFromNow):
                    addTableCellToHTMLcode(&report, withText: pilot.ageOutDate.militaryFormatShort, andTextColor: .yellow)
                
                case ("Staff Cadet", _):
                    addTableCellToHTMLcode(&report, withText: pilot.ageOutDate.militaryFormatShort, andTextColor: .defaultColor)
                
                default:
                    addTableCellToHTMLcode(&report, withText: "N/A")
            }
            
            switch (pilot.typeOfParticipant, pilot.squadron)
            {
                case let (_, squadronNumber) where squadronNumber != 0:
                    addTableCellToHTMLcode(&report, withText: "\(squadronNumber)")
                
                case ("Staff Cadet", _):
                    addTableCellToHTMLcode(&report, withText: nil, andTextColor: .red)
                
                default:
                    addTableCellToHTMLcode(&report, withText: nil, andTextColor: .defaultColor)
            }
            
            switch pilot.medical
            {
                case Date.distantPast ..< now:
                    addTableCellToHTMLcode(&report, withText: "", andTextColor: .red)
                
                case threeMonthsFromNow ..< Date.distantFuture:
                    addTableCellToHTMLcode(&report, withText: pilot.medical.militaryFormatShort, andTextColor: .defaultColor)
                
                default:
                    addTableCellToHTMLcode(&report, withText: pilot.medical.militaryFormatShort, andTextColor: .yellow)
            }
            
            if pilot.gliderQual > .noGlider
            {
                let gliderLicenseNumbers = pilot.gliderLicense.trimmingCharacters(in: CharacterSet.letters)
                
                if gliderLicenseNumbers.count > 2
                {
                    addTableCellToHTMLcode(&report, withText: pilot.gliderLicense, andTextColor: .defaultColor)
                }
                    
                else
                {
                    addTableCellToHTMLcode(&report, withText: pilot.gliderLicense, andTextColor: .red)
                }
                
                
                pilot.gliderQual >= .frontSeatFamil ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.gliderQual >= .rearSeatFamil ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.gliderQual >= .instructor ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.gliderQual >= .checkPilot ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.gliderQual >= .standardsPilot ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.pilotHoldsQual("Glider Xcountry") ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                
                let (APCexpiresBeforeCurrency, currencyDate) = pilot.calculateCurrencyDateOnType(.glider)
                
                var currencyString = APCexpiresBeforeCurrency ? currencyDate.militaryFormatShort + "  (APC)" : currencyDate.militaryFormatShort
                
                switch currencyDate
                {
                    case oneMonthFromNow ... (Date.distantFuture):
                        addTableCellToHTMLcode(&report, withText: currencyString, andTextColor: .defaultColor)
                    
                    case (Date.distantPast) ..< now:
                        currencyString = APCexpiresBeforeCurrency ? "Expired APC" : "Expired"
                        addTableCellToHTMLcode(&report, withText: currencyString, andTextColor: .red)
                    
                    default:
                        addTableCellToHTMLcode(&report, withText: currencyString, andTextColor: .yellow)
                }
                
                if pilot.aniversaryOfGliderAPC > Date() - 100*365*24*60*60
                {
                    addTableCellToHTMLcode(&report, withText: pilot.aniversaryOfGliderAPC.militaryFormatShort, andTextColor: .defaultColor)
                }
                    
                else
                {
                    addTableCellToHTMLcode(&report, withText: "?", andTextColor: .red)
                }
                
                if pilot.gliderQual > .rearSeatFamil
                {
                    switch pilot.fiExpiry
                    {
                        case threeMonthsFromNow ..< Date.distantFuture:
                            addTableCellToHTMLcode(&report, withText: pilot.fiExpiry.militaryFormatShort, andTextColor: .defaultColor)
                        
                        case now ... threeMonthsFromNow:
                            addTableCellToHTMLcode(&report, withText: pilot.fiExpiry.militaryFormatShort, andTextColor: .yellow)
                        
                        case Date.distantPast ..< now:
                            addTableCellToHTMLcode(&report, withText: pilot.fiExpiry.militaryFormatShort, andTextColor: .red)
                        
                        default:
                            addTableCellToHTMLcode(&report, withText: "?", andTextColor: .red)
                    }
                }
                    
                else
                {
                    addTableCellToHTMLcode(&report, withText: "N/A")
                }
                
                let gliderPICstring = String(fromMinutes: Double(allTimeStats.gliderPICminutes) + Double(pilot.gliderPIChoursAdjust))
                let gliderDualString = String(fromMinutes: Double(allTimeStats.gliderDualMinutes))
                let gliderInstructorString = String(fromMinutes: Double(allTimeStats.gliderInstructorMinutes) + Double(pilot.gliderInstHoursAdjust))
                
                addTableCellToHTMLcode(&report, withText: gliderPICstring)
                addTableCellToHTMLcode(&report, withText: gliderDualString)
                addTableCellToHTMLcode(&report, withText: gliderInstructorString)
                
                let gliderFlightsNumber = stats365.gliderFlights
                
                switch gliderFlightsNumber
                {
                    case 0 ..< 10:
                        addTableCellToHTMLcode(&report, withText: "\(gliderFlightsNumber)", andTextColor: .red)
                    
                    case 10 ..< 20:
                        addTableCellToHTMLcode(&report, withText: "\(gliderFlightsNumber)", andTextColor: .yellow)
                    
                    case 20 ..< 75:
                        addTableCellToHTMLcode(&report, withText: "\(gliderFlightsNumber)", andTextColor: .defaultColor)
                    
                    default:
                        addTableCellToHTMLcode(&report, withText: "\(gliderFlightsNumber)", andTextColor: .green)
                }
                
                pilot.pilotHoldsQual("Winch Launch") ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
            }
                
            else
            {
                for _ in 1...15
                {
                    addTableCellToHTMLcode(&report, withText: "N/A")
                }
            }
            
            let winchLaunchNumber = allTimeStats.launchesAsWinchOperator
            
            if pilot.pilotHoldsQual("Winch Operator")
            {
                addTableCellToHTMLcode(&report, withText: "\(winchLaunchNumber) Launches")
            }
                
            else
            {
                addTableCellToHTMLcode(&report, withText: "✗")
            }
            
            pilot.pilotHoldsQual("Winch Launch Instructor") ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
            pilot.pilotHoldsQual("Winch Retrieve Driver") ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
            
            let powerLicenseNumbers = pilot.powerLicense.trimmingCharacters(in: CharacterSet.letters)
            
            switch powerLicenseNumbers.count
            {
                case let licenseNumberCount where licenseNumberCount > 2:
                    addTableCellToHTMLcode(&report, withText: powerLicenseNumbers, andTextColor: .defaultColor)
                
                default:
                    if pilot.towQual > .noScout
                    {
                        addTableCellToHTMLcode(&report, withText: powerLicenseNumbers, andTextColor: .red)
                    }
                        
                    else
                    {
                        addTableCellToHTMLcode(&report, withText: powerLicenseNumbers, andTextColor: .defaultColor)
                }
            }
            
            if pilot.towQual > .noScout
            {
                addTableCellToHTMLcode(&report, withText: "✓")
                pilot.pilotHoldsQual("Tow Xcountry") ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.towQual > .towCheckPilot ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                pilot.towQual > .towStandardsPilot ? addTableCellToHTMLcode(&report, withText: "✓") : addTableCellToHTMLcode(&report, withText: "✗")
                
                let (APCexpiresBeforeCurrency, currencyDate) = pilot.calculateCurrencyDateOnType(.towplane)
                
                var currencyString = APCexpiresBeforeCurrency ? "\(currencyDate.militaryFormatShort) (APC)" : currencyDate.militaryFormatShort
                
                switch currencyDate
                {
                    case oneMonthFromNow ... (Date.distantFuture):
                        addTableCellToHTMLcode(&report, withText: currencyString, andTextColor: .defaultColor)
                    
                    case (Date.distantPast) ..< now:
                        currencyString = APCexpiresBeforeCurrency ? "Expired APC" : "Expired"
                        addTableCellToHTMLcode(&report, withText: currencyString, andTextColor: .red)
                    
                    default:
                        addTableCellToHTMLcode(&report, withText: currencyString, andTextColor: .yellow)
                }
                
                if pilot.aniversaryOfTowAPC > oneHundredYearsAgo
                {
                    addTableCellToHTMLcode(&report, withText: pilot.aniversaryOfTowAPC.militaryFormatShort, andTextColor: .defaultColor)
                }
                    
                else
                {
                    addTableCellToHTMLcode(&report, withText: "?", andTextColor: .red)
                }
                
                let towFlightsNumber = stats365.towAircraftTows
                
                switch towFlightsNumber
                {
                    case 0 ..< 10:
                        addTableCellToHTMLcode(&report, withText: "\(towFlightsNumber)", andTextColor: .red)
                    
                    case 10 ..< 20:
                        addTableCellToHTMLcode(&report, withText: "\(towFlightsNumber)", andTextColor: .yellow)
                    
                    case 20 ..< 100:
                        addTableCellToHTMLcode(&report, withText: "\(towFlightsNumber)", andTextColor: .defaultColor)
                    
                    default:
                        addTableCellToHTMLcode(&report, withText: "\(towFlightsNumber)", andTextColor: .green)
                }
            }
                
            else
            {
                addTableCellToHTMLcode(&report, withText: "✗")
                
                for _ in 1...6
                {
                    addTableCellToHTMLcode(&report, withText: "N/A")
                }
            }
            
            endHTMLtableRow(&report)
        }
        
        report += "</table>"
        try? report.write(toFile: saveFilePath(), atomically: true, encoding: String.Encoding.unicode)
        
        return report
    }
    
    func generateMaintenanceReport(glidingCentre GC : GlidingCentre, siteSpecific : Bool) -> String
    {
        let twelveDaysAgo = Calendar.current.date(byAdding: Calendar.Component.day, value: -12, to: Date())!.startOfDay

        var report = "<big>MAINTENANCE REPORT</big><br>"
        
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
                report += "No timesheets found for \(unit!) in the past two weeks."
            
            case (0, false):
                report += "No timesheets found in the past two weeks."
            
            default:
                report += "<table border='1'>"
                report += "<tr bgcolor='#CCCCCC'><th width ='15%'>Vehicle</th><th width ='30%'>Issues</th><th width ='10%'>Date</th><th width ='10%'>Air Time</th><th width ='10%'>Ground Launches</th><th width ='9%'>Final TTSN</th><th width ='8%'>TNI</th><th width ='8%'>TTNI</th></tr>"
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
            report += "<tr>"
            
            report += "<td rowspan ='\(last7Days.count)'>"
            report += aircraft.registrationWithTailNumberInBrackets
            report += "</td>"
            
            report += "<td rowspan ='\(last7Days.count)'>"
            
            if aircraft.maintenanceItems.count > 0
            {
                var issueString = ""
                for issue in aircraft.maintenanceItems
                {
                    if issueString.count > 0
                    {
                        issueString += "<br>"
                    }
                    
                    issueString += "\(issue.comment) (\(issue.date.militaryFormatShort))"
                }
                
                report += issueString
            }
            
            report += "</td>"
            
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
                if date != last7Days.first
                {
                    startHTMLtableRow(&report)
                }
                
                addTableCellToHTMLcode(&report, withText: date.militaryFormatShort)
                
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
                
                if TTSNstart == nil
                {
                    addTableCellToHTMLcode(&report, withText: "Not Flown")
                    addTableCellToHTMLcode(&report, withText: "\(groundLaunches)")
                    addTableCellToHTMLcode(&report, withText: "")
                    addTableCellToHTMLcode(&report, withText: "")
                }
                    
                else
                {
                    guard let TTSNstart = TTSNstart, let TTSNend = TTSNend else {return ""}
                    let timeForDay = TTSNend - TTSNstart
                    addTableCellToHTMLcode(&report, withText: timeForDay.stringWithDecimal)
                    addTableCellToHTMLcode(&report, withText: "\(groundLaunches)")
                    addTableCellToHTMLcode(&report, withText: TTSNend.stringWithDecimal)
                    
                    let hoursToNextInspection = aircraft.TTNI - (TTSNend as Decimal)
                    addTableCellToHTMLcode(&report, withText: hoursToNextInspection.stringWithDecimal)
                }
                
                if date == last7Days.first
                {
                    report += "<td valign='bottom' rowspan ='\(last7Days.count)'>\(TTNI)</td>"
                }
                
                endHTMLtableRow(&report)
            }
        }
        
        if aircraftOrderedByTailNumber.count > 0
        {
            report += "</table>"
        }
        
        return report
    }
    
    // TODO: Modify this function to be able to generate both a HTML (for PDF) and an Excel file.
    func generateTimesheetsForDate(_ date: Date, _ includeChangeLog: Bool = false) -> String
    {
        let GC = (regularFormat && dataModel.viewPreviousRecords) ? dataModel.previousRecordsGlidingCentre! : dataModel.glidingCentre
        
        dateToCreateRecords = date
        
        // Text for starting the timesheets
        var HTML = "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always}</STYLE><style type='text/css'>td{font-size:8pt;font-Fy:Helvetica}</style><style type='text/css'>th{font-size:10pt;font-Fy:Helvetica}</style><title>Gliding Timesheets</title></head><body>"
        
        let beginningOfDay = date.midnight
        let endOfDay = beginningOfDay + (60*60*24)
        
        let request = AircraftTimesheet.request
        request.predicate = NSPredicate(format: "date > %@ AND date < %@ AND glidingCentre.name == %@", argumentArray: [beginningOfDay, endOfDay, GC!.name])
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
            
            lineNumber = 1
            currentAircraftRegistration = timesheet.aircraft.registrationWithTailNumberInBrackets
            currentAircraftCommonName = timesheet.aircraft.tailNumber + " <br> \(timesheet.aircraft.registration)"
            
            // This code is for when there are multiple timesheets for a given aircraft on a given day
            var entryNumber = 1
            var fullEntryName = currentAircraftCommonName
            
            while (gliderSequenceHours[fullEntryName] != nil || scoutSequenceHours[fullEntryName] != nil)
            {
                entryNumber += 1
                fullEntryName  = currentAircraftCommonName + " Entry \(entryNumber)"
            }
            
            currentAircraftCommonName = fullEntryName
            
            towplaneOrGlider = timesheet.aircraft.type
            addTimesheetTableToString(&HTML, includeChangeLog)
            
            for recordBeingExamined in records
            {
                // ends the timesheet and starts a new timesheet if htere are too many lines
                if lineNumber > maxNumberOfFlightsPerPage
                {
                    endHTMLtable(&HTML)
                    HTML += "<P CLASS='pagebreakhere'></P>"
                    greyRow = false
                    sheetNumber += 1
                    lineNumber = 1
                    
                    addTimesheetTableToString(&HTML, includeChangeLog)
                }
                
                //starts a new row for the new entry
                beginHTMLtableRow(&HTML)
                
                if includeChangeLog
                {
                    addTableCellToHTMLcode(&HTML, withText: recordBeingExamined.recordID.hoursAndMinutes)
                }
                
                addTableCellToHTMLcode(&HTML, withText: recordBeingExamined.pilot?.fullName)
                if towplaneOrGlider == .glider
                {
                    if recordBeingExamined.flightSequence == "Student Trg"
                    {
                        addTableCellToHTMLcode(&HTML, withText: "✓")
                    }
                        
                    else
                    {
                        addTableCellToHTMLcode(&HTML)
                    }
                }
                
                addTableCellToHTMLcode(&HTML, withText: recordBeingExamined.passenger?.fullName)
                if towplaneOrGlider == .glider
                {
                    if recordBeingExamined.flightSequence == "Student Trg"
                    {
                        addTableCellToHTMLcode(&HTML, withText: "✓")
                    }
                        
                    else
                    {
                        addTableCellToHTMLcode(&HTML)
                    }
                }
                
                let upTime = recordBeingExamined.timeUp.hoursAndMinutes
                
                let downTime: String
                
                if recordBeingExamined.timeDown == Date.distantFuture
                {
                    downTime = "?"
                }
                    
                else
                {
                    downTime = recordBeingExamined.timeDown.hoursAndMinutes
                }
                
                addTableCellToHTMLcode(&HTML, withText: upTime)
                addTableCellToHTMLcode(&HTML, withText: downTime)
                addTableCellToHTMLcode(&HTML, withText: String(fromMinutes: Double(recordBeingExamined.flightLengthInMinutes)))
                
                var text = recordBeingExamined.flightSequence
                
                if recordBeingExamined.flightSequence == "Transit"
                {
                    text += " \(recordBeingExamined.transitRoute)"
                }
                
                if let connectedRoute = recordBeingExamined.connectedAircraftRecord?.transitRoute, recordBeingExamined.connectedAircraftRecord?.flightSequence == "Transit"
                {
                    text += " \(connectedRoute)"
                }
                
                addTableCellToHTMLcode(&HTML, withText: text)
                
                if let connectedAircraftRecord = recordBeingExamined.connectedAircraftRecord
                {
                    addTableCellToHTMLcode(&HTML, withText: connectedAircraftRecord.timesheet.aircraft.tailNumber)
                }
                    
                else
                {
                    addTableCellToHTMLcode(&HTML)
                }
                
                endHTMLtableRow(&HTML)
                lineNumber += 1
                
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
                
                //add logic to output a summary if it is the last one and clear the current aircraft
                if recordBeingExamined == records.last
                {
                    //ends the timesheet if all the flights for that aircraft have been printed
                    endHTMLtable(&HTML)
                    HTML += "<P CLASS='pagebreakhere'></P>"
                    
                    let pageNumber = "\(sheetNumber)"
                    for _ in 0 ..< sheetNumber
                    {
                        //puts the final number of timesheets for that aircraft on
                        HTML.replaceSubrange(HTML.range(of: "***")!, with: pageNumber)
                    }
                    
                    currentAircraftSequenceHours["TTSNstart"] = timesheet.TTSNinitial.minutesFromHours
                    currentAircraftSequenceHours["TTSNend"] = timesheet.TTSNfinal.minutesFromHours
                    
                    if towplaneOrGlider == .glider
                    {
                        gliderSequenceHours[currentAircraftCommonName] = currentAircraftSequenceHours
                        gliderSequenceFlights[currentAircraftCommonName] = currentAircraftSequenceFlights
                    }
                        
                    else
                    {
                        scoutSequenceHours[currentAircraftCommonName] = currentAircraftSequenceHours
                        scoutSequenceFlights[currentAircraftCommonName] = currentAircraftSequenceFlights
                    }
                }
            }
            
            if towplaneOrGlider == .glider
            {
                gliderSequenceHours[currentAircraftCommonName] = currentAircraftSequenceHours
                gliderSequenceFlights[currentAircraftCommonName] = currentAircraftSequenceFlights
            }
                
            else
            {
                scoutSequenceHours[currentAircraftCommonName] = currentAircraftSequenceHours
                scoutSequenceFlights[currentAircraftCommonName] = currentAircraftSequenceFlights
            }
            
            greyRow = false
            sheetNumber = 1
            lineNumber = 1
            
            if includeChangeLog
            {
                addChangeLogTableToString(&HTML)
                
                let logComponents = timesheet.history.components(separatedBy: "*****")
                
                if logComponents.count < 5
                {
                    beginHTMLtableRow(&HTML)
                    HTML += "<td colspan='5'>No changes recorded after the original date of entry.</td>"
                    endHTMLtableRow(&HTML)
                }
                    
                else
                {
                    struct editInfo
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
                    
                    var edits = [editInfo]()
                    
                    for i in stride(from: 0, to: logComponents.count, by: 5)
                    {
                        if i + 4 >= logComponents.count
                        {
                            continue
                        }
                        
                        var entryComponents = [String]()
                        entryComponents.append(logComponents[i])
                        entryComponents.append(logComponents[i+1])
                        entryComponents.append(logComponents[i+2])
                        entryComponents.append(logComponents[i+3])
                        entryComponents.append(logComponents[i+4])
                        edits.append(editInfo(data: entryComponents))
                    }
                    
                    for edit in edits
                    {
                        beginHTMLtableRow(&HTML)
                        addTableCellToHTMLcode(&HTML, withText: edit.recordID)
                        addTableCellToHTMLcode(&HTML, withText: edit.editTime)
                        addTableCellToHTMLcode(&HTML, withText: edit.editor)
                        addTableCellToHTMLcode(&HTML, withText: edit.license)
                        addTableCellToHTMLcode(&HTML, withText: edit.description)
                        endHTMLtableRow(&HTML)
                    }
                }
                
                endHTMLtable(&HTML)
                HTML += "<P CLASS='pagebreakhere'></P>"
                greyRow = false
            }
        }
        
        if gliderSequenceHours.count > 0
        {
            HTML += timesheetSummaryForType("Glider", withHours: &gliderSequenceHours, andFlights: &gliderSequenceFlights)
        }
        
        if scoutSequenceHours.count > 0
        {
            HTML += timesheetSummaryForType("Towplane", withHours: &scoutSequenceHours, andFlights: &scoutSequenceFlights)
        }
        
        if winchTimesheets.count > 0
        {
            HTML += winchSummaryFromTimesheets(winchTimesheets)
        }
        
        if autoTimesheets.count > 0
        {
            HTML += autoSummaryFromTimesheets(autoTimesheets)
        }
        
        HTML += "</body></html>"
        
        HTML = HTML.replacingOccurrences(of: "Famil", with: "F")
        HTML = HTML.replacingOccurrences(of: "Proficiency", with: "P")
        HTML = HTML.replacingOccurrences(of: "Upgrade", with: "U")
        HTML = HTML.replacingOccurrences(of: "Conversion", with: "C")
        HTML = HTML.replacingOccurrences(of: "Student Trg", with: "S")
        HTML = HTML.replacingOccurrences(of: "Transit", with: "✗")
        HTML = HTML.replacingOccurrences(of: "Maintenance", with: "✗")
        HTML = HTML.replacingOccurrences(of: "Towing", with: "TOW")
        HTML = HTML.replacingOccurrences(of: "Fam / PR / Wx", with: "F")
        HTML = HTML.replacingOccurrences(of: "Tow Course", with: "TPC")
        HTML = HTML.replacingOccurrences(of: "✓", with: "<center>✓</center>")
        try! HTML.write(toFile: saveFilePath(), atomically: true, encoding: String.Encoding.unicode)
        
        return HTML
    }
    
    //MARK: - Support Methods
    func autoSummaryFromTimesheets(_ timesheets: [AircraftTimesheet]) -> String
    {
        //create the summary table and headers
        
        var text = "<big>\(regionNameString) REGION AUTO SUMMARY \(dateToCreateRecords.militaryFormatLong.uppercased())</big><br>"
        
        text += "<table border='1'><tr bgcolor='#CCCCCC'><th></th>"
        
        for sheet in timesheets
        {
            text += "<th>\(sheet.aircraft.tailNumber)</th>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'>"
        text += "<th>Launches</th>"
        
        for sheet in timesheets
        {
            text += "<th>\(sheet.flightRecords.count)</th>"
        }
        
        text += "</tr></table><br><br>"
        
        return text
    }
    
    func winchSummaryFromTimesheets(_ timesheets: [AircraftTimesheet]) -> String
    {
        //create the summary table and headers
        
        var text = "<big>\(regionNameString) REGION WINCH SUMMARY \(dateToCreateRecords.militaryFormatLong.uppercased())</big><br>"
        
        text += "<table border='1'><tr bgcolor='#CCCCCC'><th></th>"
        
        for sheet in timesheets
        {
            text += "<th>\(sheet.aircraft.tailNumber)</th>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'>"
        text += "<th>TTSN Start</th>"
        
        for sheet in timesheets
        {
            text += "<th>\(sheet.TTSNinitial.stringWithDecimal)</th>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'>"
        text += "<th>Hours</th>"
        
        for sheet in timesheets
        {
            let hoursUsed = sheet.TTSNfinal - sheet.TTSNinitial
            text += "<th>\(hoursUsed.stringWithDecimal)</th>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'>"
        text += "<th>TTSN End</th>"
        
        for sheet in timesheets
        {
            text += "<th>\(sheet.TTSNfinal.stringWithDecimal)</th>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'>"
        text += "<th>Launches</th>"
        
        for sheet in timesheets
        {
            text += "<th>\(sheet.flightRecords.count)</th>"
        }
        
        text += "</tr></table><br><br>"
        
        return text
    }
    
    func timesheetSummaryForType(_ towplaneGlider: String, withHours hours: inout [String: [String: Int]], andFlights flights: inout [String: [String: Int]]) -> String
    {
        //create the summary table and headers
        
        var text = "<big>\(regionNameString) REGION \(towplaneGlider.uppercased()) SUMMARY \(dateToCreateRecords.militaryFormatLong.uppercased())</big><br>"
        
        let aircraftIdents = Array(hours.keys).sorted(by: numericSearch)
        
        text += "<table border='1'><tr bgcolor='#CCCCCC'><th rowspan='2'>Sequence</th>"
        
        for ident in aircraftIdents
        {
            text += "<th colspan='2'>\(ident)</th>"
        }
        
        if aircraftIdents.count > 1
        {
            text += "<th colspan='2'>All \(towplaneGlider)s</th>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'>"
        
        for _ in 0 ..< aircraftIdents.count
        {
            text += "<th>Flights</th><th>Hours</th>"
        }
        
        if aircraftIdents.count > 1
        {
            text += "<th>Flights</th><th>Hours</th>"
        }
        
        //create the summary data
        
        addTotalForAircraftHours(&hours, andFlights: &flights)
        addTotalForType(towplaneGlider, withHours: &hours, andFlights: &flights)
        
        guard let minutesTotals = hours["Total"] else {return ""}
        
        for (sequence, minutes) in minutesTotals
        {
            if (sequence != "Total") && (sequence != "TTSNstart") && (sequence != "TTSNend")
            {
                text += "</tr><tr><td>\(sequence)</td>"
                
                for ident in aircraftIdents
                {
                    if let _ = flights[ident]?[sequence]
                    {
                        let formattedHours = String(fromMinutes: Double(hours[ident]![sequence]!))
                        text += "<td>\(flights[ident]![sequence]!)</td><td>\(formattedHours.decimalHoursValue)</td>"
                    }
                        
                    else
                    {
                        text += "<td>0</td><td>0.0</td>"
                    }
                    
                }
                
                if aircraftIdents.count > 1
                {
                    let formattedHours = String(fromMinutes: Double(minutes))
                    let flights = flights["Total"]![sequence] ?? 0
                    text += "<td>\(flights)</td><td>\(formattedHours.decimalHoursValue)</td>"
                }
            }
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'><th>TTSN Start</th>"
        
        for ident in aircraftIdents
        {
            let hourText = String(fromMinutes: Double(hours[ident]!["TTSNstart"]!))
            text += "<td colspan='2'><strong><center>\(hourText.decimalHoursValue)</center></td></strong>"
        }
        
        if aircraftIdents.count > 1
        {
            text += "<td colspan='2'></td>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'><th>Total</th>"
        
        for ident in aircraftIdents
        {
            let flightTotal = flights[ident]!["Total"] ?? 0
            let hourTotal = String(fromMinutes: Double(hours[ident]!["Total"]!))
            text += "<td><strong>\(flightTotal)</td></strong><td><strong>\(hourTotal.decimalHoursValue)</td></strong>"
        }
        
        if aircraftIdents.count > 1
        {
            let flightTotal = flights["Total"]!["Total"] ?? 0
            let hourTotal = String(fromMinutes: Double(hours["Total"]!["Total"]!))
            text += "<td><strong>\(flightTotal)</strong></td><td><strong>\(hourTotal.decimalHoursValue)</strong></td>"
        }
        
        text += "</tr><tr bgcolor='#CCCCCC'><th>TTSN End</th>"
        
        for ident in aircraftIdents
        {
            let hourTotal = String(fromMinutes: Double(hours[ident]!["TTSNend"]!))
            text += "<td colspan='2'><strong><center>\(hourTotal.decimalHoursValue)</center></td></strong>"
        }
        
        if aircraftIdents.count > 1
        {
            text += "<td colspan='2'></td>"
        }
        
        text += "</tr></table><br><br>"
        
        return text
    }
    
    func addTotalForType(_ towplaneGlider: String, withHours hours: inout [String: [String: Int]], andFlights flights: inout [String: [String: Int]])
    {
        var typeFlightTotals = [String: Int]()
        var typeHourTotals = [String: Int]()
        var flightCount = 0
        var minuteCount = 0
        
        sequenceList = towplaneGlider == "Glider" ? gliderSequenceList : towplaneSequenceList
        
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
    
    func addTotalForAircraftHours(_ hours: inout [String: [String: Int]], andFlights flights: inout [String: [String: Int]])
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
    
    func convertNSNumberToDecimalString(_ hours: NSNumber) -> String
    {
        let time = hours.doubleValue
        return NSString(format: "%.1f", time) as String
    }
    
    func saveFilePath() -> String
    {
        let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask , true) as [String]
        return pathArray[0].stringByAppendingPathComponent("Timesheets.html")
    }
    
    //MARK: - Methods for HTML Creation
    func addPilotTableToString(_ HTMLtext: inout String)
    {
        HTMLtext += "<table border='1'>"
        
        HTMLtext += "<tr bgcolor='#CCCCCC'><th>Aircraft</th><th>Pilot</th><th>Student /<Br>Passenger</th><th>Time Up</th><th>Time Down</th><th>Air Time</th><th>Sequence</th></th></tr>"
    }
    
    func timesheetHeader() -> String
    {
        let type = towplaneOrGlider == .glider ? "GLIDER" : "TOWPLANE"
        
        let text = "<big>\(regionNameString) REGION \(type) FLYING TIMES</big><br><table border='1'><tr><th>A/C Reg: \(currentAircraftRegistration)</th><th>Date: \(dateToCreateRecords.militaryFormatLong)</th><th>Sheet: \(sheetNumber) of ***</th><th>Gliding Unit: \(unit!)</th></tr></table>"
        
        return text
    }
    
    func endHTMLtable(_ HTMLCode: inout String)
    {
        HTMLCode += "</table>"
    }
    
    /// Begins a HTML table row with shading
    ///
    /// - parameter HTMLCode: The HTML text to append the row ending to.
    func beginHTMLtableRow(_ HTMLCode: inout String)
    {
        if greyRow
        {
            HTMLCode += "<tr bgcolor='#E3E3E3'>"
        }
            
        else
        {
            HTMLCode += "<tr>"
        }
        
        greyRow = !greyRow
    }
    
    func startHTMLtableRow(_ HTMLCode: inout String)
    {
        HTMLCode += "<tr>"
    }
    
    /// Ends a HTML table row
    ///
    /// - parameter HTMLCode: The HTML text to append the row ending to.
    func endHTMLtableRow(_ HTMLCode: inout String)
    {
        HTMLCode += "</tr>"
    }
    
    func addTimesheetTableToString(_ HTMLtext: inout String, _ includeChangeLog: Bool = false)
    {
        HTMLtext += timesheetHeader()
        HTMLtext += "<table border='1'>"
        
        switch (towplaneOrGlider, includeChangeLog)
        {
            case (.glider, false):
                HTMLtext += "<tr bgcolor='#CCCCCC'><th>Pilot</th><th>Inst<br>Auth</th><th>Student /<Br>Passenger</th><th>Student<br>Ack</th><th>Time<Br>Up</th><th>Time<Br>Down</th><th>Air <Br>Time</th><th>Sequence</th><th>Launch<br>Vehicle</th></th></tr>"
            case (_, false):
                HTMLtext += "<tr bgcolor='#CCCCCC'><th>Pilot</th><th>Student /<Br>Passenger</th><th>Time Up</th><th>Time Down</th><th>Air Time</th><th>Sequence</th><th>Glider<br>Towed</th></th></tr>"
            case (.glider, true):
                HTMLtext += "<tr bgcolor='#CCCCCC'><th>Record<br>ID</th><th>Pilot</th><th>Inst<br>Auth</th><th>Student /<Br>Passenger</th><th>Student<br>Ack</th><th>Time<Br>Up</th><th>Time<Br>Down</th><th>Air <Br>Time</th><th>Sequence</th><th>Launch<br>Vehicle</th></th></tr>"
            case (_, true):
                HTMLtext += "<tr bgcolor='#CCCCCC'><th>Record<br>ID</th><th>Pilot</th><th>Student /<Br>Passenger</th><th>Time Up</th><th>Time Down</th><th>Air Time</th><th>Sequence</th><th>Glider<br>Towed</th></th></tr>"
        }
    }
    
    func addChangeLogTableToString(_ HTMLtext: inout String)
    {
        HTMLtext += "<big>CHANGE LOG</big><br>"
        HTMLtext += "<table border='1'>"
        HTMLtext += "<tr bgcolor='#CCCCCC'><th>Record ID</th><th>Edit Time</th><th>Editor Name</th><th>Editor License</th><th>Edit Description</th></tr>"
    }
    
    func addTableCellToHTMLcode(_ HTMLCode: inout String, withText newCellText: String? = nil, andTextColor color: TableCellColor = .defaultColor)
    {
        switch color
        {
            case .red:
                HTMLCode += RED_CELL_COLOR
            case .yellow:
                HTMLCode += YELLOW_CELL_COLOR
            case .green:
                HTMLCode += GREEN_CELL_COLOR
            case .black:
                HTMLCode += BLACK_CELL_COLOR
            default:
                HTMLCode += "<td>"
        }
        
        if newCellText == nil
        {
            HTMLCode += "</td>"
        }
            
        else
        {
            HTMLCode += "\(newCellText!)</td>"
        }
    }
    
    func tableHeaderCell(headerText: String = "") -> String
    {
        var cell = "<th>"
        cell += headerText
        
        return cell + "</th>"
    }
    
    //    func tableRow(header: Bool = false, _ rowTextGenerator: @noescape () -> String) -> String
    //    {
    //        var row = header ? "<tr bgcolor='#CCCCCC'>" : "<tr>"
    //        row += rowTextGenerator()
    //
    //        return row + "</tr>"
    //    }
    
    func tableCell(text newCellText: String? = nil, textColor: TableCellColor = .defaultColor) -> String
    {
        var cell = ""
        
        switch textColor
        {
            case .red:
                cell += RED_CELL_COLOR
            case .yellow:
                cell += YELLOW_CELL_COLOR
            case .green:
                cell += GREEN_CELL_COLOR
            case .black:
                cell += BLACK_CELL_COLOR
            default:
                cell += "<td>"
        }
        
        if newCellText == nil
        {
            cell += "</td>"
        }
            
        else
        {
            cell += "\(newCellText!)</td>"
        }
        
        return cell
    }
    
    func addBlackCellToHTMLstring(_ HTMLCode: inout String)
    {
        HTMLCode += "<td bgcolor='#000000'></td>"
    }
}
