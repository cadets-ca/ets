//
//  iBeaconManager.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-11.
//
//

import CoreBluetooth
import CoreLocation
import Foundation
import UIKit

protocol iBeaconDelegate
{
    func landAircraftWithBeacon(_ aircraftBeaconNumber: Int16)
    func updateAircraftWithBeacon(_ aircraftBeaconNumber: Int16)
}

final class iBeaconManager : NSObject, CLLocationManagerDelegate, CBPeripheralManagerDelegate
{
    let timesheetsUUID = UUID(uuidString: IBEACON_APP_IDENTIFIER)
    var broadcastMajorNumber = CLBeaconMajorValue(1)
    var delegate: iBeaconDelegate?
    let locationManager = CLLocationManager()
    var peripheralManager: CBPeripheralManager?
    var indicesOfNearbyAircraft = Set<Int16>()
    var rangesOfNearbyAircraft = Dictionary<Int16, CLProximity>()
    var iBeaconAssistance = false
    
    override init()
    {
        let defaults = UserDefaults.standard
        let iBeaconBroadcast = defaults.bool(forKey: "Transmit Beacon")
        iBeaconAssistance = defaults.bool(forKey: "iBeacon Assistance")
        
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true

        if iBeaconBroadcast
        {
            if let preferencesString = defaults.string(forKey: "Aircraft Registration")
            {
                if let majorValue = Int(preferencesString)
                {
                    broadcastMajorNumber = CLBeaconMajorValue(majorValue)
                    beginBeaconBroadcast()
                }
            }
        }
    }
    
    func beginMonitoringForBeacons()
    {
        if iBeaconAssistance
        {
            guard let timesheetsUUID = timesheetsUUID else {return}
            
            let set = locationManager.monitoredRegions as Set<CLRegion>
            for region in set
            {
                locationManager.stopMonitoring(for: region)
            }
            
            for aircraft in dataModel.aircraftAreaController?.fetchController.fetchedObjects ?? [AircraftEntity]()
            {
                let aircraftRegion = CLBeaconRegion(proximityUUID: timesheetsUUID, major: CLBeaconMajorValue(aircraft.beaconNumber), identifier: aircraft.tailNumber)
                aircraftRegion.notifyEntryStateOnDisplay = true
                aircraftRegion.notifyOnEntry = true
                aircraftRegion.notifyOnExit = true
                
                locationManager.startMonitoring(for: aircraftRegion)
            }
            
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion)
    {
        guard let region = region as? CLBeaconRegion else {return}
        locationManager.startRangingBeacons(in: region)
        
        locationManager.requestState(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion)
    {
        guard let region = region as? CLBeaconRegion else {return}

        locationManager.startRangingBeacons(in: region)
        
        let beaconValue = Int16(region.major!.intValue)

        if !indicesOfNearbyAircraft.contains(beaconValue)
        {
            indicesOfNearbyAircraft.insert(beaconValue)
            delegate?.landAircraftWithBeacon(beaconValue)
        }
        
        else
        {
            delegate?.updateAircraftWithBeacon(beaconValue)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion)
    {
        guard let region = region as? CLBeaconRegion else {return}
        locationManager.stopRangingBeacons(in: region)
        
        let beaconValue = Int16(region.major!.intValue)
        indicesOfNearbyAircraft.remove(beaconValue)
        rangesOfNearbyAircraft.removeValue(forKey: beaconValue)
        delegate?.updateAircraftWithBeacon(beaconValue)
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion)
    {
        for beacon in beacons as [CLBeacon]
        {
            let beaconValue = Int16(beacon.major.intValue)
            indicesOfNearbyAircraft.insert(beaconValue)
            
            if let oldRange = rangesOfNearbyAircraft[beaconValue], oldRange == beacon.proximity
            {
                return
            }
            
            else
            {
                rangesOfNearbyAircraft[beaconValue] = beacon.proximity
                delegate?.updateAircraftWithBeacon(beaconValue)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Location Manager failure \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Error)
    {
        print("ranging failed \(error.localizedDescription)")
        print("Region UUID \(region.proximityUUID.uuidString)")
    }
    
    func beginBeaconBroadcast()
    {
        if peripheralManager == nil
        {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        guard let timesheetsUUID = timesheetsUUID else {return}

        if peripheral.state == .poweredOn
        {
            let broadcastRegion = CLBeaconRegion(proximityUUID: timesheetsUUID, major: broadcastMajorNumber, minor: CLBeaconMinorValue(1), identifier: "Timesheets")
            if let peripheralData = NSDictionary(dictionary: broadcastRegion.peripheralData(withMeasuredPower: nil)) as? [String: AnyObject]
            {
                peripheralManager?.startAdvertising(peripheralData)
            }
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?){}
    
    func endBeaconBroadcast()
    {
        peripheralManager?.stopAdvertising()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        if status == .notDetermined
        {
            manager.requestAlwaysAuthorization()
            return
        }
    }
    
    func endMonitoringForBeacons()
    {
        for region in self.locationManager.monitoredRegions 
        {
            locationManager.stopMonitoring(for: region)
        }
    }
}
