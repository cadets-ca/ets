//
//  GlobalFunctionsAndDeclarations.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-08.
//
//

import Foundation
import UIKit
import CoreData
//import MessageUI
import CoreLocation
import CoreBluetooth

let dataModel: TimesheetsDataModel = (UIApplication.shared.delegate as! TimesheetsAppDelegate).timesheetsDataModel

var cloudKitController: CloudKitController?
{
    get
    {
        return (UIApplication.shared.delegate as! TimesheetsAppDelegate).cloudKitController
    }
}

let decimalNumberFormatter: NumberFormatter =
{
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 1
    formatter.maximumFractionDigits = 1
    formatter.minimumIntegerDigits = 1
    return formatter
}()

var shouldUpdateChangeTimes = true

enum VehicleType: Int, Comparable
{
    case glider = 1, towplane = 0, winch = -1, auto = -2
    
    func isAircraft() -> Bool
    {
        return self.rawValue >= 0 ? true : false
    }
}

enum GPSmode {case xcountryStart, xcountryEnd, nearestGC}
enum ReportType {case statsReport, timesheets, pilotLogs, logBook, ptrReport, regionalReport}
enum FlyingStatus {case landed, flying}
enum HookStatus {case unhooked, hooked}
enum ChangeTimeMode {case downtime, uptime}
enum PassengerType: Int {case cadet, guest}
enum Photos {case gliderLicense, powerLicense, medical, pilotPhoto}
enum TNIpickerMode: Int {case ttsn = 0, tni, ttni, initialTTSN, finalTTSN}
enum TowplaneQuals: Int, Comparable {case noScout = 0, towPilot, towCheckPilot, towStandardsPilot}
enum TableCellColor{case defaultColor, yellow, red, green, black}
enum SessionTypes: Double, Comparable {case day = 1, session = 0.5}
enum RecordSortAttribute: Int, Comparable {case tailNumber = 0, pilot, passenger, connectedAircraft, sequence, timeUp, timeDown, flightTime}
enum GliderSequence: String, Comparable {case Famil = "Famil", Proficiency = "Proficiency", Upgrade = "Upgrade", Conversion = "Conversion", StudentTrg = "Student Trg", GIC = "GIC", Transit = "Transit", Maintenance = "Maintenance"}
enum TowplaneSequence: String, Comparable {case Towing = "Towing", FamPRWx = "Fam / PR / Wx", TowCourse = "Tow Course", Transit = "Transit", Maintenance = "Maintenance", Proficiency = "Proficiency", Upgrade = "Upgrade"}
enum SignificantDateMode: Int {case gliderAPC = 0, towAPC, birthday, medicalExpiry, fIexpiry, towPilotDate, towCheckPilotDate, towStandardsPilotDate, basicGliderPilotDate, fsfDate, rsfDate, qgiDate, gliderCheckPilotDate, gliderStandardsPilotDate, lcoDate, winchLaunchDate, winchOperatorDate, winchLaunchInstructorDate, winchRetrieveDate, gliderXCountryDate, towXCountryDate, logBookStartDate, logBookEndDate, statsReportStartDate, statsReportEndDate}
enum GliderQuals: Int, Comparable
    {case noGlider = 0, student, basic, frontSeatFamil, rearSeatFamil, instructor, checkPilot, standardsPilot, level1Cadet = -1, level2Cadet = -2, level3Cadet = -3, level4Cadet = -4}

enum CloudKitRecordType: String, Comparable
{
    static func <(lhs: CloudKitRecordType, rhs: CloudKitRecordType) -> Bool
    {
        return lhs.rawValue == rhs.rawValue ? true : false
    }
    case Timesheet = "AircraftTimesheet", Attendance = "AttendanceRecord", FlightRecord = "FlightRecord", Comment = "GlidingDayComment", Maintenance = "MaintenanceIssue", Pilot = "Pilot", Vehicle = "VehicleRecord", Region = "Region"
}

protocol RecordsChanges
{
    var recordChangeTime: Date {get}
}

protocol HasID
{
    var recordID: Date {get}
}

protocol AttachedToGlidingUnit
{
    var glidingCentre: Timesheets.GlidingCentre! {get set}
}

protocol AttachedToRegion
{
    var region: Timesheets.Region {get set}
}

protocol AttachedToAircraft
{
    var aircraft: Timesheets.AircraftEntity! {get set}
}

protocol AttachedToPilot
{
    var pilot: Timesheets.Pilot! {get set}
}

protocol AttachedToPassenger
{
    var passenger: Timesheets.Pilot? {get set}
}

protocol AttachedToSummerUnit
{
    var summerUnit: Timesheets.SummerUnit? {get set}
}

protocol AttachedToTimesheet
{
    var timesheet: Timesheets.AircraftTimesheet! {get set}
}

protocol EquatesViaNameAlone
{
    var name: String {get}
}

/// This method compares two managed objects provided that they conform to the RecordsChanges protocol
///
/// - parameter firstRecord:  a managed object
/// - parameter secondRecord: another managed object
///
/// - returns: A tuple containing both the most recent record first and older record second
func newerAndOlderRecord<T: RecordsChanges>(_ firstRecord: T, secondRecord: T) -> (newerRecord: T, olderRecord: T)
{
    let mostRecentlyUpdatedFlightRecord: T
    let olderVersionOfFlightRecord: T
    
    if firstRecord.recordChangeTime > secondRecord.recordChangeTime
    {
        mostRecentlyUpdatedFlightRecord = firstRecord
        olderVersionOfFlightRecord = secondRecord
    }
        
    else
    {
        mostRecentlyUpdatedFlightRecord = secondRecord
        olderVersionOfFlightRecord = firstRecord
    }
    
    return (mostRecentlyUpdatedFlightRecord, olderVersionOfFlightRecord)
}

func == (left: RecordSortAttribute, right: RecordSortAttribute) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: RecordSortAttribute, right: RecordSortAttribute) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func < (left: AircraftTimesheet, right: AircraftTimesheet) -> Bool
{
    let result = left.aircraft.tailNumber.compare(right.aircraft.tailNumber, options: NSString.CompareOptions.numeric, range: nil, locale: nil)
    return result == ComparisonResult.orderedAscending ? true : false
}

func numericSearch (_ left: AircraftEntity, right: AircraftEntity) -> Bool
{
    let result = left.tailNumber.compare(right.tailNumber, options: NSString.CompareOptions.numeric, range: nil, locale: nil)
    return result == ComparisonResult.orderedAscending ? true : false
}

func numericSearch (_ left: String, right: String) -> Bool
{
    let result = left.compare(right, options: NSString.CompareOptions.numeric, range: nil, locale: nil)
    return result == ComparisonResult.orderedAscending ? true : false
}

func == (left: VehicleType, right: VehicleType) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: VehicleType, right: VehicleType) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func == (left: GliderQuals, right: GliderQuals) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: GliderQuals, right: GliderQuals) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func == (left: TowplaneQuals, right: TowplaneQuals) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: TowplaneQuals, right: TowplaneQuals) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func == (left: SessionTypes, right: SessionTypes) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: SessionTypes, right: SessionTypes) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func == (left: GliderSequence, right: GliderSequence) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: GliderSequence, right: GliderSequence) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func == (left: TowplaneSequence, right: TowplaneSequence) -> Bool
{
    return left.rawValue == right.rawValue ? true : false
}

func < (left: TowplaneSequence, right: TowplaneSequence) -> Bool
{
    return left.rawValue < right.rawValue ? true : false
}

func stringIsValidEmail(_ checkString: String) -> Bool
{
    let stricterFilterString = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
    let emailTest = NSPredicate(format: "SELF MATCHES %@", stricterFilterString)
    return emailTest.evaluate(with: checkString)
}

let logDateFormatter : DateFormatter =
{
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

func printLog(_ message : String, _ file : String = #file, _ function : String = #function, _ line : Int = #line)
{
    var startIndex = file.startIndex
    if let start = file.lastIndex(of: "/")
    {
        startIndex = file.index(after: start)
    }

    print("\(logDateFormatter.string(from: Date())) : \(file[startIndex...]).\(function)#\(line) : \(message)")
}
