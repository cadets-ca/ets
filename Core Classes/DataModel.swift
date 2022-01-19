//
//  DataModel.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-17.
//
//

import MessageUI
import CoreLocation
import CoreData
import MobileCoreServices

final class TimesheetsDataModel: NSObject, AddPilotPopoverDelegate, NSFetchedResultsControllerDelegate, GPSmanagerDelegate, MFMailComposeViewControllerDelegate, iBeaconDelegate, SelectGlidingCentreDelegate
{
    var banditTally: UILabel?
    var apacheTally: UILabel?
    var totalTally: UILabel?
    var uploadsInProgress: UILabel?
    var downloadsInProgress: UILabel?
    var todayUnflownCadetsTally: UILabel?
    var glidingUnit: UIBarButtonItem?
    var previousRecordsGlidingUnit: UIBarButtonItem?
    var pilotAreaController: PilotsController?
    var previousRecordsPilotsController: PilotsController?
    var aircraftAreaController: Airplanes?
    var previousRecordsController: Records?
    var recordAreaController: Records?
    var pilotHours: NSMutableDictionary?
    var GPS: GPSmanager
    var managedObjectContext: NSManagedObjectContext
    var aircraftFetchedResults: NSFetchedResultsController<AircraftEntity>?
    var apacheController: NSFetchedResultsController<FlightRecord>?
    var banditController: NSFetchedResultsController<FlightRecord>?
    var totalController: NSFetchedResultsController<FlightRecord>?
    var unflownCadetsController: NSFetchedResultsController<AttendanceRecord>?
    var preferences: Dictionary<String, AnyObject>
    var glidingCentre: GlidingCentre!
    var previousRecordsGlidingCentre: GlidingCentre?
    var viewPreviousRecords = false
    var dateToViewRecords = Date().midnight + (-60*60*24)
    var picker: MFMailComposeViewController?
    var attachmentPath: String?
    var currentlySelectedCell: IndexPath?
    var PDFgenerator: NDHTMLtoPDF?
    var reportTypeBeingGenerated: ReportType?
    var startDate = Date()
    var endDate = Date()
    var tableText: String?
    var beaconManager: iBeaconManager
    let keyValueStore = NSUbiquitousKeyValueStore.default
    var statsManager: StatsManager
    var aircraftInTheAirRefreshTimer: Timer?
    var registeredAsObserver = false
    var addAircraftButton: UIBarButtonItem?
    var addPilotButton: UIBarButtonItem?
    var bottomRecord: IndexPath?
    var recordBeingEdited: UITableViewCell?
    var waitForScroll = false
    var attendanceOrTimesheets: UISegmentedControl?
    var timesheetBeingCompleted: AircraftTimesheet?
    var mergeFileQuery: NSMetadataQuery?
    var regionName = UserDefaults.standard.string(forKey: "Region")
    var editorName = "Unknown Editor"
    var editorLicense = "Unknown License"
    var editorSignInTime = Date.distantPast
    
    init(fromContext context: NSManagedObjectContext)
    {
        GPS = GPSmanager()
        beaconManager = iBeaconManager()
        statsManager = StatsManager()
        managedObjectContext = context
        
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last
        let savePath = path!.stringByAppendingPathComponent("Preferences.plist")
        
        if let savedPreferences = NSDictionary(contentsOfFile: savePath)
        {
            preferences = savedPreferences as! Dictionary<String, AnyObject>
        }
            
        else
        {
            preferences = [String: AnyObject]()
        }
        
        super.init()

        GPS.delegate = self
        beaconManager.delegate = self
        reloadFetchedResults(nil)

        if preferences["GlidingCentre"] == nil
        {
            updateGlidingCentreButton("Gimli")
        }
    }
    
    //MARK: - Add Pilot Popover Delegate
    func signInFlight(_ flight: String)
    {
        let request = Pilot.request
        request.predicate = NSPredicate(format: "glidingCentre == %@ AND summerUnit.name == %@", glidingCentre, flight)
        let pilots = try! managedObjectContext.fetch(request)
        
        for pilot in pilots
        {
            createAttendanceRecordForPerson(pilot)
        }
        
        saveContext()
    }
    
    /// Creates a new attendance record. If for a previous date, the pilot will be signed in at 0800 and out at 1700. If for today, the pilot is signed in at the current time.
    ///
    /// - parameter pilotToAdd: The pilot who will be signed in
    func createAttendanceRecordForPerson(_ pilotToAdd: Pilot)
    {
        let request = AttendanceRecord.request
        
        if viewPreviousRecords
        {
            let midnightOnTargetDate = dateToViewRecords.midnight
            let oneDayLater = midnightOnTargetDate + 60*60*24
            request.predicate = NSPredicate(format: "timeIn > %@ AND timeIn < %@ AND pilot == %@", argumentArray: [midnightOnTargetDate, oneDayLater, pilotToAdd])
        }
            
        else
        {
            request.predicate = NSPredicate(format: "timeIn > %@ AND pilot == %@", argumentArray: [Date().midnight, pilotToAdd])
        }
        
        let attendanceRecordsFound = try! managedObjectContext.fetch(request) 
        let record: AttendanceRecord?
        
        if attendanceRecordsFound.count > 0
        {
            record = attendanceRecordsFound.first
            if record?.glidingCentre != glidingCentre
            {
                record?.glidingCentre = glidingCentre
            }
        }
            
        else
        {
            record = AttendanceRecord(context: managedObjectContext)
            record?.pilot = pilotToAdd
            record?.glidingCentre = glidingCentre
            record?.participantType = pilotToAdd.typeOfParticipant
            
            if viewPreviousRecords
            {
                let midnightOnTargetDate = dateToViewRecords.midnight
                let eightInTheMorning = midnightOnTargetDate + 60*60*8
                let fiveInTheAfternoon = midnightOnTargetDate + 60*60*17
                record?.timeIn = eightInTheMorning
                record?.timeOut = fiveInTheAfternoon
                record?.glidingCentre = previousRecordsGlidingCentre
            }
                
            else
            {
                record?.glidingCentre = glidingCentre
                record?.timeOut = Date.distantFuture
                record?.timeIn = record?.participantType == "cadet" ? Date().midnight + 60*60*6 : Date()
            }
        }
        
        if !viewPreviousRecords
        {
            if record?.timeOut != Date.distantFuture
            {
                record?.timeOut = Date.distantFuture
            }
            
            if pilotToAdd.signedIn == false
            {
                pilotToAdd.signedIn = true
            }
            
            verifyCorrectGCforPilot(pilotToAdd)
        }
    }
    
    func verifyCorrectGCforPilot(_ pilot: Pilot)
    {
        let request = AttendanceRecord.request
        request.predicate = NSPredicate(format: "pilot == %@", pilot)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(AttendanceRecord.timeIn), ascending: false)]
        let attendanceRecordsFound = try! managedObjectContext.fetch(request) 
        
        if attendanceRecordsFound.count > 3
        {
            let GCsignedInAt = attendanceRecordsFound.first!.glidingCentre!
            
            if pilot.glidingCentre !== GCsignedInAt
            {
                if attendanceRecordsFound[1].glidingCentre === GCsignedInAt && attendanceRecordsFound[2].glidingCentre === GCsignedInAt
                {
                    pilot.glidingCentre = GCsignedInAt
                }
            }
        }
    }
    
    func signOutPerson(_ pilotToRemove: Pilot)
    {
        if let aircraft = pilotToRemove.aircraft
        {
            if aircraft.status == .flying
            {
                let errorTitle = "Can't Sign Out \(pilotToRemove.name)"
                let errorMessage = "\(pilotToRemove.name) is currently flying in \(aircraft.tailNumber)."
                
                let pilotCannotBeSignedOut = UIAlertController(title: errorTitle, message: errorMessage, preferredStyle: .alert)
                let OKbutton = UIAlertAction(title: "OK", style: .default, handler: nil)
                pilotCannotBeSignedOut.addAction(OKbutton)
                presentController(pilotCannotBeSignedOut)
                return
            }
                
            else
            {
                if let PICofAircraft = aircraft.pilot, PICofAircraft === pilotToRemove
                {
                    aircraft.pilot = nil
                }
                    
                else
                {
                    aircraft.passenger = nil
                }
            }
        }
        
        let request = AttendanceRecord.request
        request.predicate = NSPredicate(format: "timeIn >= %@ AND pilot == %@", argumentArray: [Date().midnight, pilotToRemove])
        let recordsFound = try! managedObjectContext.fetch(request)
        for  record in recordsFound  //multiple records may exist if, for example, they were created on different devices. This block reduces it to one record per day.
        {
            if record == recordsFound.first
            {
                record.timeOut = Date()
                if (record.timeOut - record.timeIn < 10*60) && (pilotToRemove.typeOfParticipant != "cadet")
                {
                    cloudKitController?.deleteAttendanceRecord(record)
                    managedObjectContext.delete(record)
                }
                    
                else
                {
                    if (record.timeOut - record.timeIn) > Double(MAX_LENGTH_OF_CREW_SESSION)
                    {
                        record.dayOrSession = true
                    }
                }
            }
            
            else
            {
                cloudKitController?.deleteAttendanceRecord(record)
                managedObjectContext.delete(record)
            }
        }
        
        pilotToRemove.signedIn = false
        NotificationCenter.default.post(name: reloadPilotNotification, object: pilotToRemove, userInfo: nil)
    }
    
    //MARK: - Fetched results controller
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        NotificationQueue.default.enqueue(Notification(name: updateFlightCountersNotification), postingStyle: .whenIdle, coalesceMask: [.onName], forModes: nil)
    }

    @objc func reloadFetchedResults(_ note: Notification?)
    {
        if let note = note
        {
//            managedObjectContext.performBlock()
//                {
            managedObjectContext.mergeChanges(fromContextDidSave: note)
//                }
            
            closeOpenAttendanceRecordsFromPreviousDays()
            pilotAreaController?.reloadEverything()
            recordAreaController?.reloadData()
            aircraftAreaController?.reloadData()
        }
        
        let lastRunDate = UserDefaults().lastRunDate
        if !lastRunDate.isDateInToday
        {
            let request = Pilot.request
            request.predicate = NSPredicate(format: "signedIn == 1")
            if let openRecords = try? managedObjectContext.fetch(request)
            {
                for pilot in openRecords
                {
                    signOutPerson(pilot)
                }
            }
        }
        
        regionName = UserDefaults.standard.string(forKey: "Region")
        configureFlightCounters()
        saveContext()
    }
    
    func configureFlightCounters()
    {
        if glidingCentre == nil
        {
            return
        }
        
        var midnightOnTargetDate: Date
        var oneDayLater: Date
        var centreForApacheAndBanditTally: GlidingCentre
        
        if viewPreviousRecords == true
        {
            midnightOnTargetDate = dateToViewRecords.midnight
            oneDayLater = midnightOnTargetDate + 60*60*24
            centreForApacheAndBanditTally = previousRecordsGlidingCentre ?? glidingCentre!
        }
            
        else
        {
            midnightOnTargetDate = Date().midnight
            oneDayLater = Date.distantFuture
            centreForApacheAndBanditTally = glidingCentre!
        }
        
        let apacheFetchRequest = FlightRecord.request
        apacheFetchRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.glidingCentre == %@ AND flightSequence == %@ AND ((pilot.summerUnit.name == %@ AND pilot.highestGliderQual < %@) OR (passenger.summerUnit.name = %@ AND passenger.highestGliderQual < %@))", argumentArray: [midnightOnTargetDate, oneDayLater, centreForApacheAndBanditTally, "Student Trg", "Apache", NSNumber(value: Int(GliderQuals.instructor.rawValue)), "Apache", NSNumber(value: Int(GliderQuals.instructor.rawValue))])
        let sortDescriptor = NSSortDescriptor(key: #keyPath(FlightRecord.timeUp), ascending:true)
        apacheFetchRequest.sortDescriptors = [sortDescriptor]
        apacheController = NSFetchedResultsController(fetchRequest: apacheFetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath:nil, cacheName:nil)
        apacheController?.delegate = self
        try! apacheController?.performFetch()
        
        let banditFetchRequest = FlightRecord.request
        banditFetchRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.glidingCentre == %@ AND flightSequence == %@ AND ((pilot.summerUnit.name == %@ AND pilot.highestGliderQual < %@) OR (passenger.summerUnit.name = %@ AND passenger.highestGliderQual < %@))", argumentArray: [midnightOnTargetDate, oneDayLater, centreForApacheAndBanditTally, "Student Trg", "Bandit", NSNumber(value: Int(GliderQuals.instructor.rawValue)), "Bandit", NSNumber(value: Int(GliderQuals.instructor.rawValue))])
        banditFetchRequest.sortDescriptors = [sortDescriptor]
        banditController = NSFetchedResultsController(fetchRequest: banditFetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath:nil, cacheName:nil)
        banditController?.delegate = self
        try! banditController?.performFetch()
        
        let totalFetchRequest = FlightRecord.request
        totalFetchRequest.predicate = NSPredicate(format: "timeUp > %@ AND timeUp < %@ AND timesheet.glidingCentre == %@ AND (flightSequence == %@ OR flightSequence == %@ OR flightSequence == %@)", argumentArray: [midnightOnTargetDate, oneDayLater, centreForApacheAndBanditTally, "Towing", "Winching", "Auto"])
        totalFetchRequest.sortDescriptors = [sortDescriptor]
        totalController = NSFetchedResultsController(fetchRequest: totalFetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath:nil, cacheName:nil)
        totalController?.delegate = self
        try! totalController?.performFetch()
        
        let unflownCadetFetchRequest = AttendanceRecord.request
        unflownCadetFetchRequest.predicate = NSPredicate(format: "timeIn >= %@ AND timeOut == %@ AND glidingCentre == %@ AND pilot.typeOfParticipant == %@", argumentArray: [Date().midnight, Date.distantFuture, glidingCentre!, "cadet"])
        unflownCadetFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(AttendanceRecord.timeIn), ascending: true)]
        unflownCadetsController = NSFetchedResultsController(fetchRequest: unflownCadetFetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath:nil, cacheName:nil)
        unflownCadetsController?.delegate = self
        try! unflownCadetsController?.performFetch()
        
        NotificationQueue.default.enqueue(Notification(name: updateFlightCountersNotification), postingStyle: .whenIdle, coalesceMask: [.onName], forModes: nil)
    }
    
    /// Saves the preferences dictionary to disk
    func save()
    {
        (preferences as NSDictionary).write(toFile: saveFilePath(), atomically:true)
    }
    
    func saveContext()
    {
        guard trainingMode == false else {return}
        
        if managedObjectContext.persistentStoreCoordinator!.persistentStores.count > 0
        {
            do
            {
                try managedObjectContext.save()
            }
                
            catch let error as NSError
            {
                print("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
            
            catch
            {
                print("Unknown Error")
                abort()
            }
        }
    }
    
    func saveFilePath() -> String
    {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last
        return path!.stringByAppendingPathComponent("Preferences.plist")
    }
    
    //MARK: - GPS delegate
    func reloadRecords()
    {
        recordAreaController?.tableView.reloadData()
        return
    }
    
    func updateGlidingCentreButton(_ unit: String?)
    {
        guard let newUnit = unit, newUnit != "" else {return}
        
        if !((viewPreviousRecords == true) && regularFormat)
        {
            glidingUnit?.title = newUnit
            preferences["GlidingCentre"] = newUnit as NSString
            self.save()
            
//            if let tabBar = pilotAreaController?.tabBarController
//            {
//                if let viewControllers = tabBar.viewControllers, viewControllers.count > 1, let siteSelector = viewControllers.first as? SelectGlidingCentre
//                {
//                    siteSelector.configure()
//                }
//            }
        }
            
        else
        {
            previousRecordsGlidingUnit?.title = newUnit
        }
        
        let GCRequest = GlidingCentre.request
        GCRequest.predicate = NSPredicate(format: "name == %@", newUnit)
        guard let availableGCs = try? managedObjectContext.fetch(GCRequest) else {return}
        
        if (viewPreviousRecords == true) && regularFormat
        {
            if availableGCs.count > 0
            {
                previousRecordsGlidingCentre = availableGCs.first
            }
                
            else
            {
                previousRecordsGlidingCentre = GlidingCentre(context: managedObjectContext)
                previousRecordsGlidingCentre?.name = newUnit
                saveContext()
            }
        }
            
        else
        {
            if availableGCs.count > 0
            {
                glidingCentre = availableGCs.first
            }
                
            else
            {
                glidingCentre = GlidingCentre(context: managedObjectContext)
                glidingCentre?.name = newUnit
                saveContext()
                
            }
            
            configureFlightCounters()
        }
        
        NotificationCenter.default.post(name: glidingSiteSelectedNotification, object:self, userInfo:nil)
        configureFlightCounters()
    }
    
    //MARK: - Exporting Records
    func emailTimesheets(_ overideAlert: Bool,_ includeChanges: Bool = false)
    {
        // TODO: Currently working on this report!!
        reportTypeBeingGenerated = ReportType.timesheets
        let GC = (regularFormat && viewPreviousRecords) ? previousRecordsGlidingCentre! : glidingCentre
        
        var noRecordsToEmail = false
        
        if regularFormat && viewPreviousRecords
        {
            if previousRecordsController?.fetchController?.fetchedObjects?.count == 0
            {
                noRecordsToEmail = true
            }
        }
            
        else
        {
            if recordAreaController?.fetchController?.fetchedObjects?.count == 0
            {
                noRecordsToEmail = true
            }
        }
        
        if noRecordsToEmail
        {
            let noRecords = UIAlertController(title: "No Records", message: "There are currently no stored flight records to send.", preferredStyle: .alert)
            let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
            noRecords.addAction(OKbutton)
            presentController(noRecords)
            return
        }
        
        if !overideAlert
        {
            let winchTTSNcorrect = viewPreviousRecords ? checkThatWinchFinalTTSNisProvidedForDate(dateToViewRecords) :  checkThatWinchFinalTTSNisProvidedForDate(Date())
            if winchTTSNcorrect == false
            {
                return
            }
        }

        // TODO: allow for generating report even when email not enabled.
        //guard checkIfCanSendMailAndAlertUserIfNot() else {return}
        let param = TimesheetsForDateParameters(
            dateOfTimesheets: viewPreviousRecords ? dateToViewRecords : Date(),
            glidingCentre: GC,
            regionName: UserDefaults.standard.string(forKey: "Region")?.uppercased() ?? "unknown region",
            includeChangeLog: includeChanges)
        
        ReportProducer().produce( report: TimesheetsForDate(param), then: {
            (urls) in
            Distributor.getDistributor(withParentView: self.aircraftAreaController?.parent).distribute(urls, given: param)
        })
    }
    
    func emailPilotLogs()
    {
        // FIXME: Why checkIfCanSendMailAndAlertUserIfNot not called
        let GC = (regularFormat && viewPreviousRecords) ? previousRecordsGlidingCentre! : glidingCentre
        
        var noRecordsToEmail = false
        
        if regularFormat && viewPreviousRecords
        {
            if previousRecordsController?.fetchController?.fetchedObjects?.count == 0
            {
                noRecordsToEmail = true
            }
        }
            
        else
        {
            if recordAreaController?.fetchController?.fetchedObjects?.count == 0
            {
                noRecordsToEmail = true
            }
        }
        
        if noRecordsToEmail
        {
            let noRecords = UIAlertController(title: "No Records", message: "There are currently no stored flight records to send.", preferredStyle: .alert)
            let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
            noRecords.addAction(OKbutton)
            UIViewController.presentOnTopmostViewController(noRecords)
            return
        }
        
        
        let swiftGenerator = ReportGenerator()
        swiftGenerator.regionName = UserDefaults.standard.string(forKey: "Region")?.uppercased()
        swiftGenerator.unit = GC?.name
        
        let swiftGeneratorResults = viewPreviousRecords ? swiftGenerator.generatePilotLogsForDate(dateToViewRecords) : swiftGenerator.generatePilotLogsForDate(Date())
        
        let tableText = swiftGeneratorResults.HTML
        
        let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
        let path = pathArray.first?.stringByAppendingPathComponent("Timesheets.html") ?? ""
        
        picker = MFMailComposeViewController()
        picker?.mailComposeDelegate = self
        
        let today = viewPreviousRecords ? dateToViewRecords : Date()
        let todayDate = today.militaryFormatLong
        let subjectLine = todayDate + " \(GC!.name) Pilot Logs"
        
        picker?.setSubject(subjectLine)
        picker?.setToRecipients(swiftGeneratorResults.emailAddresses)
        
        let attachmentName = "\(todayDate)-\(GC!.name)-Pilot-Logs.html"
        
        let myData = try? Data(contentsOf: URL(fileURLWithPath: path))
        attachmentPath = path
        picker?.addAttachmentData(myData!, mimeType: "text/html", fileName: attachmentName)
        picker?.setMessageBody(tableText, isHTML: true)
        UIViewController.presentOnTopmostViewController(picker!)
    }
    
    func emailLogBookForPilot(_ pilot: Pilot, fromDate startDate: Date, toDate endDate: Date)
    {
        guard checkIfCanSendMailAndAlertUserIfNot() else {return}
        
        let swiftGenerator  = ReportGenerator()
        let swiftLogText = swiftGenerator.personalLogBookForPilot(pilot, fromDate: startDate, toDate: endDate)

        let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
        let path = pathArray.first?.stringByAppendingPathComponent("Timesheets.html") ?? ""
        
        picker = MFMailComposeViewController()
        picker?.mailComposeDelegate = self
        
        let subjectLine = "\(pilot.fullName) Log Book \(startDate.militaryFormatShort) to \(endDate.militaryFormatShort)"
        picker?.setSubject(subjectLine)
        
        if pilot.email != ""
        {
            picker?.setToRecipients([pilot.email])
        }
        
        let attachmentName = "\(pilot.name)-Pilot-Logs.html"
        
        let myData = try? Data(contentsOf: URL(fileURLWithPath: path))
        attachmentPath = path
        picker?.addAttachmentData(myData!, mimeType: "text/html", fileName: attachmentName)
        picker?.setMessageBody(swiftLogText, isHTML: true)
        UIViewController.presentOnTopmostViewController(picker!)
    }
    
    func emailLocalStatsReportFromDate(_ startDate: Date, toDate endDate:Date)
    {
        // set report parameters
        let GC = (regularFormat && viewPreviousRecords) ? previousRecordsGlidingCentre! : glidingCentre
        let regionName = (UserDefaults.standard.string(forKey: "Region")?.uppercased()) ?? "unknown region"
        let param = StatsReportFromDateParameters(startDate: startDate, endDate: endDate, glidingCentre: GC, regionName: regionName)

        // produce and distribute the report
        ReportProducer().produce( report: StatsReportFromDate(param), then: {
            (urls) in
            Distributor.getDistributor(withParentView: self.aircraftAreaController?.parent).distribute(urls, given: param)
        })
    }
    
    func emailRegionalStatsReportFromDate(_ startDate: Date, toDate endDate:Date)
    {
        // set report parameters
        let regionName = (UserDefaults.standard.string(forKey: "Region")?.uppercased()) ?? "unknown region"
        let param = StatsReportFromDateParameters(startDate: startDate, endDate: endDate, glidingCentre: nil, regionName: regionName)
        
        // produce the report and distribute (email or, if no email available, Activity (share)
        ReportProducer().produce( report: StatsReportFromDate(param), then: {
            (urls) in
            Distributor.getDistributor(withParentView: self.aircraftAreaController?.parent).distribute(urls, given: param)
        })
    }

    func checkThatWinchFinalTTSNisProvidedForDate(_ date: Date) -> Bool
    {
        let GC = (regularFormat && viewPreviousRecords) ? previousRecordsGlidingCentre! : glidingCentre
        
        let beginningOfDay = date.midnight
        let endOfDay = beginningOfDay + (60*60*24)
        
        let request = AircraftTimesheet.request
        request.predicate = NSPredicate(format: "%K > %@ AND %K < %@ AND %K == %@", argumentArray: [#keyPath(AircraftTimesheet.date), beginningOfDay, #keyPath(AircraftTimesheet.date), endOfDay, #keyPath(AircraftTimesheet.glidingCentre.name), GC!.name])
        let tailNumberSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.aircraft.tailNumber), ascending: true)
        let dateSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: true)
        request.sortDescriptors = [tailNumberSortDescriptor, dateSortDescriptor]
        guard let timesheets = try? managedObjectContext.fetch(request) else {return false}
        
        for timesheet in timesheets
        {
            if (timesheet.aircraft.type == .winch) && (timesheet.winchFinalTTSNsetCorrectly == false)
            {
                let messageText = "Enter the current TTSN for the winch \(timesheet.aircraft.tailNumber)."
                
                let enterTTSNalert = UIAlertController(title: "Enter Winch Hours", message: messageText, preferredStyle: .alert)
                let OKbutton = UIAlertAction(title: "Enter Later", style: .default){_ in self.emailTimesheets(true)}
                
                let enterButton = UIAlertAction(title: "Enter Time", style: .default){_ in
                    let textField = (enterTTSNalert.textFields)?.first
                    let hours = textField?.text ?? "0"
                    if Int(hours) == 0
                    {
                        let enterTTSNerror = UIAlertController(title: "Warning", message: "You have not entered a valid number.", preferredStyle: .alert)
                        let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
                        enterTTSNerror.addAction(OKbutton)
                        UIViewController.presentOnTopmostViewController(enterTTSNerror)
                        return
                    }
                
                    let decimalValue = Decimal(string: hours) ?? 0
                    timesheet.TTSNfinal = decimalValue
                    timesheet.winchFinalTTSNsetCorrectly = true
                    self.saveContext()
                    self.emailTimesheets(false)
                    
                    let timeToday = timesheet.TTSNfinal - timesheet.TTSNinitial
                    if timeToday < 0
                    {
                        let enterTTSNerror = UIAlertController(title: "Warning", message: "The TTSN at the end of the day precedes the TTSN at the beginning. You may wish to double check the value.", preferredStyle: .alert)
                        let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
                        enterTTSNerror.addAction(OKbutton)
                        UIViewController.presentOnTopmostViewController(enterTTSNerror)
                    }
                }
                
                enterTTSNalert.addTextField(){(textField: UITextField!) in
                    textField.keyboardType = regularFormat ? .numberPad : .decimalPad}
                enterTTSNalert.addAction(OKbutton)
                enterTTSNalert.addAction(enterButton)
                UIViewController.presentOnTopmostViewController(enterTTSNalert)
                return false
            }
        }
        
        return true
    }
    
    func backupDatabaseForSite(_ siteName: String, includePhotos: Bool, andMoveFileToCloud moveToCloud: Bool)
    {
        let manager = FileManager.default
        let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String]
        let sharingPath = pathArray.first?.stringByAppendingPathComponent("TimesheetsBackup.sqlite") ?? ""
        let mainDatabasePath = pathArray.first?.stringByAppendingPathComponent("Timesheets.sqlite") ?? ""
        if manager.fileExists(atPath: sharingPath)
        {
            do {try manager.removeItem(atPath: sharingPath)}
            catch {return}
        }
        
        let uniqueStorageString = "\(Date())"
        let uniqueStoragePath = pathArray.first!.stringByAppendingPathComponent(uniqueStorageString)
        let backupPathURL = URL(fileURLWithPath: uniqueStoragePath)
        let model = NSManagedObjectModel.mergedModel(from: nil)!
        let migrationManager = NSMigrationManager(sourceModel: model, destinationModel: model)
        let storeURL = URL(fileURLWithPath: mainDatabasePath)
        do {let map = try NSMappingModel.inferredMappingModel(forSourceModel: model, destinationModel: model)
        try migrationManager.migrateStore(from: storeURL, sourceType: NSSQLiteStoreType, options: nil, with: map, toDestinationURL: backupPathURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)}
        catch {return}
        
        if !includePhotos
        {
            let model = NSManagedObjectModel.mergedModel(from: nil)!
            let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
            temporaryContext.persistentStoreCoordinator = psc
            let options = [NSSQLiteManualVacuumOption: true, NSSQLitePragmasOption : ["journal_mode" : "DELETE"]] as [String : Any]
            let store: NSPersistentStore?
            do
            {
                store = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at: backupPathURL, options: options as [NSObject : AnyObject])
            }
            
            catch _
            {
                store = nil
            }
            
            temporaryContext.performAndWait()
            {
                Pilot.changeShouldUpdateChangeTimesToValue(false)

                let twelveWeeksAgo = Date() + TIME_PERIOD_FOR_FUN_STATS
                let oldTimesheetsRequest = AircraftTimesheet.fetchRequest()
                oldTimesheetsRequest.predicate = NSPredicate(format: "date < %@ OR glidingCentre.name != %@", argumentArray: [twelveWeeksAgo, siteName])
                var deleteRequest = NSBatchDeleteRequest(fetchRequest: oldTimesheetsRequest)
                deleteRequest.resultType = .resultTypeCount
                do {let _ = try temporaryContext.execute(deleteRequest)}
                catch {return}

                let oldAttendanceRequest = AttendanceRecord.fetchRequest()
                oldAttendanceRequest.predicate = NSPredicate(format: "timeIn < %@ OR glidingCentre.name != %@", argumentArray: [twelveWeeksAgo, siteName])
                deleteRequest = NSBatchDeleteRequest(fetchRequest: oldAttendanceRequest)
                deleteRequest.resultType = .resultTypeCount
                do {let _ = try temporaryContext.execute(deleteRequest)
                    try temporaryContext.save()}
                catch {return}
                temporaryContext.reset()
                temporaryContext.refreshAllObjects()

                let pilotRequest = Pilot.request
                if let pilots = try? temporaryContext.fetch(pilotRequest)
                {
                    for pilot in pilots
                    {
                        if let photo = pilot.photo
                        {
                            temporaryContext.delete(photo)
                        }
                        
                        pilot.medicalThumbnailImage = nil
                        if let medicalImage = pilot.medicalImage
                        {
                            temporaryContext.delete(medicalImage)
                        }
                        
                        pilot.photoThumbnailImage = nil
                        pilot.gliderThumbnailImage = nil
                        if let gliderLicenseImage = pilot.gliderLicenseImage
                        {
                            temporaryContext.delete(gliderLicenseImage)
                        }
                        
                        pilot.powerThumbnailImage = nil
                        if let powerLicenseImage = pilot.powerLicenseImage
                        {
                            temporaryContext.delete(powerLicenseImage)
                        }
                    }
                }
                
                do
                {
                try temporaryContext.save()
                try psc.remove(store!)
                let store2 = try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName:nil, at:(backupPathURL), options:options as [NSObject : AnyObject])
                try psc.remove(store2)
                }
                catch {return}
                
                Pilot.changeShouldUpdateChangeTimesToValue(true)
            }
        }
        
        if moveToCloud
        {
            moveFileToiCloud(backupPathURL)
        }
            
        else
        {
            do {try manager.moveItem(atPath: uniqueStoragePath, toPath:sharingPath)}
            catch {return}
        }
    }
    
    func moveFileToiCloud(_ sourceURL: URL)
    {
        var destinationFileName = preferences["uniqueIdentifier"] as? String ?? ""
        destinationFileName = String(destinationFileName.prefix(6))
        let glidingCentreName = preferences["GlidingCentre"] as? String ?? ""
        destinationFileName += " \(Date().militaryFormatWithMinutes) \(glidingCentreName).sqlite"
        
        guard let ubiquityUrl = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.ca.cadets.Timesheets.Backups")?.appendingPathComponent("Documents") else {return}
        
        var destinationURL = ubiquityUrl.appendingPathComponent(destinationFileName)
        
        let fileManager = FileManager.default

        while fileManager.fileExists(atPath: destinationURL.path)
        {
            destinationURL = destinationURL.appendingPathComponent("2")
        }
        
        let success: Bool
        do
        {
            try fileManager.setUbiquitous(true, itemAt: sourceURL, destinationURL: destinationURL)
            success = true
        }
        
        catch
        {
            success = false
        }
        
        print("Source file: \(sourceURL)")
        print("Destination file: \(destinationURL)")
        mainQueue.async{
            if success
            {
                print("iCloud upload succeeded")
            }
        
            else
            {
                print("Couldn't move file to iCloud: \(sourceURL)")
            }
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        controller.presentingViewController?.dismiss(animated: true, completion: nil)
        picker = nil
        try! FileManager.default.removeItem(atPath: attachmentPath!)
        attachmentPath = nil
    }
    
    //MARK: - iBeaconManager Delegate
    
    func landAircraftWithBeacon(_ aircraftBeaconNumber: Int16)
    {
        aircraftAreaController?.landAircraftWithBeacon(aircraftBeaconNumber)
    }
    
    func updateAircraftWithBeacon(_ aircraftBeaconNumber: Int16)
    {
        aircraftAreaController?.updateAircraftWithBeacon(aircraftBeaconNumber)
    }
    
    //MARK: - Change Gliding Centre Delegate
    func glidingCentreSelected(_ GlidingCentreName: String)
    {
        updateGlidingCentreButton(GlidingCentreName)
    }
    
    //MARK: - Other
    func presentController(_ controller: UIViewController)
    {
        guard let rootController = ((UIApplication.shared.delegate as? TimesheetsAppDelegate)?.window?.rootViewController) else {return}
        
        if let presentedController = rootController.presentedViewController
        {
            presentedController.present(controller, animated:true, completion:nil)
        }
            
        else
        {
            rootController.present(controller, animated:true, completion:nil)
        }
    }
    
    func reloadAircraftAtIndexPath(_ path: IndexPath)
    {
        aircraftAreaController?.tableView.reloadRows(at: [path], with: .fade)
    }
    
    func checkForRegionChanges()
    {
        let regionNameFromPreferencesApp = UserDefaults.standard.string(forKey: "Region") ?? ""
        
        if regionNameFromPreferencesApp != regionName
        {
            regionName = regionNameFromPreferencesApp
            UserDefaults().lastRunDate = Date.distantPast
            reloadFetchedResults(nil)
            GPS.initializeAerodromeList()
            
            if CLLocationManager.locationServicesEnabled()
            {
                GPS.updateGlidingCentre()
            }
            
            NotificationCenter.default.post(name: regionChangedNotification, object:self, userInfo:nil)
        }
        
        cloudKitController?.regionName = regionNameFromPreferencesApp
    }
    
    func stopTimer()
    {
        aircraftInTheAirRefreshTimer?.invalidate()
    }
    
    func startTimer()
    {
        stopTimer()
        
        if let controller = aircraftAreaController
        {
            let currentMinute = Date().floorToMinute
            let timerStart = currentMinute + 61
            aircraftInTheAirRefreshTimer = Timer(fireAt: timerStart, interval:60, target: controller, selector: #selector(Airplanes.updateFlightTimes), userInfo: nil, repeats: true)

            aircraftInTheAirRefreshTimer?.tolerance = 10
            let currentLoop = RunLoop.current
            currentLoop.add(aircraftInTheAirRefreshTimer!, forMode:RunLoop.Mode.default)
        }
    }
    
    func closeOpenAttendanceRecordsFromPreviousDays()
    {
        let request = AttendanceRecord.request
        request.predicate = NSPredicate(format: "timeIn < %@ AND timeOut > %@", argumentArray: [Date().midnight, Date()])        //only open records have a sign out time after the present
        if let openRecords = try? managedObjectContext.fetch(request)
        {
            for record in openRecords
            {
                let signInDayAtMidnight = record.timeIn.midnight
                let signInDayAt1730 = signInDayAtMidnight + (60*60*17.5)
                record.timeOut = signInDayAt1730
                if record.timeIn > record.timeOut
                {
                    record.timeOut = record.timeIn + (60*60*3)
                }
                
                if (record.timeOut - record.timeIn) > Double(MAX_LENGTH_OF_CREW_SESSION)
                {
                    record.dayOrSession = true
                }
                
                if record.pilot?.signedIn == true
                {
                    record.pilot?.signedIn.toggle()
                }
                
                if let aircraftpilot = record.pilot?.aircraft?.pilot, aircraftpilot === record.pilot
                {
                    record.pilot?.aircraft?.pilot = nil
                }
                    
                else
                {
                    record.pilot?.aircraft?.passenger = nil
                }
            }
        }
    }

    func checkForMajorPreferencesChanges()
    {
        let defaults = UserDefaults.standard
        defaults.synchronize()
        let trainingStateFromPreferencesApp = defaults.bool(forKey: "Training Mode")
        
        let iBeaconAssistance = defaults.bool(forKey: "iBeacon Assistance")
        if beaconManager.iBeaconAssistance != iBeaconAssistance
        {
            if iBeaconAssistance
            {
                beaconManager = iBeaconManager()
                beaconManager.delegate = self
                beaconManager.beginMonitoringForBeacons()
            }
            
            else
            {
                beaconManager.endMonitoringForBeacons()
                beaconManager = iBeaconManager()
                beaconManager.delegate = self
                beaconManager.beginMonitoringForBeacons()
            }
        }
        
        switch (trainingStateFromPreferencesApp, trainingMode)
        {
        case (true, false):
            trainingMode = true
            UIApplication.shared.delegate!.window??.tintColor = UIColor.red
            aircraftAreaController?.navigationController?.navigationBar.tintColor = UIColor.red
            pilotAreaController?.navigationController?.navigationBar.tintColor = UIColor.red
            recordAreaController?.navigationController?.navigationBar.tintColor = UIColor.red
            
            if let parentController = aircraftAreaController?.parent as? iPadRootViewController
            {
                parentController.leftBar?.tintColor = UIColor.red
                parentController.rightBar?.tintColor = UIColor.red
                parentController.sortMethod?.tintColor = UIColor.red
            }

        case (false, true):
            trainingMode = false
            UIApplication.shared.delegate!.window??.tintColor = globalTintColor
            aircraftAreaController?.navigationController?.navigationBar.tintColor = nil
            pilotAreaController?.navigationController?.navigationBar.tintColor = nil
            recordAreaController?.navigationController?.navigationBar.tintColor = nil
            managedObjectContext.rollback()
            
            if let parentController = aircraftAreaController?.parent as? iPadRootViewController
            {
                parentController.leftBar?.tintColor = nil
                parentController.rightBar?.tintColor = nil
                parentController.sortMethod?.tintColor = UIColor(red: 16/255, green: 75/255, blue: 248/255, alpha: 1)
            }
            
        default:
            break
        }
    }
    
    func HTMLtoPDFDidFail(_ htmlToPDF: NDHTMLtoPDF)
    {
        return
    }
    
    fileprivate func getGlidingCenterNameToUse() -> String {
        let extractedExpr: GlidingCentre? = (regularFormat && viewPreviousRecords) ? previousRecordsGlidingCentre! : glidingCentre
        return extractedExpr?.name ?? "Unknown Gliding Center"
    }

    func canSendMail() -> Bool
    {
        return MFMailComposeViewController.canSendMail()
    }
    
    func checkIfCanSendMailAndAlertUserIfNot() -> Bool
    {
        let canSendMail = MFMailComposeViewController.canSendMail()
        if !canSendMail
        {
            let cantSendMailAlert = UIAlertController(title: "Can't Send Mail", message: "You cannot view this report until you set up mail in the settings app.", preferredStyle: .alert)
            let OKbutton = UIAlertAction(title: "OK", style: .default, handler:nil)
            cantSendMailAlert.addAction(OKbutton)
            presentController(cantSendMailAlert)
        }
        return canSendMail
    }
    
    func emailPTRs()
    {
        guard checkIfCanSendMailAndAlertUserIfNot() else {return}
        
        let generator = ReportGenerator()
        let GC = (regularFormat && viewPreviousRecords) ? previousRecordsGlidingCentre! : glidingCentre
        
        generator.unit = GC?.name
        generator.regionName = UserDefaults.standard.string(forKey: "Region")?.uppercased()
        
        let tableText = generator.generatePTRreport()
        let pathArray = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let path = pathArray.first?.stringByAppendingPathComponent("Timesheets.html") ?? ""
        
        picker = MFMailComposeViewController()
        picker?.mailComposeDelegate = self
        
        let today = Date()
        let todayDate = today.militaryFormatLong
        let subjectLine = "\(todayDate) \(GC!.name) PTR Report"
        
        picker?.setSubject(subjectLine)
        
        // Attach an image to the email.
        let attachmentName = "\(todayDate)-\(GC!.name)-PTR-Report.html"
        let myData = try? Data(contentsOf: URL(fileURLWithPath: path))
        attachmentPath = path
        picker?.addAttachmentData(myData!, mimeType: "text/html", fileName: attachmentName)
        picker?.setMessageBody(tableText, isHTML: true)

        if regularFormat
        {
            let controller = aircraftAreaController?.parent
            controller?.dismiss(animated: true, completion:nil)
            controller?.present(picker!, animated:true, completion: nil)
        }
            
        else
        {
            UIViewController.presentOnTopmostViewController(picker!)
        }
    }
    
    func performSetup()
    {
        configureFlightCounters()
                
        glidingUnit?.title = "???"

        let lastRunDate = UserDefaults().lastRunDate
        let gc = preferences["GlidingCentre"] as? String ?? ""
        updateGlidingCentreButton(gc)

        if !lastRunDate.isDateInToday
        {
            UserDefaults().lastRunDate = Date()
            self.closeOpenAttendanceRecordsFromPreviousDays()
            self.saveContext()
        }
    
        var ID: UUID
        
        if let uniqueIdentifier = preferences["uniqueIdentifier"] as? String
        {
            ID = UUID(uuidString: uniqueIdentifier)!
        }
        
        else
        {
            ID = UUID()
            preferences["uniqueIdentifier"] = ID.uuidString as NSString
            save()
        }
        
        reloadRecords()
        configureFlightCounters()
        pilotAreaController?.tableView.reloadData()
        
        if !registeredAsObserver
        {
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadFetchedResults), name: refreshEverythingNotification, object: UIApplication.shared.delegate)
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateApacheAndBandit), name: updateFlightCountersNotification, object: nil)
            registeredAsObserver = true
        }
        
        startTimer()
    }
    
    func setCurrentTimesheetForAircraft(_ aircraft: AircraftEntity, possibleContext: NSManagedObjectContext?)
    {
        let context = possibleContext ?? managedObjectContext
        
        let request = AircraftTimesheet.request
        request.predicate = NSPredicate(format: "aircraft == %@", aircraft)
        let dateSortDescriptor = NSSortDescriptor(key: #keyPath(AircraftTimesheet.date), ascending: true)
        request.sortDescriptors = [dateSortDescriptor]
        if let records = try? context.fetch(request), records.count > 0
        {
            aircraft.currentTimesheet = records.last
        }
        
        else
        {
            let _ = aircraft.insertNewTimeSheetForAircraft(withContext: context)
        }
    }
    
    func becomeActive()
    {
        let lastRunDate = UserDefaults().lastRunDate

        if lastRunDate.isDateInToday
        {
            aircraftAreaController?.updateFlightTimes()
            aircraftAreaController?.tableView.reloadRows(at: aircraftAreaController?.tableView.indexPathsForVisibleRows ?? [IndexPath](), with: .none)
            pilotAreaController?.tableView.reloadRows(at: pilotAreaController?.tableView.indexPathsForVisibleRows ?? [IndexPath](), with: .none)
            recordAreaController?.tableView.reloadRows(at: (recordAreaController?.tableView.indexPathsForVisibleRows ?? [IndexPath]()), with: .none)
        }
        
        else
        {
            UserDefaults().lastRunDate = Date()
            closeOpenAttendanceRecordsFromPreviousDays()
            saveContext()
            pilotAreaController?.reloadEverything()
            recordAreaController?.reloadData()
            aircraftAreaController?.reloadData()
            configureFlightCounters()
        }
        
        if registeredAsObserver == false
        {
            NotificationCenter.default.addObserver(forName: refreshEverythingNotification, object: UIApplication.shared.delegate, queue: OperationQueue.main, using: {[unowned self] note in self.reloadFetchedResults(note)})
            NotificationCenter.default.addObserver(forName: updateFlightCountersNotification, object: nil, queue: OperationQueue.main, using: {[unowned self] _ in self.updateApacheAndBandit()})
            registeredAsObserver = true
        }
        
        startTimer()
        beaconManager.beginMonitoringForBeacons()
    }
    
    //MARK: - Aircraft Delegate
    @objc func updateApacheAndBandit()
    {
        let apacheNumber = apacheController?.fetchedObjects?.count ?? 0
        let banditNumber = banditController?.fetchedObjects?.count ?? 0
        let totalNumber = totalController?.fetchedObjects?.count ?? 0
        var unflownCadetNumber = 0
        
        if unflownCadetsController?.fetchedObjects != nil
        {
            for record in unflownCadetsController!.fetchedObjects!
            {
                let targetDateDualFlightsArray = record.pilot.sortedDualFlights
                if targetDateDualFlightsArray.count == 0
                {
                    unflownCadetNumber += 1
                }
                    
                else
                {
                    let mostRecentFlight = targetDateDualFlightsArray.last!
                    if mostRecentFlight.timeUp < Date().midnight
                    {
                        unflownCadetNumber += 1
                    }
                }
            }
        }
        
        apacheTally?.text = "Apache: \(apacheNumber)"
        banditTally?.text = "Bandit: \(banditNumber)"
        totalTally?.text = "Glider Flights: \(totalNumber)"
        todayUnflownCadetsTally?.text = "Cadets to Fly: \(unflownCadetNumber)"
        
        apacheTally?.isHidden = (apacheNumber == 0) ? true : false
        banditTally?.isHidden = (banditNumber == 0) ? true : false
        totalTally?.isHidden = (totalNumber == 0) ? true : false
        todayUnflownCadetsTally?.isHidden = (unflownCadetNumber == 0) ? true : false
        
        if viewPreviousRecords
        {
            statsManager.updateKVSwithTotalNumberOfGliderFlight()
        }
        
        else
        {
            statsManager.updateKVSwithTotalNumberOfGliderFlight(totalNumber)
        }
    }

    func getGlidingCentre(forName glidingCentreName : String) -> GlidingCentre
    {
        return getGlidingCentre(forName : glidingCentreName, using : managedObjectContext)
    }

    func getGlidingCentre(forName glidingCentreName : String, using context : NSManagedObjectContext) -> GlidingCentre
    {
        if glidingCentreName != ""
        {
            let request = GlidingCentre.request
            request.predicate = NSPredicate(format: "name = %@", argumentArray: [glidingCentreName])
            let gcs = try! context.fetch(request)

            var glidingCentre = gcs.first as GlidingCentre?
            if glidingCentre == nil
            {
                glidingCentre = GlidingCentre(context: context)
                glidingCentre!.name = glidingCentreName
            }
            return glidingCentre!
        }

        return getFirstGlidingCentre(using : context)
    }

    func getFirstGlidingCentre(using context : NSManagedObjectContext) -> GlidingCentre
    {
        let request = GlidingCentre.request
        request.sortDescriptors = [NSSortDescriptor(key:"name", ascending: true)]
        let gcs = try! context.fetch(request)

        return gcs.first! as GlidingCentre
    }

    func getGlidingCentres() -> [GlidingCentre]
    {
        let request = GlidingCentre.request
        return try! managedObjectContext.fetch(request)
    }

    //MARK: - Object Lifecycle
    deinit
    {
        aircraftInTheAirRefreshTimer?.invalidate()
    }
}

