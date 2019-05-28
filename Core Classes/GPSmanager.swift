//
//  GPSmanager.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-23.
//
//

import CoreLocation
import Foundation
import UIKit

protocol GPSmanagerDelegate
{
    func updateGlidingCentreButton(_ unit: String?)
    func saveContext()
    func reloadFetchedResults(_ note: Notification?)
}

final class GPSmanager : NSObject, CLLocationManagerDelegate
{
    var locationFinder = CLLocationManager()
    private var unitList = [String: GlidingCentreInfo]()
    typealias Position = (latitude: Double, longitude: Double)
    private var aerodromeList = [String: Position]()
    var mode: GPSmode = .nearestGC
    var delegate: GPSmanagerDelegate?
    var recordToUpdate: FlightRecord?
    
    override init()
    {
        super.init()
        
        locationFinder.delegate = self
        locationFinder.desiredAccuracy = kCLLocationAccuracyBest
        unitList = GlidingCentreInfo.initalizeGCInfoList()
        initializeAerodromeList()
    }
    
    func initializeAerodromeList()
    {
        let region = UserDefaults.standard.string(forKey: "Region") ?? "Northwest"
        let fileName = region + "Aerodromes"
        let myfile = Bundle.main.path(forResource: fileName, ofType: "csv") ?? ""
        let rawList: String
        
        do {try rawList = String(contentsOfFile: myfile, encoding: String.Encoding.ascii)}
        catch
        {
            UserDefaults.standard.set("Northwest", forKey: "Region")
            let region = UserDefaults.standard.string(forKey: "Region") ?? "Northwest"
            let fileName = region + "Aerodromes"
            let file = Bundle.main.path(forResource: fileName, ofType: "csv") ?? ""
            rawList = try! String(contentsOfFile: file, encoding: String.Encoding.ascii)
        }

        
        var separators = CharacterSet.newlines
        separators.insert(charactersIn: ",")
        let components = rawList.components(separatedBy: separators)
        var ident : String
        
        for i in stride(from: 0, to: components.count, by: 3)
        {            
            ident = components[i]
            aerodromeList[ident] = Position(components[i+1].doubleValue, components[i+2].doubleValue)
        }
    }
    
    func updateGlidingCentre()
    {
        let defaults = UserDefaults.standard
        let defaultsRegion = defaults.string(forKey: "Region")
        
        if defaultsRegion == nil
        {
            defaults.set("Northwest", forKey: "Region")
            defaults.synchronize()
            
            let errorText: String
            
            if regularFormat
            {
                errorText = "Your region has been set to Northwest by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left."
            }
                
            else
            {
                errorText = "Your region has been set to Northwest by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left of the pilots tab."
            }
            
            let regionAlert = UIAlertController(title: "Region Set", message: errorText, preferredStyle: .alert)
            let OKbutton = UIAlertAction(title: "OK", style: .default, handler: nil)
            regionAlert.addAction(OKbutton)
            
            UIViewController.presentOnTopmostViewController(regionAlert)
            
            delegate?.reloadFetchedResults(nil)
            delegate?.updateGlidingCentreButton("Gimli")
        }
        
        mode = .nearestGC
        locationFinder.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        if (status == .denied) || (status == .restricted)
        {
            let defaults = UserDefaults.standard
            let defaultsRegion = defaults.string(forKey: "Region")
            
            if defaultsRegion == nil
            {
                defaults.set("Northwest", forKey: "Region")
                defaults.synchronize()
                
                let errorText: String
                
                if regularFormat
                {
                    errorText = "Your region has been set to Northwest by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left."
                }
                    
                else
                {
                    errorText = "Your region has been set to Northwest by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left of the pilots tab."
                }
                let regionAlert = UIAlertController(title: "Region Set", message: errorText, preferredStyle: .alert)
                let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
                regionAlert.addAction(OKbutton)
                
                UIViewController.presentOnTopmostViewController(regionAlert)
                delegate?.reloadFetchedResults(nil)
            }
        }
    }
    
    func addXcountryStart(_ record: FlightRecord)
    {
        recordToUpdate = record
        mode = .xcountryStart
        locationFinder.requestLocation()
    }
    
    func addXcountryEnd(_ record: FlightRecord)
    {
        recordToUpdate = record
        mode = .xcountryEnd
        locationFinder.requestLocation()
    }
    
    //MARK: - Location Manager Delegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        guard let newLocation = locations.first else {return}
        
        if (newLocation.horizontalAccuracy > 500) || (newLocation.timestamp.timeIntervalSinceNow < -60)
        {
            return
        }
        
        let regionIsUnknown = true
        
        if mode == .nearestGC
        {
            let defaults = UserDefaults.standard
            if let _ = defaults.string(forKey: "Region")
            {
                unitList = GlidingCentreInfo.initalizeGCInfoList()
                unitList = GlidingCentreInfo.filterToCurrentRegion(unitList, includeSummerUnits: Date().IsDuringSummerOps)
                aerodromeList.removeAll(keepingCapacity: true)
                for (site, info) in unitList
                {
                    let coordinates = Position(info.latitude, info.longitude)
                    aerodromeList[site] = coordinates
                }
            }
        }
        
        let unitNames = aerodromeList.keys
        var closestUnit = unitNames.first ?? ""
        
        var closestUnitCoordinates = CLLocation(latitude: aerodromeList[closestUnit]!.latitude, longitude: aerodromeList[closestUnit]!.longitude)
        var comparaisonUnitCoordinates: CLLocation
        
        for comparaisonUnit in unitNames
        {
            comparaisonUnitCoordinates = CLLocation(latitude: aerodromeList[comparaisonUnit]!.latitude, longitude: aerodromeList[comparaisonUnit]!.longitude)
            if comparaisonUnitCoordinates.distance(from: newLocation) < closestUnitCoordinates.distance(from: newLocation)
            {
                closestUnitCoordinates = comparaisonUnitCoordinates
                closestUnit = comparaisonUnit
            }
            
        }
        
        switch mode
        {
        case .nearestGC:
            delegate?.updateGlidingCentreButton(closestUnit)
            
            if regionIsUnknown
            {
                guard let unitInfo = unitList[closestUnit] else {return}
                let region = unitInfo.region
                let defaults = UserDefaults.standard
                defaults.set(region, forKey: "Region")
                defaults.synchronize()
                delegate?.reloadFetchedResults(nil)
                                
                let errorText = "Your region has been set to \(region) based on your closest known gliding centre. This can be changed in settings."
                
                let regionAlert = UIAlertController(title: "Region Set", message: errorText, preferredStyle: .alert)
                let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
                regionAlert.addAction(OKbutton)
                
                UIViewController.presentOnTopmostViewController(regionAlert)
            }
            
        case .xcountryStart:
            let newRoute = "\(closestUnit)-?"
            
            if recordToUpdate?.transitRoute != newRoute
            {
                recordToUpdate?.transitRoute = newRoute
                delegate?.saveContext()
            }
            
        case .xcountryEnd:
            var routeSoFar = recordToUpdate?.transitRoute ?? "?-"
            let placeholder = routeSoFar.firstIndex(of: "-")!
            let rangeToReplace = routeSoFar.index(placeholder, offsetBy: 1) ... routeSoFar.index(routeSoFar.endIndex, offsetBy: -1)
            
            routeSoFar.replaceSubrange(rangeToReplace, with: closestUnit)
            
            if recordToUpdate?.transitRoute != routeSoFar
            {
                recordToUpdate?.transitRoute = routeSoFar
                delegate?.saveContext()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        return
    }
}
