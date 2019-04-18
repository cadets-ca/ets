//
//  PlistManagement.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-07-20.
//
//

import Foundation

protocol ProvidesRegionAndDefunctAndSummerUnit
{
    var region: String {get}
    var defunct: Bool {get}
    var summerUnit: Bool {get}
}

struct GlidingCentreInfo: ProvidesRegionAndDefunctAndSummerUnit
{
    let defunct: Bool
    let latitude: Double
    let longitude: Double
    let region: String
    let fullName: String
    let summerUnit: Bool

    init(plistData: [String: AnyObject])
    {
        defunct = plistData["Defunct"] as? Bool ?? false
        latitude = plistData["Latitude"] as? Double ?? 0.0
        longitude = plistData["Longitude"] as? Double ?? 0.0
        region = plistData["Region"] as? String ?? "?"
        fullName = plistData["FullName"] as? String ?? "?"
        summerUnit = plistData["SummerUnit"] as? Bool ?? false
    }
    
    static func initalizeGCInfoList() -> [String: GlidingCentreInfo]
    {
        var returnDictionary = [String: GlidingCentreInfo]()
        
        if let coordinatesFilePath = Bundle.main.path(forResource: "GlidingCentreCoordinates", ofType:"plist")
        {
            let glidingCentreCoordinates = NSDictionary(contentsOfFile: coordinatesFilePath) as? [String: AnyObject] ?? [String: AnyObject]()
            for (name, data) in glidingCentreCoordinates
            {
                returnDictionary[name] = GlidingCentreInfo(plistData: data as? [String : AnyObject] ?? [String: AnyObject]())
            }
        }
        
        return returnDictionary
    }
}

struct CampFlightInfo: ProvidesRegionAndDefunctAndSummerUnit
{
    let defunct: Bool
    let region: String
    var summerUnit = true

    init(plistData: [String: AnyObject])
    {
        defunct = plistData["Defunct"] as? Bool ?? false
        region = plistData["Region"] as? String ?? "?"
        summerUnit = plistData["SummerUnit"] as? Bool ?? false
    }
    
    static func initalizeFlightInfoList() -> [String: CampFlightInfo]
    {
        var returnDictionary = [String: CampFlightInfo]()
        
        if let coordinatesFilePath = Bundle.main.path(forResource: "RGSflights", ofType:"plist")
        {
            let glidingCentreCoordinates = NSDictionary(contentsOfFile: coordinatesFilePath) as? [String: AnyObject] ?? [String: AnyObject]()
            for (name, data) in glidingCentreCoordinates
            {
                returnDictionary[name] = CampFlightInfo(plistData: data as? [String : AnyObject] ?? [String: AnyObject]())
            }
        }
        
        return returnDictionary
    }
}

extension ProvidesRegionAndDefunctAndSummerUnit
{
    static func filterToCurrentRegion<T: ProvidesRegionAndDefunctAndSummerUnit>(_ inputData: Dictionary<String, T>, includeSummerUnits: Bool = true) -> Dictionary<String, T>
    {
        var data = inputData
        let defaults = UserDefaults.standard
        let region: String? = defaults.string(forKey: "Region")
        
        var outOfRegionFlights = Set<String>()
        
        for (name, info) in data
        {
            if info.region != region
            {
                outOfRegionFlights.insert(name)
            }
            
            if info.defunct
            {
                outOfRegionFlights.insert(name)
            }
            
            if !includeSummerUnits
            {
                if info.summerUnit == true
                {
                    outOfRegionFlights.insert(name)
                }
            }
        }
        
        for flightName in outOfRegionFlights
        {
            data.removeValue(forKey: flightName)
        }
        
        return data
    }
}
