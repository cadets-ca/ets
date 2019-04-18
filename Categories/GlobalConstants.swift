//
//  GlobalConstants.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-12.
//
//

import Foundation
import UIKit

var observerMode = false                                                        //prevents the upload of any local changes to CloudKit
var trainingMode = false                                                        //prevents changes from being saved as well as prevents iCloud upload
var regularFormat = false
let LENGTH_OF_MIN_REST_PERIOD = 1500.0
let ATTENDANCE = 0
let TIMESHEETS = 1
let MAX_LENGTH_OF_CREW_SESSION = 21600
let LENGTH_OF_SUMMER_OPS = 6048000
let IBEACON_APP_IDENTIFIER = "FB1539E2-91CA-41C6-96B6-5C1755BB5836"
let RED_CELL_COLOR = "<td bgcolor='#FFD1D7'>"
let YELLOW_CELL_COLOR = "<td bgcolor='#FDFFC7'>"
let GREEN_CELL_COLOR = "<td bgcolor='#D1FFD8'>"
let BLACK_CELL_COLOR = "<td bgcolor='#000000'>"
let TIME_PERIOD_FOR_FUN_STATS = -7257600 as Double   //twelve weeks
let behavior = NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
let maxNumberOfFlightsPerPage = 30
let oneHundredYearsAgo = Date() - 100*24*60*60

//let globalQueue = DispatchQueue.global(qos: .default)
let mainQueue = DispatchQueue.main

let reloadPilotNotification = Notification.Name("ReloadPilotNotification")
let pilotBeingEditedNotification = Notification.Name("ChangeMadeToPilot")
let updateFlightCountersNotification = Notification.Name("UpdateFlightCounters")
let highestQualChangedNotification = Notification.Name("HighestQualChangedForPilot")
let aircraftChangedNotification = Notification.Name("AircraftChanged")
let glidingSiteSelectedNotification = Notification.Name("GlidingCentreSelected")
let nameChangedNotification = Notification.Name("PilotNameChange")
let enterOrExitViewPreviousRecordsNotification = Notification.Name("didEnterOrExitViewPreviousRecordsMode")
let recordsChangedNotification = Notification.Name("PilotRecordsChanged")
let flightRecordsChangedNotification = Notification.Name("FlightRecordChanged")
let refreshEverythingNotification = Notification.Name("RefetchAllDatabaseData")
let regionChangedNotification = Notification.Name("Region Changed")

let globalTintColor = UIColor(red: 16/255, green: 75/255, blue: 248/255, alpha: 1)
