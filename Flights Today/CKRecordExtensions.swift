//
//  CKRecordExtensions.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-25.
//

import Foundation
import CloudKit

struct FlightRecordData
{
    let timeUp: Date
    let timeDown: Date
    let recordChangeTime: Date
    let flightSequence: String
    let flightLengthInMinutes: Int
    let pilot: String
    let passenger: String
    let aircraft: String
    let connectedAircraft: String
    let glidingCenter: String
    let gliderOrTowplane: VehicleType
    
    init (record: CKRecord)
    {
        timeUp = record["timeUp"] as? Date ?? Date.distantPast
        timeDown = record["timeDown"] as? Date ?? Date.distantFuture
        recordChangeTime = record["recordChangeTime"] as? Date ?? Date.distantFuture
        gliderOrTowplane = VehicleType(rawValue: record["gliderOrTowplane"] as? Int ?? 0) ?? VehicleType.glider
        flightSequence = record["flightSequence"] as? String ?? ""
        pilot = record["pilot"] as? String ?? ""
        passenger = record["passenger"] as? String ?? ""
        aircraft = record["aircraft"] as? String ?? ""
        connectedAircraft = record["connectedAircraft"] as? String ?? ""
        glidingCenter = record["glidingCenter"] as? String ?? ""
        flightLengthInMinutes = record["flightLengthInMinutes"] as? Int ?? 0
    }
}

extension CKRecord
{
    var data: FlightRecordData
    {
        return FlightRecordData(record: self)
    }
}

struct PilotRecordData
{
    let medical: Date
    let gliderAPC: Date
    let FIexpiry: Date
    let dateModified: Date
    let typeOfParticipant: String
    let name: String
    let glidingSite: String
    let highestGliderQual: Int
    let highestTowQual: Int
    let recordID: Date

    init (record: CKRecord)
    {
        medical = record["medical"] as? Date ?? Date.distantPast
        gliderAPC = record["aniversaryOfGliderAPC"] as? Date ?? Date.distantPast
        FIexpiry = record["fiExpiry"] as? Date ?? Date.distantPast
        dateModified = record["recordChangeTime"] as? Date ?? Date.distantPast
        typeOfParticipant = record["typeOfParticipant"] as? String ?? ""
        name = record["fullName"] as? String ?? ""
        glidingSite = record["glidingCentre"] as? String ?? ""
        highestGliderQual = record["highestGliderQual"] as? Int ?? 0
        highestTowQual = record["highestScoutQual"] as? Int ?? 0
        recordID = record["ID"] as? Date ?? Date.distantPast
    }
}

extension CKRecord
{
    var pilotData: PilotRecordData
    {
        return PilotRecordData(record: self)
    }
}

