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

    func issuesString(from maintenanceEvents : Set<MaintenanceEvent>, withSeparator separator : String) -> String
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
    
    func generateMaintenanceReportWithReportGenerator(_ generator : HtmlStatsReportFromDate, glidingCentre GC : GlidingCentre, siteSpecific : Bool)
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
                generator.addLineOfText("No timesheets found for \(unit!) in the past two weeks.")
            
            case (0, false):
                generator.addLineOfText("No timesheets found in the past two weeks.")
            
            default:
                generator.startTable([ReportColumn(widthPercent: 15, title: "Vehicle"),
                                     ReportColumn(widthPercent: 30, title: "Issues"),
                                     ReportColumn(widthPercent: 10, title: "Date"),
                                     ReportColumn(widthPercent: 10, title: "Air Time"),
                                     ReportColumn(widthPercent: 10, title: "Ground Launches"),
                                     ReportColumn(widthPercent: 9, title: "Final TTSN"),
                                     ReportColumn(widthPercent: 8, title: "TNI"),
                                     ReportColumn(widthPercent: 8, title: "TTNI")])
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
    

    /**
     This is the new version of the statsReportFromDate.
     
     This version uses a class that implement the StatsReport protocol, whose responsibility is the structure the
     report according to the format of the file. The goal is to keep in the method only what belongs to the gathering of the data.
     
     The first part will be to extract the report variable into the HtmlStatsReport, replacing each reference to the report variable
     by a call to a method of the StatsReport protocol.
     
     The start and end of the HTML file will only appear in the "getResult" method called only at the end.
     
     I envision a addSection(text) which, in the case of HTML report, will insert a heading (<big>) with the text passed. We can also think of a addEmptyRow to create spacing.
     
     Other methods will be created keeping in mind that the at the end, we want to replace the HTML report by an Excel report.
     
     - Warning
     
     The problem to solve is that presently, the result is a String representing the HTML file (the text format) that will be tranformed into a PDF file (the binary format) using some utility class that
     depends on some kind of UI API. But the goal is to be able to have it generate an Excel spreadsheet. Which is already our binary format (in fact it is still text format - XML - but need no
     other transformation).
     */
    func statsReportFromDateWithReportGenerator(_ startDate: Date, toDate endDate: Date, _ siteSpecific: Bool = false) -> String
    {
        let generator = HtmlStatsReportFromDate(startDate, toDate: endDate, siteSpecific)

        //Heading and number of glider flights
        guard let GC = regularFormat && dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre else{return ""}
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
            generator.addTitle("\(unit.uppercased()) STATS REPORT \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            generator.addTitle("REGIONAL STATS REPORT \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        generator.addBlankLine()
        
        if siteSpecific
        {
            generator.addLineOfInfoText("\(unit!) glider flights last five days: \(numberOfGliderFlightsInLastFiveDays)")
        }
            
        else
        {
            generator.addLineOfInfoText("Glider flights last five days: \(numberOfGliderFlightsInLastFiveDays)")
        }
        
        generator.addBlankLine()
        
        // MARK: - Maintenance portion of report
        generateMaintenanceReportWithReportGenerator(generator, glidingCentre: GC, siteSpecific: siteSpecific)
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
            generator.addNewSectionTitle("\(unit.uppercased()) NATIONAL REPORT STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            generator.addNewSectionTitle("NATIONAL REPORT STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }

        generator.startTable([ReportColumn(title : ""),
                              ReportColumn(colSpan : 2, title : "Gliders"),
                              ReportColumn(colSpan : 2, title : "Tow Aircraft")],
                             [ReportColumn(title : ""),
                              ReportColumn(title : "Flights"),
                              ReportColumn(title : "Hours"),
                              ReportColumn(title : "Flights"),
                              ReportColumn(title : "Hours")])
        
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
            
            generator.addTableRow([ReportCell(value : "GIC"),
                                   ReportCell(value : "\(sequenceTotal)"),
                                   ReportCell(value : roundedSequenceDecimal.stringWithDecimal),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true)])
        }
            
        else
        {
            generator.addTableRow([ReportCell(value : "GIC"),
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
            
            generator.addTableRow([ReportCell(value : "TPC"),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true),
                                   ReportCell(value : "\(sequenceTotal)"),
                                   ReportCell(value : roundedSequenceDecimal.stringWithDecimal)])
        }
            
        else
        {
            generator.addTableRow([ReportCell(value : "TPC"),
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
            
            generator.addTableRow([ReportCell(value : "C"),
                                   ReportCell(value : "\(sequenceTotal)"),
                                   ReportCell(value : roundedSequenceDecimal.stringWithDecimal),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true)])
        }
            
        else
        {
            generator.addTableRow([ReportCell(value : "C"),
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
            generator.addTableRow([ReportCell(value : "S"),
                                   ReportCell(value : "\(sequenceTotal)"),
                                   ReportCell(value : roundedSequenceDecimal.stringWithDecimal),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true)])
        }
            
        else
        {
            generator.addTableRow([ReportCell(value : "S"),
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
        
        generator.addTableRow([ReportCell(value : "P"),
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
        
        generator.addTableRow([ReportCell(value : "U"),
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
        
        generator.addTableRow([ReportCell(value : "F"),
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
        
        generator.addTableRow([ReportCell(value : "✗"),
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
            
            generator.addTableRow([ReportCell(value : "TOW"),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true),
                                   ReportCell(value : roundedSequenceDecimal.stringWithDecimal)])
        }
            
        else
        {
            generator.addTableRow([ReportCell(value : "TOW"),
                                   ReportCell(isBlack : true),
                                   ReportCell(isBlack : true),
                                   ReportCell(value : "0"),
                                   ReportCell(value : "0.0")])
        }
        
        //Totals
        generator.addTotalRow([ReportCell(value : "Total"),
                               ReportCell(value : "\(gliderFlightsTotal)"),
                               ReportCell(value : gliderHoursTotal.stringWithDecimal),
                               ReportCell(value : "\(towplaneFlightsTotal)"),
                               ReportCell(value : towplaneHoursTotal.stringWithDecimal)])
        generator.endTable()
        
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
            generator.addLineOfText("\(winchLaunches) winch launches")
        }
        
        if autoLaunches > 0
        {
            generator.addLineOfText("\(autoLaunches) auto launches")
        }
        
        let NATIONALCOMPLETED = Date()
        //MARK: End Of National Section
        //Squadron Attendance portion of report
        
        if siteSpecific
        {
            generator.addNewSectionTitle("\(unit.uppercased()) SQUADRON ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            generator.addNewSectionTitle("SQUADRON ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        let squadronCadetRequest = AttendanceRecord.request
        let cadetRequestPredicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND pilot.typeOfParticipant == %@", argumentArray: [startDate,endDate, "cadet"])
        
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
        let commentRequestPredicate = NSPredicate(format: "date >= %@ AND date <= %@", argumentArray: [startDate, endDate])
        
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
        
        generator.startTable([ReportColumn(widthPixel : 60, title : "Date"),
                              ReportColumn(widthPixel : 100, title : "Squadron"),
                              ReportColumn(widthPixel : 60, title : "Number of Squadron Cadets Attended"),
                              ReportColumn(widthPixel : 60, title : "Number of Squadron Cadet Glider Fams"),
                              ReportColumn(widthPixel : 60, title : "Number of Glider Flights"),
                              ReportColumn(widthPixel : 60, title : "Number of Cadet Fam Flights in Tow A/C"),
                              ReportColumn(title : "Comments")],
                             withAlternatingRowColor : true)

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

            generator.addTableRow([ReportCell(value : date.militaryFormatShort),
                                   ReportCell(value : squadronString),
                                   ReportCell(value : squadronAttendanceString),
                                   ReportCell(value : squadronGliderAttendanceString),
                                   ReportCell(value : "\(flightsAndAttenaceForDate.totalGliderFlights)"),
                                   ReportCell(value : "\(flightsAndAttenaceForDate.totalScoutFams)"),
                                   ReportCell(value : commentsForDate)])
        }

        generator.addTotalRow([ReportCell(value : "Total"),
                               ReportCell(),
                               ReportCell(value : "\(totalNumberOfCadets)"),
                               ReportCell(value : "\(totalNumberOfCadetsFlown)"),
                               ReportCell(value : "\(gliderFlightsTotal)"),
                               ReportCell(value : "\(towFamFlights)"),
                               ReportCell()])

        generator.endTable()
        
        let SQUADRONCOMPLETED = Date()
        //MARK: End of Squadron Stats
        
        //Personnel portion of report
        if siteSpecific
        {
            generator.addNewSectionTitle("\(unit.uppercased()) PERSONNEL STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            generator.addNewSectionTitle("PERSONNEL STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        // - TODO: Start table
        generator.startTable([ReportColumn(title : ""),
                              ReportColumn(title : "Days Worked"),
                              ReportColumn(title : "PIC Flights"),
                              ReportColumn(title : "PIC flights /<br> day worked"),
                              ReportColumn(title : "Dual Flights"),
                              ReportColumn(title : "Dual Flights /<br>day worked")], withAlternatingRowColor : true)
        
        let staffAttendanceRequest = AttendanceRecord.request
        let staffAttendanceRequestPredicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND participantType != %@ AND pilot != nil", argumentArray: [startDate, endDate, "cadet"])
        
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
                if (startDate...endDate).contains(timesheet.date)
                {
                    flightRecordsInTimePeriod.formUnion(timesheet.flightRecords)
                }
            }
        }
            
        else
        {
            let flightRecordRequest = FlightRecord.request
            let flightRecordRequestPredicate = NSPredicate(format: "\(#keyPath(FlightRecord.timeUp)) > %@ AND \(#keyPath(FlightRecord.timeUp)) < %@ AND \(#keyPath(FlightRecord.pilot)) != nil", argumentArray: [startDate, endDate])
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
            generator.addTableRow([ReportCell(value : participantType),
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

        generator.endTable()
        
        let paidDays = COATSstats.daysWorked + CIstats.daysWorked
        generator.addBlankLine()
        generator.addLineOfText("Total paid days used \(paidDays.oneDecimalStringRepresentation)")

        // Start Staff Cadet Attendance
        if siteSpecific
        {
            generator.addNewSectionTitle("\(unit.uppercased()) STAFF CADET ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            generator.addNewSectionTitle("STAFF CADET ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }

        generator.startTable([ReportColumn(title : "Name"),
                              ReportColumn(title : "Squadron"),
                              ReportColumn(title : "Site"),
                              ReportColumn(title : "Days Worked")],
                             withAlternatingRowColor : true,
                             withInformationText : "Cadets signed in less than 2 days are not shown in this report.")
        
        var cadetNames = Array(staffCadetAttandance.keys)
        cadetNames.sort(by: {staffCadetAttandance[$0]! > staffCadetAttandance[$1]!})
        
        for cadet in cadetNames
        {
            if let daysWorked = staffCadetAttandance[cadet], daysWorked > 1.5
            {
                generator.addTableRow([ReportCell(value : cadet.fullName),
                                       ReportCell(value : "\(cadet.squadron)"),
                                       ReportCell(value : cadet.glidingCentre.name),
                                       ReportCell(value : daysWorked.oneDecimalStringRepresentation)])
            }
        }

        generator.endTable()
        
        if siteSpecific
        {
            generator.addNewSectionTitle("\(unit.uppercased()) STAFF UPGRADES \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
            
        else
        {
            generator.addNewSectionTitle("STAFF UPGRADES \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")
        }
        
        generator.startTable([ReportColumn(title : "Upgrade"),
                              ReportColumn(title : "Name"),
                              ReportColumn(title : "Type of Participant"),
                              ReportColumn(title : "Site")])
        
        let upgradeFetchRequest = Pilot.request
        var upgradeFetchRequestPredicate = NSPredicate(format: "dateOfFrontSeatFamilPilot > %@ AND dateOfFrontSeatFamilPilot < %@ AND highestGliderQual >2 ", argumentArray: [startDate, endDate])
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
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfRearSeatFamilPilot > %@ AND dateOfRearSeatFamilPilot < %@ AND highestGliderQual >3", argumentArray: [startDate, endDate])
        let RSFupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderInstructorPilot > %@ AND dateOfGliderInstructorPilot < %@ AND highestGliderQual >4", argumentArray: [startDate, endDate])
        let instructorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderCheckPilot > %@ AND dateOfGliderCheckPilot < %@ AND highestGliderQual >5", argumentArray: [startDate, endDate])
        let gliderCheckPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderStandardsPilot > %@ AND dateOfGliderStandardsPilot < %@ AND highestGliderQual >6", argumentArray: [startDate, endDate])
        let gliderStandardsPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderPilotXCountry > %@ AND dateOfGliderPilotXCountry < %@", argumentArray: [startDate, endDate])
        let gliderXCountryUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Glider Xcountry")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchPilot > %@ AND dateOfWinchLaunchPilot < %@",argumentArray: [startDate, endDate])
        let winchPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Launch")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchOperator > %@ AND dateOfWinchLaunchOperator < %@", argumentArray: [startDate, endDate])
        let winchOperatorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Operator")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchInstructor > %@ AND dateOfWinchLaunchInstructor < %@", argumentArray: [startDate, endDate])
        let winchInstructorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Launch Instructor")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchRetrieveDriver > %@ AND dateOfWinchRetrieveDriver < %@", argumentArray: [startDate, endDate])
        let winchRetrieveUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Retrieve Driver")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowPilot > %@ AND dateOfTowPilot < %@ AND highestScoutQual >0", argumentArray: [startDate, endDate])
        let towPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowCheckPilot > %@ AND dateOfTowCheckPilot < %@ AND highestScoutQual >1", argumentArray: [startDate, endDate])
        let towCheckPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowStandardsPilot > %@ AND dateOfTowStandardsPilot < %@ AND highestScoutQual >2", argumentArray: [startDate, endDate])
        let towStandardsPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowPilotXCountry > %@ AND dateOfTowPilotXCountry < %@", argumentArray: [startDate, endDate])
        let towXcountryUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Tow Xcountry")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfLaunchControlOfficer > %@ AND dateOfLaunchControlOfficer < %@", argumentArray: [startDate, endDate])
        let LCOupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("LCO")})
        
        func addCellForUpgrade(_ name: String, upgradedPilots: [Pilot])
        {
            for upgradedPilot in upgradedPilots
            {
                generator.addTotalRow([ReportCell(value : name),
                                       ReportCell(value : upgradedPilot.fullName),
                                       ReportCell(value : upgradedPilot.typeOfParticipantStringWithSquadronForCadets),
                                       ReportCell(value : upgradedPilot.glidingCentre?.name ?? "")])
            }
        }
        
        greyRow = false
        
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
        
        generator.endTable()
        
        do{try generator.result().write(toFile: saveFilePath(), atomically: true, encoding: String.Encoding.utf8)}
        catch{}
        
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
                    gliders.append(GliderData(glider: vehicle, startDate: startDate, endDate: endDate))
                
                case .towplane:
                    towplanes.append(TowplaneData(towplane: vehicle, startDate: startDate, endDate: endDate))
                
                case .winch:
                    winches.append(WinchData(winch: vehicle, startDate: startDate, endDate: endDate))
                
                default:
                    break
            }
        }
        
        generator.addNewSectionTitle("GLIDER USAGE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")

        generator.startTable([ReportColumn(colSpan : 2, title : ""),
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
                              ReportColumn(title : "Current TTSN")], withAlternatingRowColor : true)
        
        for glider in gliders
        {
            guard glider.totalHours > 0 else {continue}

            glider.glider.updateTTSN()

            generator.addTableRow([ReportCell(value : glider.glider.registration),
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
        
        generator.endTable()

        generator.addNewSectionTitle("TOWPLANE USAGE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")

        generator.startTable([ReportColumn(colSpan : 2, title : ""),
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
                              ReportColumn(title : "Current TTSN")], withAlternatingRowColor: true)
        
        for towplane in towplanes
        {
            guard towplane.totalHours > 0 else {continue}
            towplane.towplane.updateTTSN()

            generator.addTableRow([ReportCell(value : towplane.towplane.registration),
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
        generator.endTable()

        generator.addNewSectionTitle("WINCH USAGE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())")

        generator.startTable([ReportColumn(colSpan : 2, title : ""),
                              ReportColumn(title : "Current TTSN"),
                              ReportColumn(title : "Hours"),
                              ReportColumn(title : "Flights")], withAlternatingRowColor: true)
        
        for winch in winches
        {
            guard winch.flights > 0 else {continue}
            winch.winch.updateTTSN()

            generator.addTableRow([ReportCell(value : winch.winch.registration),
                                   ReportCell(value : winch.winch.tailNumber),
                                   ReportCell(value : winch.winch.currentTimesheet!.TTSNfinal.stringWithDecimal),
                                   ReportCell(value : winch.hours.stringWithDecimal),
                                   ReportCell(value : "\(winch.flights)")])
        }

        generator.endTable()
        
        if siteSpecific
        {
            generator.addNewSectionTitle("<big>ACTIVE STAFF CONTACT INFO</big>")
            
            let pilotRequest = Pilot.request
            pilotRequest.predicate = NSPredicate(format: "inactive == NO AND glidingCentre == %@ AND (highestGliderQual > 0 OR highestScoutQual > 0)", dataModel.glidingCentre)
            let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.fullName), ascending: true)
            pilotRequest.sortDescriptors = [nameSortDescriptor]
            let pilots = try! dataModel.managedObjectContext.fetch(pilotRequest)
            
            for pilot in pilots
            {
                guard pilot.email.count > 0 else{continue}
                generator.addText(pilot.email + ", ")
            }
            
        }
        
        return generator.result()
    }
    
    func statsReportFromDate(_ startDate: Date, toDate endDate: Date, _ siteSpecific: Bool = false) -> String
    {
        //Heading and number of glider flights
        guard let GC = regularFormat && dataModel.viewPreviousRecords ? dataModel.previousRecordsGlidingCentre : dataModel.glidingCentre else{return ""}
        let START = Date()
        
        var report = "<html><head><STYLE TYPE='text/css'>P.pagebreakhere {page-break-before: always}</STYLE><style type='text/css'>td{font-size:8pt;font-family:Helvetica}</style><style type='text/css'>th{font-size:10pt;font-family:Helvetica}</style><title>Stats Report</title></head><body>"
        
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
            report += "<big>\(unit.uppercased()) STATS REPORT \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
            
        else
        {
            report += "<big>REGIONAL STATS REPORT \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
        
        report += "<br>"
        
        if siteSpecific
        {
            report += "<b>\(unit!) glider flights last five days: \(numberOfGliderFlightsInLastFiveDays)</b>"
        }
            
        else
        {
            report += "<b>Glider flights last five days: \(numberOfGliderFlightsInLastFiveDays)</b>"
        }
        
        report += "<br><br>"
        
        // MARK: - Maintenance portion of report
        report += generateMaintenanceReport(glidingCentre: GC, siteSpecific: siteSpecific)
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
        
        report += "<P CLASS='pagebreakhere'>"
        
        if siteSpecific
        {
            report += "<big>\(unit.uppercased()) NATIONAL REPORT STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
            
        else
        {
            report += "<big>NATIONAL REPORT STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
        
        report += "</P>"
        report += "<table border='1'>"
        
        report += "<tr bgcolor='#CCCCCC'><th></th><th colspan='2'>Gliders</th><th colspan='2'>Tow Aircraft</th></tr>"
        report += "<tr bgcolor='#CCCCCC'><th></th><th>Flights</th><th>Hours</th><th>Flights</th><th>Hours</th></tr>"
        
        var gliderFlightsTotal = 0
        var gliderHoursTotal = NSDecimalNumber(value: 0)
        var towplaneFlightsTotal = 0
        var towplaneHoursTotal = NSDecimalNumber(value: 0)
        var sequenceDecimal: NSDecimalNumber
        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 1, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        
        //Glider Instructor Course
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "GIC")
        
        if let sequenceTotal = gliderFlightsBySequence["GIC"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["GIC"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        addBlackCellToHTMLstring(&report)
        addBlackCellToHTMLstring(&report)
        endHTMLtableRow(&report)
        
        //Tow Pilot Course
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "TPC")
        addBlackCellToHTMLstring(&report)
        addBlackCellToHTMLstring(&report)
        
        if let sequenceTotal = towplaneFlightsBySequence["Tow Course"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Tow Course"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        endHTMLtableRow(&report)
        
        // Conversion
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "C")
        
        if let sequenceTotal = gliderFlightsBySequence["Conversion"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Conversion"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        addBlackCellToHTMLstring(&report)
        addBlackCellToHTMLstring(&report)
        endHTMLtableRow(&report)
        
        // Student Trg
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "S")
        
        if let sequenceTotal = gliderFlightsBySequence["Student Trg"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Student Trg"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        addBlackCellToHTMLstring(&report)
        addBlackCellToHTMLstring(&report)
        endHTMLtableRow(&report)
        
        // Proficiency
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "P")
        
        if let sequenceTotal = gliderFlightsBySequence["Proficiency"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Proficiency"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        addBlackCellToHTMLstring(&report)
        if let sequenceTotal = towplaneFlightsBySequence["Proficiency"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Proficiency"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        endHTMLtableRow(&report)
        
        // Upgrade
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "U")
        if let sequenceTotal = gliderFlightsBySequence["Upgrade"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Upgrade"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        addBlackCellToHTMLstring(&report)
        if let sequenceTotal = towplaneFlightsBySequence["Upgrade"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Upgrade"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        endHTMLtableRow(&report)
        
        // Famil
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "F")
        if let sequenceTotal = gliderFlightsBySequence["Famil"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Famil"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        if let sequenceTotal = towplaneFlightsBySequence["Fam / PR / Wx"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Fam / PR / Wx"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        endHTMLtableRow(&report)
        
        // Transit
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "✗")
        if let sequenceTotal = gliderFlightsBySequence["Transit"]
        {
            addTableCellToHTMLcode(&report, withText: "\(sequenceTotal)")
            gliderFlightsTotal += sequenceTotal
            var sequenceHours = Double(gliderSequenceMinutes["Transit"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newGliderHoursTotal = gliderHoursTotal.adding(roundedSequenceDecimal)
            gliderHoursTotal = newGliderHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        addBlackCellToHTMLstring(&report)
        if let sequenceTotal = towplaneFlightsBySequence["Transit"]
        {
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Transit"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        endHTMLtableRow(&report)
        
        //Towing
        startHTMLtableRow(&report)
        addTableCellToHTMLcode(&report, withText: "TOW")
        addBlackCellToHTMLstring(&report)
        addBlackCellToHTMLstring(&report)
        
        if let sequenceTotal = towplaneFlightsBySequence["Towing"]
        {
            addBlackCellToHTMLstring(&report)
            towplaneFlightsTotal += sequenceTotal
            var sequenceHours = Double(towplaneSequenceMinutes["Towing"] ?? 0)
            sequenceHours /= 60
            sequenceDecimal = NSDecimalNumber(value: sequenceHours)
            let roundedSequenceDecimal = sequenceDecimal.rounding(accordingToBehavior: handler)
            addTableCellToHTMLcode(&report, withText: roundedSequenceDecimal.stringWithDecimal)
            let newTowplaneHoursTotal = towplaneHoursTotal.adding(roundedSequenceDecimal)
            towplaneHoursTotal = newTowplaneHoursTotal
        }
            
        else
        {
            addTableCellToHTMLcode(&report, withText: "0")
            addTableCellToHTMLcode(&report, withText: "0.0")
        }
        
        endHTMLtableRow(&report)
        
        //Totals
        report += "<tr bgcolor='#CCCCCC'><th>Total</th>"
        report += "<th>\(gliderFlightsTotal)</th>"
        report += "<th>\(gliderHoursTotal.stringWithDecimal)</th>"
        report += "<th>\(towplaneFlightsTotal)</th>"
        report += "<th>\(towplaneHoursTotal.stringWithDecimal)</th>"
        report += "</tr>"
        report += "</table>"
        
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
            report += "\(winchLaunches) winch launches<br>"
        }
        
        if autoLaunches > 0
        {
            report += "\(autoLaunches) auto launches<br>"
        }
        
        let NATIONALCOMPLETED = Date()
        //MARK: End Of National Section
        //Squadron Attendance portion of report
        
        report += "<P CLASS='pagebreakhere'>"
        
        if siteSpecific
        {
            report += "<big>\(unit.uppercased()) SQUADRON ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
            
        else
        {
            report += "<big>SQUADRON ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
        
        report += "</P>"
        report += "<table border='1'>"
        report += "<tr bgcolor='#CCCCCC'><th width = '60'>Date</th><th width = '100'>Squadron</th><th width = '60'>Number of Squadron Cadets Attended</th><th width = '60'>Number of Squadron Cadet Glider Fams</th><th width = '60'>Number of Glider Flights</th><th width = '60'>Number of Cadet Fam Flights in Tow A/C</th><th>Comments</th></tr>"
        
        
        let squadronCadetRequest = AttendanceRecord.request
        let cadetRequestPredicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND pilot.typeOfParticipant == %@", argumentArray: [startDate,endDate, "cadet"])
        
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
        let commentRequestPredicate = NSPredicate(format: "date >= %@ AND date <= %@", argumentArray: [startDate, endDate])
        
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
        
        for date in arrayOfDatesFlownOrWithCadets
        {
            var commentsForDate = ""
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
            
            beginHTMLtableRow(&report)
            addTableCellToHTMLcode(&report, withText: date.militaryFormatShort)
            
            let flightsAndAttenaceForDate = statsForDay(date)
            
            report += "<td>"
            
            let sortedSquadronNumbers = flightsAndAttenaceForDate.squadronCadetsAttended.keys.sorted(by: <)
            
            if flightsAndAttenaceForDate.squadronCadetsAttended.count > 0
            {
                for squadronNumber in sortedSquadronNumbers
                {
                    report += "\(squadronNumber)"
                    
                    if siteSpecific == false, let squadron = flightsAndAttenaceForDate.siteForSquadron[squadronNumber]
                    {
                        report += " \(squadron)"
                    }
                    
                    if squadronNumber != sortedSquadronNumbers.last ?? 0
                    {
                        report += "<br>"
                    }
                }
            }
                
            else
            {
                report += "Training"
            }
            
            report += "</td><td>"
            
            for squadronNumber in sortedSquadronNumbers
            {
                report += "\(flightsAndAttenaceForDate.squadronCadetsAttended[squadronNumber] ?? 0)"
                
                if squadronNumber != sortedSquadronNumbers.last ?? 0
                {
                    report += "<br>"
                }
            }
            
            report += "</td><td>"
            
            for squadronNumber in sortedSquadronNumbers
            {
                report += "\(flightsAndAttenaceForDate.squadronCadetsFlownInGlider[squadronNumber] ?? 0)"
                
                if squadronNumber != sortedSquadronNumbers.last ?? 0
                {
                    report += "<br>"
                }
            }
            
            report += "</td><td>"
            report += "\(flightsAndAttenaceForDate.totalGliderFlights)"
            
            report += "</td><td>"
            report += "\(flightsAndAttenaceForDate.totalScoutFams)"
            
            report += "</td><td>"
            report += "\(commentsForDate)"
            
            report += "</td>"
            endHTMLtableRow(&report)
        }
        
        report += "<th>Total</th><th></th>"
        report += "<th>\(totalNumberOfCadets)</th>"
        report += "<th>\(totalNumberOfCadetsFlown)</th>"
        report += "<th>\(gliderFlightsTotal)</th>"
        report += "<th>\(towFamFlights)</th>"
        report += "<th></th>"
        
        greyRow = false
        
        report += "</table>"
        
        let SQUADRONCOMPLETED = Date()
        //MARK: End of Squadron Stats
        
        //Personnel portion of report
        
        report += "<P CLASS='pagebreakhere'>"
        
        if siteSpecific
        {
            report += "<big>\(unit.uppercased()) PERSONNEL STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
            
        else
        {
            report += "<big>PERSONNEL STATS \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big><br>"
        }
        
        report += "</P>"
        report += "<table border='1'>"
        report += "<tr bgcolor='#CCCCCC'><th></th><th>Days Worked</th><th>PIC Flights</th><th>PIC flights /<br> day worked</th><th>Dual Flights</th><th>Dual Flights /<br>day worked</th></tr>"
        
        let staffAttendanceRequest = AttendanceRecord.request
        let staffAttendanceRequestPredicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND participantType != %@ AND pilot != nil", argumentArray: [startDate, endDate, "cadet"])
        
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
                if (startDate...endDate).contains(timesheet.date)
                {
                    flightRecordsInTimePeriod.formUnion(timesheet.flightRecords)
                }
            }
        }
            
        else
        {
            let flightRecordRequest = FlightRecord.request
            let flightRecordRequestPredicate = NSPredicate(format: "\(#keyPath(FlightRecord.timeUp)) > %@ AND \(#keyPath(FlightRecord.timeUp)) < %@ AND \(#keyPath(FlightRecord.pilot)) != nil", argumentArray: [startDate, endDate])
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
        
        func appendStatsFor(_ participantType: String, PICFlights: Int, dualFlights: Int, daysWorked: Double, reportString: inout String)
        {
            reportString += "<tr>"
            reportString += "<td>\(participantType)</td>"
            reportString += "<td>\(daysWorked.oneDecimalStringRepresentation)</td>"
            reportString += "<td>\(PICFlights)</td>"
            let PICflightsPerDay = daysWorked == 0 ? 0 : Double(PICFlights) / daysWorked
            reportString += "<td>\(PICflightsPerDay.oneDecimalStringRepresentation)</td>"
            reportString += "<td>\(dualFlights)</td>"
            let dualFlightsPerDay = daysWorked == 0 ? 0 : Double(dualFlights) / daysWorked
            reportString += "<td>\(dualFlightsPerDay.oneDecimalStringRepresentation)</td>"
            reportString += "</tr>"
        }
        
        appendStatsFor("Staff Cadet", PICFlights: staffCadetStats.PICflights, dualFlights: staffCadetStats.dualFlights, daysWorked: staffCadetStats.daysWorked, reportString: &report)
        appendStatsFor("Volunteer", PICFlights: volunteerStats.PICflights, dualFlights: volunteerStats.dualFlights, daysWorked: volunteerStats.daysWorked, reportString: &report)
        appendStatsFor("CI", PICFlights: CIstats.PICflights, dualFlights: CIstats.dualFlights, daysWorked: CIstats.daysWorked, reportString: &report)
        appendStatsFor("COATS", PICFlights: COATSstats.PICflights, dualFlights: COATSstats.dualFlights, daysWorked: COATSstats.daysWorked, reportString: &report)
        
        report += "</table>"
        
        let paidDays = COATSstats.daysWorked + CIstats.daysWorked
        report += "<br>Total paid days used \(paidDays.oneDecimalStringRepresentation) <br>"
        
        report += "<P CLASS='pagebreakhere'>"
        
        if siteSpecific
        {
            report += "<big>\(unit.uppercased()) STAFF CADET ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
        }
            
        else
        {
            report += "<big>STAFF CADET ATTENDANCE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
        }
        
        report += "</P>"
        report += "<table border='1'>Cadets signed in less than 2 days are not shown in this report.<br>"
        report += "<tr bgcolor='#CCCCCC'><th>Name</th><th>Squadron</th><th>Site</th><th>Days Worked</th></tr>"
        
        var cadetNames = Array(staffCadetAttandance.keys)
        cadetNames.sort(by: {staffCadetAttandance[$0]! > staffCadetAttandance[$1]!})
        
        for cadet in cadetNames
        {
            if let daysWorked = staffCadetAttandance[cadet], daysWorked > 1.5
            {
                beginHTMLtableRow(&report)
                report += "<tr><td>\(cadet.fullName)</td><td>\(cadet.squadron)</td><td>\(cadet.glidingCentre.name)</td><td>\(daysWorked.oneDecimalStringRepresentation)</td></tr>"
                endHTMLtableRow(&report)
            }
        }
        
        report += "</table>"
        report += "<P CLASS='pagebreakhere'>"
        
        if siteSpecific
        {
            report += "<big>\(unit.uppercased()) STAFF UPGRADES \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
            
        }
            
        else
        {
            report += "<big>STAFF UPGRADES \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
        }
        
        report += "</P>"
        report += "<table border='1'><br>"
        report += "<tr bgcolor='#CCCCCC'><th>Upgrade</th><th>Name</th><th>Type of Participant</th><th>Site</th></tr>"
        
        let upgradeFetchRequest = Pilot.request
        var upgradeFetchRequestPredicate = NSPredicate(format: "dateOfFrontSeatFamilPilot > %@ AND dateOfFrontSeatFamilPilot < %@ AND highestGliderQual >2 ", argumentArray: [startDate, endDate])
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
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfRearSeatFamilPilot > %@ AND dateOfRearSeatFamilPilot < %@ AND highestGliderQual >3", argumentArray: [startDate, endDate])
        let RSFupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderInstructorPilot > %@ AND dateOfGliderInstructorPilot < %@ AND highestGliderQual >4", argumentArray: [startDate, endDate])
        let instructorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderCheckPilot > %@ AND dateOfGliderCheckPilot < %@ AND highestGliderQual >5", argumentArray: [startDate, endDate])
        let gliderCheckPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderStandardsPilot > %@ AND dateOfGliderStandardsPilot < %@ AND highestGliderQual >6", argumentArray: [startDate, endDate])
        let gliderStandardsPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfGliderPilotXCountry > %@ AND dateOfGliderPilotXCountry < %@", argumentArray: [startDate, endDate])
        let gliderXCountryUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Glider Xcountry")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchPilot > %@ AND dateOfWinchLaunchPilot < %@",argumentArray: [startDate, endDate])
        let winchPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Launch")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchOperator > %@ AND dateOfWinchLaunchOperator < %@", argumentArray: [startDate, endDate])
        let winchOperatorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Operator")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchLaunchInstructor > %@ AND dateOfWinchLaunchInstructor < %@", argumentArray: [startDate, endDate])
        let winchInstructorUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Launch Instructor")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfWinchRetrieveDriver > %@ AND dateOfWinchRetrieveDriver < %@", argumentArray: [startDate, endDate])
        let winchRetrieveUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Winch Retrieve Driver")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowPilot > %@ AND dateOfTowPilot < %@ AND highestScoutQual >0", argumentArray: [startDate, endDate])
        let towPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowCheckPilot > %@ AND dateOfTowCheckPilot < %@ AND highestScoutQual >1", argumentArray: [startDate, endDate])
        let towCheckPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowStandardsPilot > %@ AND dateOfTowStandardsPilot < %@ AND highestScoutQual >2", argumentArray: [startDate, endDate])
        let towStandardsPilotUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate)
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfTowPilotXCountry > %@ AND dateOfTowPilotXCountry < %@", argumentArray: [startDate, endDate])
        let towXcountryUpgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("Tow Xcountry")})
        
        upgradeFetchRequestPredicate = NSPredicate(format: "dateOfLaunchControlOfficer > %@ AND dateOfLaunchControlOfficer < %@", argumentArray: [startDate, endDate])
        let LCOupgrades = executeupgradeFetchRequest(newPredicate: upgradeFetchRequestPredicate).filter({$0.pilotHoldsQual("LCO")})
        
        func addCellForUpgrade(_ name: String, upgradedPilots: [Pilot])
        {
            for upgradedPilot in upgradedPilots
            {
                beginHTMLtableRow(&report)
                report += "<td>\(name)</td><td>\(upgradedPilot.fullName)</td><td>\(upgradedPilot.typeOfParticipantStringWithSquadronForCadets)</td><td>\(upgradedPilot.glidingCentre?.name ?? "")</td>"
                endHTMLtableRow(&report)
            }
        }
        
        greyRow = false
        
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
        
        report += "</table>"
        
        do{try report.write(toFile: saveFilePath(), atomically: true, encoding: String.Encoding.utf8)}
        catch{}
        
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
                    gliders.append(GliderData(glider: vehicle, startDate: startDate, endDate: endDate))
                
                case .towplane:
                    towplanes.append(TowplaneData(towplane: vehicle, startDate: startDate, endDate: endDate))
                
                case .winch:
                    winches.append(WinchData(winch: vehicle, startDate: startDate, endDate: endDate))
                
                default:
                    break
            }
        }
        
        report += "<P CLASS='pagebreakhere'>"
        report += "</P>"
        report += "<big>GLIDER USAGE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
        report += "<table border='1'>"
        report += "<tr bgcolor='#CCCCCC'><th colspan='2'></th><th colspan='5'>Glider Flights</th><th colspan='5'>Glider Hours</th><th colspan='2'></th></tr>"
        report += "<tr bgcolor='#CCCCCC'><th colspan='2'>Gliders</th><th>Transit</th><th>Famil</th><th>Prof</th><th>Student</th><th>Upgrade</th><th>Transit</th><th>Famil</th><th>Prof</th><th>Student</th><th>Upgrade</th><th>Time Flown</th><th>Current TTSN</th></tr>"
        
        for glider in gliders
        {
            guard glider.totalHours > 0 else {continue}
            
            beginHTMLtableRow(&report)
            report += "<td>\(glider.glider.registration)</td><td>\(glider.glider.tailNumber)</td>"
            report += "<td>\(glider.transitFlights)</td><td>\(glider.familFlights)</td><td>\(glider.profFlights)</td><td>\(glider.studentFlights)</td><td>\(glider.upgradeFlights)</td>"
            report += "<td>\(glider.transitHours.stringWithDecimal)</td><td>\(glider.familHours.stringWithDecimal)</td><td>\(glider.profHours.stringWithDecimal)</td><td>\(glider.studentHours.stringWithDecimal)</td><td>\(glider.upgradeHours.stringWithDecimal)</td>"
            glider.glider.updateTTSN()
            report += "<td>\(glider.totalHours.stringWithDecimal)</td><td>\(glider.glider.currentTimesheet!.TTSNfinal.stringWithDecimal)</td>"
            endHTMLtableRow(&report)
        }
        
        report += "</table>"
        report += "<P CLASS='pagebreakhere'>"
        report += "</P>"
        report += "<big>TOWPLANE USAGE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
        report += "<table border='1'>"
        report += "<tr bgcolor='#CCCCCC'><th colspan='2'></th><th colspan='7'>Scout Hours</th><th>Scout Flights</th><th colspan='2'></th></tr>"
        report += "<tr bgcolor='#CCCCCC'><th colspan='2'>Towplanes</th><th>Transit</th><th>Towing</th><th>TPC</th><th>Maintenance</th><th>Prof</th><th>Upgrade</th><th>Fam</th><th>Fam</th><th>Time Flown</th><th>Current TTSN</th></tr>"
        
        for towplane in towplanes
        {
            guard towplane.totalHours > 0 else {continue}
            
            beginHTMLtableRow(&report)
            report += "<td>\(towplane.towplane.registration)</td><td>\(towplane.towplane.tailNumber)</td>"
            report += "<td>\(towplane.transitHours.stringWithDecimal)</td><td>\(towplane.towingHours.stringWithDecimal)</td><td>\(towplane.towCourseHours.stringWithDecimal)</td><td>\(towplane.maintenanceHours.stringWithDecimal)</td><td>\(towplane.profHours.stringWithDecimal)</td><td>\(towplane.upgradeHours.stringWithDecimal)</td><td>\(towplane.familHours.stringWithDecimal)</td>"
            report += "<td>\(towplane.familFlights)</td>"
            towplane.towplane.updateTTSN()
            report += "<td>\(towplane.totalHours.stringWithDecimal)</td><td>\(towplane.towplane.currentTimesheet!.TTSNfinal.stringWithDecimal)</td>"
            endHTMLtableRow(&report)
        }
        
        report += "</table>"
        report += "<P CLASS='pagebreakhere'>"
        report += "</P>"
        report += "<big>WINCH USAGE \(startDate.militaryFormatShort.uppercased()) TO \(endDate.militaryFormatShort.uppercased())</big>"
        report += "<table border='1'>"
        report += "<tr bgcolor='#CCCCCC'><th colspan='2'></th><th>Current TTSN</th><th>Hours</th><th>Flights</th></tr>"
        
        for winch in winches
        {
            guard winch.flights > 0 else {continue}
            
            beginHTMLtableRow(&report)
            report += "<td>\(winch.winch.registration)</td><td>\(winch.winch.tailNumber)</td>"
            winch.winch.updateTTSN()
            report += "<td>\(winch.winch.currentTimesheet!.TTSNfinal.stringWithDecimal)</td>"
            report += "<td>\(winch.hours.stringWithDecimal)</td>"
            report += "<td>\(winch.flights)</td>"
            endHTMLtableRow(&report)
        }
        
        report += "</table>"
        
        if siteSpecific
        {
            report += "<P CLASS='pagebreakhere'>"
            report += "</P>"
            report += "<big>ACTIVE STAFF CONTACT INFO</big><br>"
            
            let pilotRequest = Pilot.request
            pilotRequest.predicate = NSPredicate(format: "inactive == NO AND glidingCentre == %@ AND (highestGliderQual > 0 OR highestScoutQual > 0)", dataModel.glidingCentre)
            let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.fullName), ascending: true)
            pilotRequest.sortDescriptors = [nameSortDescriptor]
            let pilots = try! dataModel.managedObjectContext.fetch(pilotRequest)
            
            for pilot in pilots
            {
                guard pilot.email.count > 0 else{continue}
                report += pilot.email
                report += ", "
            }
            
        }
        
        report += "</body></html>"
        
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
