//
//  FunStatsViewController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-06-21.
//
//

import Foundation
import UIKit
import CoreData
import NotificationCenter

final class FunStatsViewController : UITableViewController
{
    var numberOfGliderHogsToDisplay = 0
    var numberOfTowHogsToDisplay = 0
    var numberOfWinchHogsToDisplay = 0
    var numberOfLongFlightsToDisplay = 0
    var numberOfGlidingCentresInRegion = 0
    var numberOfGlidingCentresFlyingThisWeekend = 0
    
    var pilotsSortedByGliderFlights = [(Pilot, Int)]()
    var pilotsSortedByTowFlights = [(Pilot, Int)]()
    var pilotsSortedByWinchLaunches = [(Pilot, Int)]()
    
    var glidingCentresActiveLastFiveDays = [GlidingCentreData]()
    var glidingCentresActiveThisSeason = [GlidingCentreData]()

    var listOfGliderFlightsByLength = [FlightRecord]()

    override func viewDidLoad()
    {
        super.viewDidLoad()
//        cleanDatabase()
//        annonymize(); #warning("Turn this off!!!!")
//        cleanUbiquitousKeyValueStore(); #warning("Turn this off!!!!")
        
//        minuteStats(); #warning("Turn this off!!!!")
        
//        let obsoleteName = "BGC"
//        let currentName = "Brandon"
////
//        let mainStoreGcRequest = GlidingCentre.fetchRequest() as! NSFetchRequest<GlidingCentre>
//        mainStoreGcRequest.predicate = NSPredicate(format: "name == %@", obsoleteName)

        
        
//        let mainStoreRequest = Pilot.request
//        let startDate = Date() - 850*24*60*60
//        let endDate = Date() - 365*24*60*60*2
//
//        mainStoreRequest.predicate = NSPredicate(format: "timeIn < %@ OR timeIn > %@", startDate as CVarArg, endDate as CVarArg)

//        mainStoreRequest.predicate = NSPredicate(format: "highestScoutQual > 0 OR highestGliderQual > 0", argumentArray: [])
//
//        let matchingRecords = try! dataModel.managedObjectContext.fetch(mainStoreRequest)
//
//                for record in matchingRecords
//                {
//                    let request = AttendanceRecord.request
//                    request.predicate = NSPredicate(format: "pilot == %@", argumentArray: [record])
//                    let sortDescriptor = NSSortDescriptor(key: #keyPath(AttendanceRecord.timeIn), ascending: false)
//                    request.sortDescriptors = [sortDescriptor]
//                    let results = try! dataModel.managedObjectContext.fetch(request)
//
//                    if let mostRecentAttendanceRecord = results.first
//                    {
//                        record.glidingCentre = mostRecentAttendanceRecord.glidingCentre
//                    }
//
////                    print("deleted \(gc.name)")
////                    if record.picFlights.count == 0 && record.dualFlights.count == 0
////                    {
////                        dataModel.managedObjectContext.delete(record)
////                    }
////
////                    if record.name != currentName
////                    {
////                        dataModel.managedObjectContext.delete(record)
////                    }
////
////                    if record.flightRecords.count == 0
////                    {
////                        dataModel.managedObjectContext.delete(record)
////                    }
////
////                    dataModel.managedObjectContext.delete(record)
//
//                }
//        dataModel.saveContext()

//
        
//        var matchingGCs = try! dataModel.managedObjectContext.fetch(mainStoreGcRequest)
//
//        for gc in matchingGCs
//        {
//            print("name is \(gc.name)")
//        }
//
//        let obsolete = matchingGCs.first!
//        print("Obsolete contains \(obsolete.pilots.count) pilots, \(obsolete.timesheets.count) timesheets, \(obsolete.glidingDayComments.count) comments, and \(obsolete.attendaceRecords.count) attendance records")
//
//        mainStoreGcRequest.predicate = NSPredicate(format: "name == %@", currentName)
//        matchingGCs = try! dataModel.managedObjectContext.fetch(mainStoreGcRequest)
//        let current = matchingGCs.first!
//        print("Current contains \(current.pilots.count) pilots, \(current.timesheets.count) timesheets, \(current.glidingDayComments.count) comments, and \(current.attendaceRecords.count) attendance records")
//
//        obsolete.aircraft.removeAll()
//        current.attendaceRecords = current.attendaceRecords.union(obsolete.attendaceRecords)
//        obsolete.attendaceRecords.removeAll()
//        current.pilots = current.pilots.union(obsolete.pilots)
//        obsolete.pilots.removeAll()
//        current.timesheets = current.timesheets.union(obsolete.timesheets)
//        obsolete.timesheets.removeAll()
//        current.glidingDayComments = current.glidingDayComments.union(obsolete.glidingDayComments)
//        obsolete.glidingDayComments.removeAll()
//        dataModel.managedObjectContext.delete(obsolete)
//        print("Current contains \(current.pilots.count) pilots, \(current.timesheets.count) timesheets, \(current.glidingDayComments.count) comments, and \(current.attendaceRecords.count) attendance records")
//        dataModel.saveContext()
        
        
    
        let today = Date()
        let twelveWeeksAgo = today + TIME_PERIOD_FOR_FUN_STATS
        
        let request = FlightRecord.request
        request.predicate = NSPredicate(format: "timeUp > %@ AND timesheet.glidingCentre == %@", argumentArray: [twelveWeeksAgo, dataModel.glidingCentre!])
        let pilotSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.pilot.name), ascending: false)
        request.sortDescriptors = [pilotSortDescriptor]
        
        let recordsForCurrentGlidingCentreThisSeason = try! dataModel.managedObjectContext.fetch(request) 
        
        var gliderHogs = Dictionary<Pilot, Int>()
        var towHogs = Dictionary<Pilot, Int>()
        var winchHogs = Dictionary<Pilot, Int>()
        
        for record in recordsForCurrentGlidingCentreThisSeason
        {
            guard let type = record.timesheet?.aircraft?.type, let pilot = record.pilot else {continue}
            
            switch type
            {
            case .glider:
                if let flightsFound = gliderHogs[pilot]
                {
                    gliderHogs[pilot] =  flightsFound + 1
                }
                
                else
                {
                    gliderHogs[pilot] = 1
                }
                
            case .towplane:
                if let flightsFound = towHogs[pilot]
                {
                    towHogs[pilot] =  flightsFound + 1
                }
                    
                else
                {
                    towHogs[pilot] = 1
                }
                
            case .winch:
                if let flightsFound = winchHogs[pilot]
                {
                    winchHogs[pilot] =  flightsFound + 1
                }
                    
                else
                {
                    winchHogs[pilot] = 1
                }
                
            case .auto:
                break
            }
        }
        
        for (pilot, numberOfFlights) in gliderHogs
        {
            pilotsSortedByGliderFlights.append((pilot, numberOfFlights))
        }
        
        for (pilot, numberOfFlights) in towHogs
        {
            pilotsSortedByTowFlights.append((pilot, numberOfFlights))
        }
        
        for (pilot, numberOfFlights) in winchHogs
        {
            pilotsSortedByWinchLaunches.append((pilot, numberOfFlights))
        }
        
        pilotsSortedByGliderFlights.sort(by: {$0.1 > $1.1})
        pilotsSortedByTowFlights.sort(by: {$0.1 > $1.1})
        pilotsSortedByWinchLaunches.sort(by: {$0.1 > $1.1})
        
        let flightRecordRequest = FlightRecord.request
        flightRecordRequest.predicate = NSPredicate(format: "timeUp > %@ AND timesheet.glidingCentre == %@ AND timesheet.aircraft.gliderOrTowplane == 1 AND flightSequence != %@", argumentArray: [twelveWeeksAgo, dataModel.glidingCentre!, "Transit"])
        let flightTimeSortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.flightLengthInMinutes), ascending: false)
        flightRecordRequest.sortDescriptors = [flightTimeSortDescriptor]
        listOfGliderFlightsByLength = try! dataModel.managedObjectContext.fetch(flightRecordRequest) 
        
        numberOfGliderHogsToDisplay = pilotsSortedByGliderFlights.count >= 3 ? 4 : pilotsSortedByGliderFlights.count
        numberOfTowHogsToDisplay = pilotsSortedByTowFlights.count >= 3 ? 4 : pilotsSortedByTowFlights.count
        numberOfWinchHogsToDisplay = pilotsSortedByWinchLaunches.count >= 3 ? 4 : pilotsSortedByWinchLaunches.count
        numberOfLongFlightsToDisplay = listOfGliderFlightsByLength.count > 3 ? 4 : listOfGliderFlightsByLength.count
        
        updateInfo()
        numberOfGlidingCentresFlyingThisWeekend = glidingCentresActiveLastFiveDays.count
        numberOfGlidingCentresInRegion = glidingCentresActiveThisSeason.count
        
        tableView.backgroundColor = presentingViewController?.traitCollection.horizontalSizeClass == .compact ? UIColor.groupTableViewBackground : UIColor.clear
    }
    
    func updateInfo()
    {
        glidingCentresActiveLastFiveDays.removeAll(keepingCapacity: true)
        var keyValueStoreData = dataModel.keyValueStore.dictionaryRepresentation  as [String: AnyObject]
        
        for gcName in keyValueStoreData.keys
        {
            let gcDataDictionary = keyValueStoreData[gcName] as! [String: AnyObject]
            let processedData = GlidingCentreData(name: gcName, gcData: gcDataDictionary)
//            print("\(processedData)")
            
            if processedData.flightsInLastFiveDays > 0
            {
                glidingCentresActiveLastFiveDays.append(processedData)
            }
            
            if processedData.flightsThisSeason > 0 && processedData.activeInLast100Days == true
            {
                glidingCentresActiveThisSeason.append(processedData)
            }
        }
        
        glidingCentresActiveLastFiveDays.sort(by: >)
        glidingCentresActiveThisSeason.sort(by: >)

        preferredContentSize = CGSize(width: 0, height: self.tableView.contentSize.height)
        
        let controller = NCWidgetController()
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {return}
        
        if glidingCentresActiveLastFiveDays.count > 0
        {
            controller.setHasContent(true, forWidgetWithBundleIdentifier: bundleIdentifier)
        }
            
        else
        {
            controller.setHasContent(false, forWidgetWithBundleIdentifier: bundleIdentifier)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
    }
 
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = (indexPath as NSIndexPath).section < 4 ? tableView.dequeueReusableCell(withIdentifier: "RightDetailCell", for: indexPath) : tableView.dequeueReusableCell(withIdentifier: "StandardCell", for: indexPath)
        
        switch (indexPath as NSIndexPath).section
        {
        case 0:
            if ((indexPath as NSIndexPath).row == numberOfGliderHogsToDisplay - 1) && (numberOfGliderHogsToDisplay == 4)
            {
                cell.textLabel?.text = "Show All"
                cell.detailTextLabel?.text = ""
                
                if pilotsSortedByGliderFlights.count == 3
                {
                    cell.textLabel?.text = "All Pilots Shown"
                }
            }
                
            else
            {
                cell.textLabel?.text = pilotsSortedByGliderFlights[(indexPath as NSIndexPath).row].0.fullName
                cell.detailTextLabel?.text = "\(pilotsSortedByGliderFlights[(indexPath as NSIndexPath).row].1) Flights"
            }
            
        case 1:
            if ((indexPath as NSIndexPath).row == numberOfTowHogsToDisplay - 1) && (numberOfTowHogsToDisplay == 4)
            {
                cell.textLabel?.text = "Show All"
                cell.detailTextLabel?.text = ""
                
                if pilotsSortedByTowFlights.count == 3
                {
                    cell.textLabel?.text = "All Pilots Shown"
                }
            }
                
            else
            {
                cell.textLabel?.text = pilotsSortedByTowFlights[(indexPath as NSIndexPath).row].0.fullName
                cell.detailTextLabel?.text = "\(pilotsSortedByTowFlights[(indexPath as NSIndexPath).row].1) Flights"
            }
            
        case 2:
            if ((indexPath as NSIndexPath).row == numberOfWinchHogsToDisplay - 1) && (numberOfWinchHogsToDisplay == 4)
            {
                cell.textLabel?.text = "Show All"
                cell.detailTextLabel?.text = ""
                
                if pilotsSortedByWinchLaunches.count == 3
                {
                    cell.textLabel?.text = "All Pilots Shown"
                }
            }
                
            else
            {
                cell.textLabel?.text = pilotsSortedByWinchLaunches[(indexPath as NSIndexPath).row].0.fullName
                cell.detailTextLabel?.text = "\(pilotsSortedByWinchLaunches[(indexPath as NSIndexPath).row].1) Launches"
            }
            
        case 3:
            if ((indexPath as NSIndexPath).row == numberOfLongFlightsToDisplay - 1) && (numberOfLongFlightsToDisplay < listOfGliderFlightsByLength.count)
            {
                cell.textLabel?.text = "Show More"
                cell.detailTextLabel?.text = ""
            }
                
            else
            {
                let longestFlight = listOfGliderFlightsByLength[(indexPath as NSIndexPath).row]
                cell.textLabel?.text = longestFlight.pilot!.fullName + " (\(longestFlight.timeUp.militaryFormatShort))"
                cell.detailTextLabel?.text = String(fromMinutes: Double(longestFlight.flightLengthInMinutes))
            }
            
        case 4:
            let listOfGlidingCentresByFlights = glidingCentresActiveThisSeason.sorted {$0.flightsThisSeason > $1.flightsThisSeason}
            cell.textLabel?.text = "\(listOfGlidingCentresByFlights[(indexPath as NSIndexPath).row].gcName)"
            cell.detailTextLabel?.text = "\(listOfGlidingCentresByFlights[(indexPath as NSIndexPath).row].flightsThisSeason) Flights"
            
            let GCImage = UIImage(named: listOfGlidingCentresByFlights[(indexPath as NSIndexPath).row].gcName)
            cell.imageView?.image = GCImage
            
        case 5:
            let listOfGlidingCentresByMinutes = glidingCentresActiveThisSeason.sorted {$0.minutesThisSeason > $1.minutesThisSeason}
            let nameOfGC = listOfGlidingCentresByMinutes[(indexPath as NSIndexPath).row].gcName
            let numberOfMinutesFlownForGC = listOfGlidingCentresByMinutes[(indexPath as NSIndexPath).row].minutesThisSeason
            let hourString = String(fromMinutes: Double(numberOfMinutesFlownForGC))
            cell.textLabel?.text = nameOfGC
            cell.detailTextLabel?.text = hourString + " Hours"
            let GCImage = UIImage(named: nameOfGC)
            cell.imageView?.image = GCImage
            
        case 6:
            let listOfGlidingCentresByFlightsToday = glidingCentresActiveLastFiveDays
            let gcData = listOfGlidingCentresByFlightsToday[(indexPath as NSIndexPath).row]
            let nameOfGC = gcData.gcName
            let mostRecentLaunch = gcData.mostRecentFlight
            var cellTitle = nameOfGC
            
            if mostRecentLaunch.midnight > Date().midnight
            {
                cellTitle += " (Last Launch \(mostRecentLaunch.hoursAndMinutes))"
            }
            
            cell.textLabel?.text = cellTitle
            
            let flightsToday = gcData.flightsToday
            var cellDetailLabel = "\(flightsToday) Flight"
            
            if flightsToday != 1
            {
                cellDetailLabel += "s"
            }
            
            let fiveDaysAgo = Date().midnight + -4*24*60*60
            cellDetailLabel += " (\(gcData.flightsInLastFiveDays) since \(fiveDaysAgo.militaryFormatShort))"
            cell.detailTextLabel?.text = cellDetailLabel
            let GCImage = UIImage(named: nameOfGC)
            cell.imageView?.image = GCImage
            
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let numberOfRows: Int
        
        switch section
        {
        case 0:
            numberOfRows = numberOfGliderHogsToDisplay
            
        case 1:
            numberOfRows = numberOfTowHogsToDisplay
            
        case 2:
            numberOfRows = numberOfWinchHogsToDisplay
            
        case 3:
            numberOfRows = numberOfLongFlightsToDisplay
            
        case 4:
            numberOfRows = numberOfGlidingCentresInRegion
            
        case 5:
            numberOfRows = numberOfGlidingCentresInRegion
            
        case 6:
            numberOfRows = numberOfGlidingCentresFlyingThisWeekend
            
        default:
            numberOfRows = 0
        }
        
        return numberOfRows
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 7
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let title: String
        
        switch section
        {
        case 0:
            title = "Glider Hog"
            
        case 1:
            title = "Tow Hog"
            
        case 2:
            title = "Winch Hog"
            
        case 3:
            title = "Longest Glider Flight"
            
        case 4:
            title = "GCs by Glider Flights"
            
        case 5:
            title = "GCs by Glider Hours"
            
        case 6:
            title = "Today's Flying"
            
        default:
            title = ""
        }
        
        return title
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        return section == 6 ? "Data may not be available for all gliding centres." : nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch ((indexPath as NSIndexPath).section)
        {
        case 0:
            if ((indexPath as NSIndexPath).row == 3) && (numberOfGliderHogsToDisplay == 4) && (pilotsSortedByGliderFlights.count > 3)
            {
                numberOfGliderHogsToDisplay = pilotsSortedByGliderFlights.count
                var rowsToAdd = [IndexPath]()
                for i in 4 ..< pilotsSortedByGliderFlights.count
                {
                    rowsToAdd.append(IndexPath(row: i, section: 0))
                }
                
                tableView.beginUpdates()
                tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .fade)
                tableView.insertRows(at: rowsToAdd, with: .automatic)
                tableView.endUpdates()
            }
            
        case 1:
            if ((indexPath as NSIndexPath).row == 3) && (numberOfTowHogsToDisplay == 4) && (pilotsSortedByTowFlights.count > 3)
            {
                numberOfTowHogsToDisplay = pilotsSortedByTowFlights.count
                var rowsToAdd = [IndexPath]()
                for i in 4 ..< pilotsSortedByTowFlights.count
                {
                    rowsToAdd.append(IndexPath(row: i, section: 1))
                }
                
                tableView.beginUpdates()
                tableView.reloadRows(at: [IndexPath(row: 3, section: 1)], with: .fade)
                tableView.insertRows(at: rowsToAdd, with: .automatic)
                tableView.endUpdates()
            }
            
        case 2:
            if ((indexPath as NSIndexPath).row == 3) && (numberOfWinchHogsToDisplay == 4) && (pilotsSortedByWinchLaunches.count > 3)
            {
                numberOfWinchHogsToDisplay = pilotsSortedByWinchLaunches.count
                var rowsToAdd = [IndexPath]()
                for i in 4 ..< pilotsSortedByWinchLaunches.count
                {
                    rowsToAdd.append(IndexPath(row: i, section: 2))
                }
                
                tableView.beginUpdates()
                tableView.reloadRows(at: [IndexPath(row: 3, section: 2)], with: .fade)
                tableView.insertRows(at: rowsToAdd, with: .automatic)
                tableView.endUpdates()
            }
            
        case 3:
            if ((indexPath as NSIndexPath).row == numberOfLongFlightsToDisplay - 1) && (listOfGliderFlightsByLength.count > numberOfLongFlightsToDisplay)
            {
                let formerNumberOfLongFlightsShown = numberOfLongFlightsToDisplay - 1
                let newNumberOfLongFlightsShown = formerNumberOfLongFlightsShown + 5

                if newNumberOfLongFlightsShown >= listOfGliderFlightsByLength.count
                {
                    numberOfLongFlightsToDisplay = listOfGliderFlightsByLength.count
                }
                
                else
                {
                    numberOfLongFlightsToDisplay = newNumberOfLongFlightsShown + 1
                }
                
                var rowsToAdd = [IndexPath]()
                for i in (indexPath as NSIndexPath).row + 1 ..< numberOfLongFlightsToDisplay
                {
                    rowsToAdd.append(IndexPath(row: i, section: 3))
                }

                tableView.beginUpdates()
                tableView.reloadRows(at: [indexPath], with: .fade)
                tableView.insertRows(at: rowsToAdd, with: .automatic)
                tableView.endUpdates()
            }
            
        default:
            break
        }
    }
    
    func cleanUbiquitousKeyValueStore()
    {
        let keys = dataModel.keyValueStore.dictionaryRepresentation.keys
        
        for key in keys
        {
            dataModel.keyValueStore.removeObject(forKey: key)
        }
        
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ca.cadets.Timesheets")!
        let fullPath = containerURL.path.stringByAppendingPathComponent("KVSdata")

        (dataModel.keyValueStore.dictionaryRepresentation as NSDictionary).write(toFile: fullPath, atomically: true)
    }
    
    func cleanDatabase()
    {
        var request = Pilot.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND fullName == %@", "", "")
        var deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        var deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) pilots")
        
        request = GlidingDayComment.fetchRequest()
        request.predicate = NSPredicate(format: "glidingCentre == nil")
        deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) comments")
        
        request = FlightRecord.fetchRequest()
        request.predicate = NSPredicate(format: "timesheet == nil")
        deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) flight records")
        
        request = AircraftTimesheet.fetchRequest()
        request.predicate = NSPredicate(format: "aircraft == nil")
        deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) timesheets")
        
        request = AircraftTimesheet.fetchRequest()
        request.predicate = NSPredicate(format: "glidingCentre == nil")
        deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) timesheets")
        
        request = MaintenanceEvent.fetchRequest()
        request.predicate = NSPredicate(format: "aircraft == nil")
        deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) maintenance records")
        
        request = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(format: "pilot == nil")
        deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        deleteResults = try! dataModel.managedObjectContext.execute(deleteRequest) as! NSBatchDeleteResult
        print("Deleting \(deleteResults.result as! Int) attendance records")
        
//        let newRequest = AttendanceRecord.request
//        newRequest.predicate = NSPredicate(format: "pilot.typeOfParticipant == %@", argumentArray: ["cadet"])
//        let result = try! dataModel.managedObjectContext.fetch(newRequest)
//        for record in result
//        {
//            record.timeIn = record.recordID
//            dataModel.saveContext()
//        }
        
        dataModel.managedObjectContext.refreshAllObjects()
    }
    
    func annonymize()
    {
        var myfile = Bundle.main.path(forResource: "RandomNames", ofType: "csv")
        var rawList = try! String(contentsOfFile: myfile!, encoding: String.Encoding.ascii)

        let separators = CharacterSet.newlines
        let firstNames = rawList.components(separatedBy: separators)
        
        myfile = Bundle.main.path(forResource: "RandomSurnames", ofType: "csv")
        rawList = try! String(contentsOfFile: myfile!, encoding: String.Encoding.ascii)
        let lastNames = rawList.components(separatedBy: separators)
        
        let request = Pilot.request
        let pilotsFound = try! dataModel.managedObjectContext.fetch(request) 
        
        let numberOfSurnames = lastNames.count
        let numberOfNames = firstNames.count
        let squadronOffset = Int.random(in: 0...100)
        
        for pilot in pilotsFound
        {
            let indexOfNewSurname = Int.random(in: 0..<numberOfSurnames)
            let indexOfNewName = Int.random(in: 0..<numberOfNames)
            pilot.name = lastNames[indexOfNewSurname]
            pilot.firstName = firstNames[indexOfNewName]
            pilot.fullName = "\(pilot.name), \(pilot.firstName)"
            let randonSeconds = Int.random(in: 0..<(24*60*60*180))
            let dateOffset = Double(randonSeconds - 24*60*60*90)
            var licenseNumber = Int.random(in: 0...999999)
            
            while licenseNumber < 100000
            {
                licenseNumber = Int.random(in: 0...999999)
            }
            

            pilot.birthday = pilot.birthday + dateOffset
            
            pilot.email = ""
            pilot.squadron = pilot.squadron + Int16(squadronOffset)
            pilot.aniversaryOfGliderAPC = pilot.aniversaryOfGliderAPC + dateOffset
            pilot.aniversaryOfTowAPC = pilot.aniversaryOfTowAPC + dateOffset
            pilot.fiExpiry = pilot.fiExpiry + dateOffset
            pilot.medical = pilot.medical + dateOffset
            
            pilot.medicalThumbnailImage = nil
            pilot.photoThumbnailImage = nil
            pilot.gliderThumbnailImage = nil
            pilot.powerThumbnailImage = nil
            pilot.gliderLicense = "\(licenseNumber)"
            pilot.powerLicense = "\(licenseNumber)"
        }
        
        let pilotPhotoRequest = Photo.request
        let pilotPhotos = try! dataModel.managedObjectContext.fetch(pilotPhotoRequest) as [NSManagedObject]
        
        let gliderPhotoRequest = GliderLicenseImage.request
        let gliderPhotos = try! dataModel.managedObjectContext.fetch(gliderPhotoRequest) as [NSManagedObject]
        
        let powerPhotoRequest = PowerLicenseImage.request
        let powerPhotos = try! dataModel.managedObjectContext.fetch(powerPhotoRequest) as [NSManagedObject]
        
        let medicalPhotoRequest = MedicalImage.request
        let medicalPhotos = try! dataModel.managedObjectContext.fetch(medicalPhotoRequest) as [NSManagedObject]
        
        var itemsToDelete = [NSManagedObject]()
        
        itemsToDelete += pilotPhotos
        itemsToDelete += gliderPhotos
        itemsToDelete += powerPhotos
        itemsToDelete += medicalPhotos
        
        for object in itemsToDelete
        {
            dataModel.managedObjectContext.delete(object)
        }
        
        dataModel.saveContext()        
    }
    
    func minuteStats()
    {
        let hours = 5...21
        let minutes = 0...59
        
        var minutesAndFlights = [Int: Int]()
        var minutesAndFlightsCompressed = [Int: Int]()
        
        var decimalStartMinutes = [Int]()
        for minute in stride(from: 0, to: 60, by: 12)
        {
            decimalStartMinutes.append(minute)
        }
        
        for hour in hours
        {
            for minute in minutes
            {
                let time = hour*100 + minute
                minutesAndFlights[time] = 0
            }
            
            for minute in decimalStartMinutes
            {
                let time = hour*100 + minute
                minutesAndFlightsCompressed[time] = 0
            }
        }

        var components = gregorian.dateComponents([.year], from: Date())
        components.year = 2013
        components.month = 7
        components.day = 16
        components.hour = 1
        components.minute = 1
        let startTime = gregorian.date(from: components) ?? Date()

        components.month = 8
        components.day = 13
        let endTime = gregorian.date(from: components) ?? Date()
        
        let request = FlightRecord.request
        request.predicate = NSPredicate(format: "timeUp > %@ AND timeDown < %@ AND timesheet.glidingCentre == %@ AND timesheet.aircraft.gliderOrTowplane = 1", argumentArray: [startTime, endTime, dataModel.glidingCentre!])
        
        let records = try! dataModel.managedObjectContext.fetch(request)
        
        for record in records
        {
            guard let upTime = Int(record.timeUp.hoursAndMinutes) else {continue}
            
            if let priorLaunchesSameMinute = minutesAndFlights[upTime]
            {
                minutesAndFlights[upTime] = priorLaunchesSameMinute + 1
            }
        }

        let compressedKeys = minutesAndFlightsCompressed.keys.sorted(by: <)
        
        for key in compressedKeys
        {
            let affectedMinutes = [key, key + 1, key + 2, key + 3, key + 4, key + 5, key + 6, key + 7, key + 8, key + 9, key + 10, key + 11]
            var sum = 0
            for minute in affectedMinutes
            {
                if let value = minutesAndFlights[minute]
                {
                    sum += value
                }
            }
            minutesAndFlightsCompressed[key] = sum
            print("\(key) \(sum)")
        }
    }
}
