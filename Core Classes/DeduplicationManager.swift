//
//  DeduplicationManager.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-23.
//
//

import Foundation
import UIKit
import CoreData

extension TimesheetsDataModel
{
    func deduplicateDatabase(withProgressViewer progressViewer: DeduplicateProgressViewController, onContext context:NSManagedObjectContext, withTempStore tempStore: NSPersistentStore, andMainStore mainStore: NSPersistentStore)
    {
        let fetchBatchSize = 0
        
        let tempRegionRequest = Region.request
        tempRegionRequest.affectedStores = [tempStore]
        let regionList = try! context.fetch(tempRegionRequest)
        let mainStoreRegionRequest = Region.request
        mainStoreRegionRequest.affectedStores = [mainStore]
        let mainStoreGcRequest = GlidingCentre.request
        mainStoreGcRequest.affectedStores = [mainStore]
        let mainStoreAircraftRequest = AircraftEntity.request
        mainStoreAircraftRequest.affectedStores = [mainStore]
        let mainStorePilotRequest = Pilot.request
        mainStorePilotRequest.affectedStores = [mainStore]
        let mainStoreSummerUnitRequest = SummerUnit.request
        mainStoreSummerUnitRequest.affectedStores = [mainStore]
        let mainStoreTimesheetRequest = AircraftTimesheet.request
        mainStoreTimesheetRequest.affectedStores = [mainStore]
        let mainStoreMaintenanceEventRequest = MaintenanceEvent.request
        mainStoreMaintenanceEventRequest.affectedStores = [mainStore]
        let mainStoreQualRequest = Qualification.request
        mainStoreQualRequest.affectedStores = [mainStore]
        let mainStoreFlightRecordRequest = FlightRecord.request
        mainStoreFlightRecordRequest.affectedStores = [mainStore]
        let mainStoreAttendanceRequest = AttendanceRecord.request
        mainStoreAttendanceRequest.affectedStores = [mainStore]

        let numberOfRegionsToAnalyze = Float(regionList.count)
        var numberOfRecordsAnalyzed = 0 as Float

        func saveIfNecessary()
        {
            if remainder(numberOfRecordsAnalyzed, 500) == 0
            {
                try! context.save()
            }
        }
        
        func setGCfor<T : AttachedToGlidingUnit>(_ object: inout T, toMatchTempGC tempGC: GlidingCentre)
        {
            mainStoreGcRequest.predicate = NSPredicate(format: "name == %@", tempGC.name)
            let matchingGCs = try! context.fetch(mainStoreGcRequest)
            
            if let matchedGC = matchingGCs.first, matchingGCs.count == 1
            {
                object.glidingCentre = matchedGC
            }
                
            else
            {
                print("There should be exactly one \(type(of: tempGC)) with name \(tempGC.name) in the database, somehow there are \(matchingGCs.count)")
            }
            
            mainStoreGcRequest.predicate = nil
        }
        
        func setAircraftFor<T : AttachedToAircraft>(_ object: inout T, toMatch tempAircraft: AircraftEntity)
        {
            mainStoreAircraftRequest.predicate = NSPredicate(format: "registration == %@", tempAircraft.registration)
            let matchingAircraft = try! context.fetch(mainStoreAircraftRequest)
            
            if let matchedAircraft = matchingAircraft.first, matchingAircraft.count == 1
            {
                object.aircraft = matchedAircraft
            }
                
            else
            {
                print("There should be exactly one aircraft with registration \(tempAircraft.registration), somehow there are \(matchingAircraft.count)")
            }
            
            mainStoreAircraftRequest.predicate = nil
        }
        
        func setPilotFor<T : AttachedToPilot>(_ object: inout T, toMatch tempPilot: Pilot)
        {
            mainStorePilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempPilot.recordID])
            let matchingPilots = try! context.fetch(mainStorePilotRequest)
            
            if let matchedPilot = matchingPilots.first, matchingPilots.count == 1
            {
                object.pilot = matchedPilot
            }
                
            else
            {
                print("There should be exactly one pilot with a given recordID in the database. Somehow a pilot named \(tempPilot.name) has \(matchingPilots.count)")
            }
            
            mainStorePilotRequest.predicate = nil
        }
        
        func setPassengerFor<T : AttachedToPassenger>(_ object: inout T, toMatch tempPilot: Pilot)
        {
            mainStorePilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempPilot.recordID])
            let matchingPilots = try! context.fetch(mainStorePilotRequest)
            
            if let matchedPilot = matchingPilots.first, matchingPilots.count == 1
            {
                object.passenger = matchedPilot
            }
                
            else
            {
                print("There should be exactly one pilot with a given recordID in the database. Somehow a pilot named \(tempPilot.name) has \(matchingPilots.count)")
            }
            
            mainStorePilotRequest.predicate = nil
        }
        
        func setSummerUnitFor<T : AttachedToSummerUnit>(_ object: inout T, toMatch tempUnit: SummerUnit)
        {
            mainStoreSummerUnitRequest.predicate = NSPredicate(format: "name == %@", tempUnit.name)
            let matchingUnits = try! context.fetch(mainStoreSummerUnitRequest)
            
            if let matchedUnit = matchingUnits.first, matchingUnits.count == 1
            {
                object.summerUnit = matchedUnit
            }
                
            else
            {
                print("There should be exactly one summer unit with name \(tempUnit.name) in the database, somehow there are \(matchingUnits.count)")
            }
            
            mainStoreSummerUnitRequest.predicate = nil
        }
        
        func setTimesheetFor<T : AttachedToTimesheet>(_ object: inout T, toMatch tempTimesheet: AircraftTimesheet)
        {
            mainStoreTimesheetRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempTimesheet.recordID])
            let matchingTimesheets = try! context.fetch(mainStoreTimesheetRequest)
            
            if let matchedTimesheet = matchingTimesheets.first, matchingTimesheets.count == 1
            {
                object.timesheet = matchedTimesheet
            }
                
            else
            {
                print("There should be exactly one timesheet with a particular recordID")
            }
            
            mainStoreTimesheetRequest.predicate = nil
        }
        
        func setConnectedRecordFor(_ record: inout FlightRecord, toMatch recordID: Date)
        {
            mainStoreFlightRecordRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [recordID])
            let matchingRecords = try! context.fetch(mainStoreFlightRecordRequest)
            
            if let matchedRecord = matchingRecords.first, matchingRecords.count == 1
            {
                record.connectedAircraftRecord = matchedRecord
            }
                
            else if matchingRecords.count > 1
            {
                print("There should be exactly one timesheet with a particular recordID")
            }
            
            mainStoreFlightRecordRequest.predicate = nil
        }
        
        for region in regionList
        {
            mainStoreRegionRequest.predicate = NSPredicate(format: "name == %@", region.name)
            let matchingRegions = try! context.fetch(mainStoreRegionRequest)

            if matchingRegions.count == 0
            {
                let copiedRegionOnMainContext = Region(context: context)
                context.assign(copiedRegionOnMainContext, to: mainStore)
                copiedRegionOnMainContext.name = region.name
            }
            
            numberOfRecordsAnalyzed += 1
            let fractionCompleted = numberOfRecordsAnalyzed / numberOfRegionsToAnalyze
            mainQueue.async{progressViewer.region.setProgress(fractionCompleted, animated: false)}
        }
        mainQueue.async{progressViewer.region.setProgress(1, animated: false)}

        autoreleasepool
        {
            let tempGcRequest = GlidingCentre.request
            tempGcRequest.affectedStores = [tempStore]
            let tempGcList = try! context.fetch(tempGcRequest)
            let numberOfGlidingCentresToAnalyze = Float(tempGcList.count)
            numberOfRecordsAnalyzed = 0

            for tempGC in tempGcList
            {
                mainStoreGcRequest.predicate = NSPredicate(format: "name == %@", tempGC.name)
                let matchingGCs = try! context.fetch(mainStoreGcRequest)

                if matchingGCs.count == 0
                {
                    let copiedGcOnMainContext = GlidingCentre(context: context)
                    context.assign(copiedGcOnMainContext, to: mainStore)
                    copiedGcOnMainContext.name = tempGC.name
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfGlidingCentresToAnalyze
                mainQueue.async{progressViewer.glidingCentre.setProgress(fractionCompleted, animated: false)}
            }
            mainQueue.async{progressViewer.glidingCentre.setProgress(1, animated: false)}

            try! context.save()
//            context.reset()
        }

        autoreleasepool
        {
            let tempGlidingDayCommentRequest = GlidingDayComment.request
            tempGlidingDayCommentRequest.affectedStores = [tempStore]
            tempGlidingDayCommentRequest.fetchBatchSize = fetchBatchSize
            let tempGlidingDayCommentList = try! context.fetch(tempGlidingDayCommentRequest)
            let mainStoreCommentRequest = GlidingDayComment.request
            mainStoreCommentRequest.affectedStores = [mainStore]
            let numberOfCommentsToAnalyze = Float(tempGlidingDayCommentList.count)
            numberOfRecordsAnalyzed = 0

            for tempComment in tempGlidingDayCommentList
            {
                mainStoreCommentRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempComment.recordID])
                let matchingComments = try! context.fetch(mainStoreCommentRequest)

                if matchingComments.count == 0
                {
                    var copiedCommentOnMainContext = GlidingDayComment(context: context)
                    context.assign(copiedCommentOnMainContext, to: mainStore)
                    copiedCommentOnMainContext.comment = tempComment.comment
                    copiedCommentOnMainContext.date = tempComment.date
                    copiedCommentOnMainContext.recordChangeTime = tempComment.recordChangeTime
                    copiedCommentOnMainContext.recordID = tempComment.recordID
                    guard let tempGC = tempComment.glidingCentre else {continue}
                    setGCfor(&copiedCommentOnMainContext, toMatchTempGC: tempGC)
                }

                else
                {
                    if let matchedMainStoreComment = matchingComments.first, matchingComments.count == 1
                    {
                        let (mostRecentVersionOfComment, _) = newerAndOlderRecord(tempComment, secondRecord: matchedMainStoreComment)

                        if mostRecentVersionOfComment === tempComment
                        {
                            matchedMainStoreComment.comment = tempComment.comment
                            matchedMainStoreComment.date = tempComment.date
                            matchedMainStoreComment.recordChangeTime = tempComment.recordChangeTime
                        }
                    }

                    else
                    {
                        print("There should be exactly one comment with a given ID in the database, instead there are \(matchingComments.count)")
                    }
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfCommentsToAnalyze
                mainQueue.async{progressViewer.glidingDayComments.setProgress(fractionCompleted, animated: false)}

                saveIfNecessary()
            }
            mainQueue.async{progressViewer.glidingDayComments.setProgress(1, animated: false)}

            try! context.save()
//            context.reset()
        }

        autoreleasepool
        {
            let tempSummerUnitRequest = SummerUnit.request
            tempSummerUnitRequest.affectedStores = [tempStore]
            let tempSummerUnitList = try! context.fetch(tempSummerUnitRequest)
            print("Initially there are \(try! context.count(for: mainStoreSummerUnitRequest)) summer camp flights")
            let numberOfSummerUnitsToAnalyze = Float(tempSummerUnitList.count)
            numberOfRecordsAnalyzed = 0

            for tempUnit in tempSummerUnitList
            {
                mainStoreSummerUnitRequest.predicate = NSPredicate(format: "name == %@", tempUnit.name)
                let matchingUnits = try! context.fetch(mainStoreSummerUnitRequest)

                if matchingUnits.count == 0
                {
                    let copiedUnitOnMainContext = SummerUnit(context: context)
                    context.assign(copiedUnitOnMainContext, to: mainStore)
                    copiedUnitOnMainContext.name = tempUnit.name
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfSummerUnitsToAnalyze
                mainQueue.async{progressViewer.summerUnits.setProgress(fractionCompleted, animated: false)}
            }
            mainQueue.async{progressViewer.summerUnits.setProgress(1, animated: false)}

            try! context.save()
//            context.reset()
        }

        autoreleasepool
        {
            let tempAircraftRequest = AircraftEntity.request
            tempAircraftRequest.affectedStores = [tempStore]
            let tempAircraftList = try! context.fetch(tempAircraftRequest)
            print("Initially there are \(try! context.count(for: mainStoreAircraftRequest)) aircraft")
            numberOfRecordsAnalyzed = 0
            let numberOfAircraftToAnalyze = Float(tempAircraftList.count)

            for tempAircraft in tempAircraftList
            {
                mainStoreAircraftRequest.predicate = NSPredicate(format: "registration == %@", tempAircraft.registration)
                let matchingAircraft = try! context.fetch(mainStoreAircraftRequest)

                if matchingAircraft.count == 0
                {
                    let copiedAircraftOnMainContext = AircraftEntity(context: context)
                    context.assign(copiedAircraftOnMainContext, to: mainStore)

                    copiedAircraftOnMainContext.beaconNumber = tempAircraft.beaconNumber
                    copiedAircraftOnMainContext.flightSequence = tempAircraft.flightSequence
                    copiedAircraftOnMainContext.gliderOrTowplane = tempAircraft.gliderOrTowplane
                    copiedAircraftOnMainContext.inTheAir = false
                    copiedAircraftOnMainContext.registration = tempAircraft.registration
                    copiedAircraftOnMainContext.tailNumber = tempAircraft.tailNumber
                    copiedAircraftOnMainContext.TTNI = tempAircraft.TTNI
                }

                else
                {
                    if let matchedMainStoreAircraft = matchingAircraft.first, matchingAircraft.count == 1
                    {
                        matchedMainStoreAircraft.passenger = nil
                        matchedMainStoreAircraft.pilot = nil
                        matchedMainStoreAircraft.currentRecord = nil
                        matchedMainStoreAircraft.connectedAircraft = nil
                        matchedMainStoreAircraft.glidingCentre = nil

                        if matchedMainStoreAircraft.TTNI < tempAircraft.TTNI
                        {
                            matchedMainStoreAircraft.TTNI = tempAircraft.TTNI
                        }
                    }

                    else
                    {
                        print("There should be exactly one aircraft with a given registration in the database, instead there are \(matchingAircraft.count)")
                    }
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfAircraftToAnalyze
                mainQueue.async{progressViewer.aircraft.setProgress(fractionCompleted, animated: false)}
            }
            mainQueue.async{progressViewer.aircraft.setProgress(1, animated: false)}

            try! context.save()
//            context.reset()
        }

        autoreleasepool
        {
            let tempMaintenanceRequest = MaintenanceEvent.request
            tempMaintenanceRequest.affectedStores = [tempStore]
            tempMaintenanceRequest.fetchBatchSize = fetchBatchSize
            let tempMaintenanceEventList = try! context.fetch(tempMaintenanceRequest)
            print("Initially there are \(try! context.count(for: mainStoreMaintenanceEventRequest)) maintenance items")
            numberOfRecordsAnalyzed = 0
            let numberOfMaintenanceEventsToAnalyze = Float(tempMaintenanceEventList.count)

            for tempEvent in tempMaintenanceEventList
            {
                mainStoreMaintenanceEventRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempEvent.recordID])
                let matchingEvents = try! context.fetch(mainStoreMaintenanceEventRequest)

                if matchingEvents.count == 0
                {
                    var copiedEventOnMainContext = MaintenanceEvent(context: context)
                    context.assign(copiedEventOnMainContext, to: mainStore)

                    copiedEventOnMainContext.comment = tempEvent.comment
                    copiedEventOnMainContext.date = tempEvent.date
                    copiedEventOnMainContext.recordChangeTime = tempEvent.recordChangeTime
                    copiedEventOnMainContext.recordID = tempEvent.recordID
                    copiedEventOnMainContext.ttsn = tempEvent.ttsn

                    if tempEvent.aircraft == nil
                    {
                        continue
                    }

                    setAircraftFor(&copiedEventOnMainContext, toMatch: tempEvent.aircraft)
                }

                else
                {
                    if let matchedMainStoreMaintenanceEvent = matchingEvents.first, matchingEvents.count == 1
                    {
                        let (mostRecentVersionOfEvent, _) = newerAndOlderRecord(tempEvent, secondRecord: matchedMainStoreMaintenanceEvent)

                        if mostRecentVersionOfEvent === tempEvent
                        {
                            matchedMainStoreMaintenanceEvent.comment = tempEvent.comment
                            matchedMainStoreMaintenanceEvent.date = tempEvent.date
                            matchedMainStoreMaintenanceEvent.recordChangeTime = tempEvent.recordChangeTime
                            matchedMainStoreMaintenanceEvent.recordID = tempEvent.recordID
                            matchedMainStoreMaintenanceEvent.ttsn = tempEvent.ttsn
                        }
                    }

                    else
                    {
                        print("There should be exactly one maintenance event with a given ID in the database, instead there are \(matchingEvents.count)")
                    }
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfMaintenanceEventsToAnalyze
                mainQueue.async{progressViewer.maintenanceEvents.setProgress(fractionCompleted, animated: false)}

                saveIfNecessary()
            }
            mainQueue.async{progressViewer.maintenanceEvents.setProgress(1, animated: false)}

            mainStoreMaintenanceEventRequest.predicate = nil
            try! context.save()
        }

        autoreleasepool
        {
            let tempPilotRequest = Pilot.request
            tempPilotRequest.affectedStores = [tempStore]
            tempPilotRequest.fetchBatchSize = fetchBatchSize
            let tempPilotList = try! context.fetch(tempPilotRequest)
            print("Initially there are \(try! context.count(for: mainStorePilotRequest)) pilots")
            let numberOfPilotsToAnalyze = Float(tempPilotList.count)
            numberOfRecordsAnalyzed = 0

            for tempPilot in tempPilotList
            {
                mainStorePilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempPilot.recordID])
                let matchingPilots = try! context.fetch(mainStorePilotRequest)

                if matchingPilots.count == 0
                {
                    var copiedPilotOnMainContext = Pilot(context: context)
                    context.assign(copiedPilotOnMainContext, to: mainStore)
                    copiedPilotOnMainContext.recordChangeTime = Date.distantPast
                    copiedPilotOnMainContext.mergeWithPilot(tempPilot, includingRelationships: false)
                    copiedPilotOnMainContext.recordChangeTime = tempPilot.recordChangeTime - 1

//                    if let image = tempPilot.photo
//                    {
//                        let copiedPhotoOnMainContext = Photo(context: context)
//                        context.assign(copiedPhotoOnMainContext, to: mainStore)
//                        copiedPhotoOnMainContext.pilot = copiedPilotOnMainContext
//                        copiedPhotoOnMainContext.image = image
//                    }

                    guard let tempGC = tempPilot.glidingCentre else {continue}
                    setGCfor(&copiedPilotOnMainContext, toMatchTempGC: tempGC)

                    if let tempSummerUnit = tempPilot.summerUnit
                    {
                        setSummerUnitFor(&copiedPilotOnMainContext, toMatch: tempSummerUnit)
                    }
                }

//                else
//                {
//                    if var matchedMainStorePilot = matchingPilots.first, matchingPilots.count == 1
//                    {
//                        if tempPilot.recordChangeTime >= matchedMainStorePilot.recordChangeTime && tempPilot.glidingCentre == nil
//                        {
//                            matchedMainStorePilot.clearRelationships()
//                            continue
//                        }
//
//                        matchedMainStorePilot.mergeWithPilot(tempPilot, includingRelationships: false)
//
//                        if newerAndOlderRecord(matchedMainStorePilot, secondRecord: tempPilot).newerRecord === tempPilot, let image = tempPilot.photo
//                        {
//                            let copiedPhotoOnMainContext = Photo(context: context)
//                            context.assign(copiedPhotoOnMainContext, to: mainStore)
//                            copiedPhotoOnMainContext.pilot = matchedMainStorePilot
//                            copiedPhotoOnMainContext.image = image
//
//                            setGCfor(&matchedMainStorePilot, toMatchTempGC: tempPilot.glidingCentre)
//                            matchedMainStorePilot.region = tempPilot.glidingCentre.region.name
//
//                            if let tempSummerUnit = tempPilot.summerUnit
//                            {
//                                setSummerUnitFor(&matchedMainStorePilot, toMatch: tempSummerUnit)
//                            }
//                        }
//                    }
//
//                    else
//                    {
//                        print("There should be exactly one pilot with a given ID in the database, instead there are \(matchingPilots.count)")
//                    }
//                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfPilotsToAnalyze
                mainQueue.async{progressViewer.pilots.setProgress(fractionCompleted, animated: false)}
                saveIfNecessary()
            }
            mainQueue.async{progressViewer.pilots.setProgress(1, animated: false)}

            do
            {
                try context.save()
            }

            catch let error as NSError
            {
                print("\(error.localizedDescription)")
            }
        }

        autoreleasepool
        {
            let tempQualRequest = Qualification.request
            tempQualRequest.affectedStores = [tempStore]
            let tempQualList = try! context.fetch(tempQualRequest)
            print("Initially there are \(try! context.count(for: mainStoreQualRequest)) quals")
            numberOfRecordsAnalyzed = 0
            let numberOfQualsToAnalyze = Float(tempQualList.count)

            for tempQual in tempQualList
            {
                mainStoreQualRequest.predicate = NSPredicate(format: "nameOfQualification == %@", tempQual.nameOfQualification)
                let matchingQuals = try! context.fetch(mainStoreQualRequest)

                if matchingQuals.count == 0
                {
                    let copiedQualOnMainContext = Qualification(context: context)
                    context.assign(copiedQualOnMainContext, to: mainStore)
                    copiedQualOnMainContext.nameOfQualification = tempQual.nameOfQualification

                    for tempPilot in tempQual.pilotsWhoHaveIt
                    {
                        mainStorePilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempPilot.recordID])
                        let matchingPilots = try! context.fetch(mainStorePilotRequest)

                        if let matchedPilot = matchingPilots.first, matchingPilots.count == 1
                        {
                            if newerAndOlderRecord(matchedPilot, secondRecord: tempPilot).newerRecord === tempPilot
                            {
                                var pilotsWithQual = copiedQualOnMainContext.pilotsWhoHaveIt
                                pilotsWithQual.insert(matchedPilot)
                                copiedQualOnMainContext.pilotsWhoHaveIt = pilotsWithQual
                            }
                        }

                        else
                        {
                            print("There should be exactly one pilot with a given recordID in the database")
                        }
                    }
                }

                else
                {
                    if let mainStoreQual = matchingQuals.first
                    {
                        for tempPilot in tempQual.pilotsWhoHaveIt
                        {
                            mainStorePilotRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempPilot.recordID])
                            let matchingPilots = try! context.fetch(mainStorePilotRequest)

                            if let matchedPilot = matchingPilots.first, matchingPilots.count == 1
                            {
                                if newerAndOlderRecord(matchedPilot, secondRecord: tempPilot).newerRecord === tempPilot
                                {
                                    var pilotsWithQual = mainStoreQual.pilotsWhoHaveIt
                                    pilotsWithQual.insert(matchedPilot)
                                    mainStoreQual.pilotsWhoHaveIt = pilotsWithQual
                                }
                            }

                            else
                            {
                                print("There should be exactly one pilot with a given recordID in the database")
                            }
                        }
                    }
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfQualsToAnalyze
                mainQueue.async{progressViewer.quals.setProgress(fractionCompleted, animated: false)}
            }
            mainQueue.async{progressViewer.quals.setProgress(1, animated: false)}

            mainStoreQualRequest.predicate = nil
            try! context.save()
//            context.reset()
        }

        autoreleasepool
        {
            let tempStoreAttendanceRequest = AttendanceRecord.request
            tempStoreAttendanceRequest.affectedStores = [tempStore]
            tempStoreAttendanceRequest.fetchBatchSize = fetchBatchSize
            let tempStoreAttendanceRecordList = try! context.fetch(tempStoreAttendanceRequest)
            print("Initially there are \(try! context.count(for: mainStoreAttendanceRequest)) attendance records")
            let numberOfAttendanceRecordsToAnalyze = Float(tempStoreAttendanceRecordList.count)
            numberOfRecordsAnalyzed = 0

            for tempAttendanceRecord in tempStoreAttendanceRecordList
            {
                if tempAttendanceRecord.pilot == nil
                {
                    continue
                }

                mainStoreAttendanceRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempAttendanceRecord.recordID])
                let matchingAttendanceRecords = try! context.fetch(mainStoreAttendanceRequest)

                if matchingAttendanceRecords.count == 0
                {
                    var copiedAttendanceRecordOnMainContext = AttendanceRecord(context: context)
                    context.assign(copiedAttendanceRecordOnMainContext, to: mainStore)

                    copiedAttendanceRecordOnMainContext.dayOrSession = tempAttendanceRecord.dayOrSession
                    copiedAttendanceRecordOnMainContext.participantType = tempAttendanceRecord.participantType
                    copiedAttendanceRecordOnMainContext.recordChangeTime = tempAttendanceRecord.recordChangeTime
                    copiedAttendanceRecordOnMainContext.recordID = tempAttendanceRecord.recordID
                    copiedAttendanceRecordOnMainContext.timeIn = tempAttendanceRecord.timeIn
                    copiedAttendanceRecordOnMainContext.timeOut = tempAttendanceRecord.timeOut

                    guard let tempGC = tempAttendanceRecord.glidingCentre else {continue}
                    setGCfor(&copiedAttendanceRecordOnMainContext, toMatchTempGC: tempGC)
                    setPilotFor(&copiedAttendanceRecordOnMainContext, toMatch: tempAttendanceRecord.pilot)
                }

                else
                {
                    if let matchedMainStoreAttendanceRecord = matchingAttendanceRecords.first, matchingAttendanceRecords.count == 1
                    {
                        if newerAndOlderRecord(matchedMainStoreAttendanceRecord, secondRecord: tempAttendanceRecord).newerRecord === tempAttendanceRecord
                        {
                            matchedMainStoreAttendanceRecord.dayOrSession = tempAttendanceRecord.dayOrSession
                            matchedMainStoreAttendanceRecord.participantType = tempAttendanceRecord.participantType
                            matchedMainStoreAttendanceRecord.recordChangeTime = tempAttendanceRecord.recordChangeTime
                            matchedMainStoreAttendanceRecord.recordID = tempAttendanceRecord.recordID
                            matchedMainStoreAttendanceRecord.timeIn = tempAttendanceRecord.timeIn
                            matchedMainStoreAttendanceRecord.timeOut = tempAttendanceRecord.timeOut

                            if tempAttendanceRecord.glidingCentre == nil
                            {
                                matchedMainStoreAttendanceRecord.clearRelationships()
                            }
                        }
                    }

                    else
                    {
                        print("There should be exactly one attendance record with a given ID in the database, instead there are \(matchingAttendanceRecords.count)")
                    }
                }

                numberOfRecordsAnalyzed += 1
                let fractionCompleted = numberOfRecordsAnalyzed / numberOfAttendanceRecordsToAnalyze
                mainQueue.async{progressViewer.attendance.setProgress(fractionCompleted, animated: false)}
                saveIfNecessary()
            }
            mainQueue.async{progressViewer.attendance.setProgress(1, animated: false)}

            mainStoreAttendanceRequest.predicate = nil
            try! context.save()
//            context.reset()
        }
        
        autoreleasepool
        {
            let tempTimesheetRequest = AircraftTimesheet.request
            tempTimesheetRequest.affectedStores = [tempStore]
            tempTimesheetRequest.fetchBatchSize = fetchBatchSize
            let tempTimesheetList = try! context.fetch(tempTimesheetRequest)
            print("Initially there are \(try! context.count(for: mainStoreTimesheetRequest)) timesheets")
            let numberOfTimesheetsToAnalyze = Float(tempTimesheetList.count)
            numberOfRecordsAnalyzed = 0
            
            for tempTimesheet in tempTimesheetList
            {
                mainStoreTimesheetRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempTimesheet.recordID])
                let matchingTimesheets = try! context.fetch(mainStoreTimesheetRequest)
                
                if matchingTimesheets.count == 0
                {
                    var copiedTimesheetOnMainContext = AircraftTimesheet(context: context)
                    context.assign(copiedTimesheetOnMainContext, to: mainStore)
                    
                    copiedTimesheetOnMainContext.date = tempTimesheet.date
                    copiedTimesheetOnMainContext.TTSNfinal = tempTimesheet.TTSNfinal
                    copiedTimesheetOnMainContext.TTSNinitial = tempTimesheet.TTSNinitial
                    copiedTimesheetOnMainContext.recordChangeTime = tempTimesheet.recordChangeTime
                    copiedTimesheetOnMainContext.recordID = tempTimesheet.recordID
                    copiedTimesheetOnMainContext.winchFinalTTSNsetCorrectly = tempTimesheet.winchFinalTTSNsetCorrectly

                    guard let tempGC = tempTimesheet.glidingCentre else {continue}
                    setGCfor(&copiedTimesheetOnMainContext, toMatchTempGC: tempGC)
                    setAircraftFor(&copiedTimesheetOnMainContext, toMatch: tempTimesheet.aircraft)
                }
                
                else
                {
                    if var matchedMainStoreTimesheet = matchingTimesheets.first, matchingTimesheets.count == 1
                    {
                        if newerAndOlderRecord(matchedMainStoreTimesheet, secondRecord: tempTimesheet).newerRecord === tempTimesheet
                        {
                            matchedMainStoreTimesheet.date = tempTimesheet.date
                            matchedMainStoreTimesheet.TTSNfinal = tempTimesheet.TTSNfinal
                            matchedMainStoreTimesheet.TTSNinitial = tempTimesheet.TTSNinitial
                            matchedMainStoreTimesheet.recordChangeTime = tempTimesheet.recordChangeTime
                            matchedMainStoreTimesheet.recordID = tempTimesheet.recordID
                            matchedMainStoreTimesheet.winchFinalTTSNsetCorrectly = tempTimesheet.winchFinalTTSNsetCorrectly
                            
                            if tempTimesheet.glidingCentre == nil
                            {
                                matchedMainStoreTimesheet.clearRelationships()
                            }
                            
                            else
                            {
                                if matchedMainStoreTimesheet.glidingCentre == nil || matchedMainStoreTimesheet.glidingCentre.name != tempTimesheet.glidingCentre.name
                                {
                                    setGCfor(&matchedMainStoreTimesheet, toMatchTempGC: tempTimesheet.glidingCentre)
                                }
                                
                                if matchedMainStoreTimesheet.aircraft == nil || tempTimesheet.aircraft.registration != matchedMainStoreTimesheet.aircraft.registration
                                {
                                    setAircraftFor(&matchedMainStoreTimesheet, toMatch: tempTimesheet.aircraft)
                                }
                            }
                        }
                    }
                        
                    else
                    {
                        print("There should be exactly one timesheet with a given ID in the database, instead there are \(matchingTimesheets.count)")
                    }
                }
                    
                numberOfRecordsAnalyzed += 1
                let fractionCompleted = (numberOfRecordsAnalyzed / numberOfTimesheetsToAnalyze)
                mainQueue.async{progressViewer.timesheets.setProgress(fractionCompleted, animated: false)}
                saveIfNecessary()
            }
            mainQueue.async{progressViewer.timesheets.setProgress(1, animated: false)}

            try! context.save()
//            context.reset()
        }

        let modifiedRecords = [(tempRecord: FlightRecord, mainStoreRecord: FlightRecord)]()
        
        autoreleasepool
        {
            let tempFlightRecordRequest = FlightRecord.request
            tempFlightRecordRequest.affectedStores = [tempStore]
            tempFlightRecordRequest.fetchBatchSize = fetchBatchSize
            
            
            
            
            let tempFlightRecordList = try! context.fetch(tempFlightRecordRequest)

            
            
            print("Initially there are \(try! context.count(for: mainStoreFlightRecordRequest)) flight records")
            let numberOfFlightRecordsToAnalyze = Float(tempFlightRecordList.count)
            numberOfRecordsAnalyzed = 0
            
            for tempFlightRecord in tempFlightRecordList
            {
                mainStoreFlightRecordRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempFlightRecord.recordID])
                let matchingFlightRecords = try! context.fetch(mainStoreFlightRecordRequest)
                
//                let connectedRecordID = tempFlightRecord.connectedAircraftRecord?.recordID
                
                
//                if let connected = tempFlightRecord.connectedAircraftRecord
//                {
//                    
//                    
//                    print("The record is \(tempFlightRecord.timeUp)")
//                    print("The defective record is \(connected.timeUp)")
//                    
//                    
//                    print("The defective record is \(connected.pilot?.fullName)")
//
//                    
//                    print("The defective record is \(connected)")
//                    print("The defective record is \(connected.aircraft)")
//                    print("The defective record is \(connected.aircraft.tailNumber)")
//                    
//                    
//                    print("The record ID should be \(connected.recordID)")
//                }
                
                
                
                
                if matchingFlightRecords.count == 0
                {
                    var copiedFlightRecordOnMainContext = FlightRecord(context: context)
                    context.assign(copiedFlightRecordOnMainContext, to: mainStore)
//                    modifiedRecords.append((tempRecord: tempFlightRecord, mainStoreRecord: copiedFlightRecordOnMainContext))
                    
                    copiedFlightRecordOnMainContext.dualParticipantType = tempFlightRecord.dualParticipantType
                    copiedFlightRecordOnMainContext.flightLengthInMinutes = tempFlightRecord.flightLengthInMinutes
                    copiedFlightRecordOnMainContext.flightSequence = tempFlightRecord.flightSequence
                    copiedFlightRecordOnMainContext.picParticipantType = tempFlightRecord.picParticipantType
                    copiedFlightRecordOnMainContext.recordChangeTime = tempFlightRecord.recordChangeTime
                    copiedFlightRecordOnMainContext.recordID = tempFlightRecord.recordID
                    copiedFlightRecordOnMainContext.timeDown = tempFlightRecord.timeDown
                    copiedFlightRecordOnMainContext.timeUp = tempFlightRecord.timeUp
                    copiedFlightRecordOnMainContext.transitRoute = tempFlightRecord.transitRoute
                    
                    if tempFlightRecord.timesheet == nil
                    {
                        continue
                    }
                    setPilotFor(&copiedFlightRecordOnMainContext, toMatch: tempFlightRecord.pilot)
                    
                    if let passenger = tempFlightRecord.passenger
                    {
                        setPassengerFor(&copiedFlightRecordOnMainContext, toMatch: passenger)
                    }
                    
                    if let _ = tempFlightRecord.connectedAircraftRecord?.pilot
                    {
                        setConnectedRecordFor(&copiedFlightRecordOnMainContext, toMatch: tempFlightRecord.connectedAircraftRecord!.recordID)
                    }
                    
                    setTimesheetFor(&copiedFlightRecordOnMainContext, toMatch: tempFlightRecord.timesheet)
                }
                    
                else
                {
                    if var matchedMainStoreFlightRecord = matchingFlightRecords.first, matchingFlightRecords.count == 1
                    {
                        if newerAndOlderRecord(matchedMainStoreFlightRecord, secondRecord: tempFlightRecord).newerRecord === tempFlightRecord
                        {
//                            modifiedRecords.append((tempRecord: tempFlightRecord, mainStoreRecord: matchedMainStoreFlightRecord))
                            matchedMainStoreFlightRecord.dualParticipantType = tempFlightRecord.dualParticipantType
                            matchedMainStoreFlightRecord.flightLengthInMinutes = tempFlightRecord.flightLengthInMinutes
                            matchedMainStoreFlightRecord.flightSequence = tempFlightRecord.flightSequence
                            matchedMainStoreFlightRecord.picParticipantType = tempFlightRecord.picParticipantType
                            matchedMainStoreFlightRecord.recordChangeTime = tempFlightRecord.recordChangeTime
                            matchedMainStoreFlightRecord.recordID = tempFlightRecord.recordID
                            matchedMainStoreFlightRecord.timeDown = tempFlightRecord.timeDown
                            matchedMainStoreFlightRecord.timeUp = tempFlightRecord.timeUp
                            matchedMainStoreFlightRecord.transitRoute = tempFlightRecord.transitRoute
                            
                            if tempFlightRecord.timesheet == nil
                            {
                                matchedMainStoreFlightRecord.clearRelationships()
                            }
                                
                            else
                            {
                                setPilotFor(&matchedMainStoreFlightRecord, toMatch: tempFlightRecord.pilot)
                                
                                if let passenger = tempFlightRecord.passenger
                                {
                                    setPassengerFor(&matchedMainStoreFlightRecord, toMatch: passenger)
                                }
                                
                                setTimesheetFor(&matchedMainStoreFlightRecord, toMatch: tempFlightRecord.timesheet)
                                
                                if let _ = tempFlightRecord.connectedAircraftRecord?.pilot
                                {
                                    setConnectedRecordFor(&matchedMainStoreFlightRecord, toMatch: tempFlightRecord.connectedAircraftRecord!.recordID)
                                }
                            }
                        }
                    }
                        
                    else
                    {
                        print("There should be exactly one flight record with a given ID in the database, instead there are \(matchingFlightRecords.count)")
                    }
                }
                
                numberOfRecordsAnalyzed += 1
                let fractionCompleted = (numberOfRecordsAnalyzed / numberOfFlightRecordsToAnalyze)
                mainQueue.async{progressViewer.flightRecords.setProgress(fractionCompleted, animated: false)}
                saveIfNecessary()
            }
            mainQueue.async{progressViewer.flightRecords.setProgress(1, animated: false)}
            try! context.save()
        }
        
//        tempFlightRecordRequest.predicate = NSPredicate(format: "recordID == nil")
//        print(tempFlightRecordList.count)

        
        autoreleasepool
        {
            let numberOfPairsToAnalyze = Float(modifiedRecords.count)
            numberOfRecordsAnalyzed = 0

            for modifiedPair in modifiedRecords
            {
                autoreleasepool
                {
                    if let tempConnectedRecord = modifiedPair.tempRecord.connectedAircraftRecord
                    {
                        let tempConnectedRecordID = tempConnectedRecord.recordID
                        print("The record ID should be \(tempConnectedRecord.recordID) or better yet \(tempConnectedRecordID)")
                        mainStoreFlightRecordRequest.predicate = NSPredicate(format: "recordID == %@", argumentArray: [tempConnectedRecordID])
                        let matchingRecords = try! context.fetch(mainStoreFlightRecordRequest)
                        
                        if let matchedFlightRecord = matchingRecords.first, matchingRecords.count == 1
                        {
                            modifiedPair.mainStoreRecord.connectedAircraftRecord = matchedFlightRecord
                        }
                            
                        else
                        {
                            print("There should be exactly one flight record with a given recordID in the database")
                        }
                    }
                    
                    numberOfRecordsAnalyzed += 1
                    let fractionCompleted = (numberOfRecordsAnalyzed / numberOfPairsToAnalyze)
                    mainQueue.async{progressViewer.pairing.setProgress(fractionCompleted, animated: false)}
                    saveIfNecessary()
                }
            }
            mainQueue.async{progressViewer.pairing.setProgress(1, animated: false)}

            mainStoreFlightRecordRequest.predicate = nil
            
            try! context.save()
//            context.reset()
        }
        
        autoreleasepool
        {
            mainStoreTimesheetRequest.predicate = nil
            let mainStoreTimesheets = try! context.fetch(mainStoreTimesheetRequest)
            
            let numberOfTimesheetsToTotal = Float(mainStoreTimesheets.count)
            numberOfRecordsAnalyzed = 0
            
            for timesheet in mainStoreTimesheets
            {
                if timesheet.aircraft == nil
                {
                    continue
                }
                
                if timesheet.aircraft.type > .winch
                {
                    let totalMinutes = timesheet.flightRecords.reduce(0, {$0 + Int($1.flightLengthInMinutes)})
                    let hourString = String(fromMinutes: Double(totalMinutes))
                    let decimalString = hourString.decimalHoursValue
                    let initialTTSNdecimal = timesheet.TTSNinitial
                    timesheet.TTSNfinal = initialTTSNdecimal + Decimal(string: decimalString)!
                }
                
                numberOfRecordsAnalyzed += 1
                let fractionCompleted = (numberOfRecordsAnalyzed / numberOfTimesheetsToTotal)
                mainQueue.async{progressViewer.updatingTimesheetTotals.setProgress(fractionCompleted, animated: false)}
            }
            mainQueue.async{progressViewer.updatingTimesheetTotals.setProgress(1, animated: false)}

            let mainStoreAircraft = try! context.fetch(mainStoreAircraftRequest)

            for aircraft in mainStoreAircraft
            {
                setCurrentTimesheetForAircraft(aircraft, possibleContext: context)
            }
            
            try! context.save()
            context.reset()
        }

        print("After deduplication there are \(try! context.count(for: mainStoreSummerUnitRequest)) summer camp flights")
        print("After deduplication there are \(try! context.count(for: mainStoreAircraftRequest)) aircraft")
        print("After deduplication there are \(try! context.count(for: mainStoreMaintenanceEventRequest)) maintenance items")
        print("After deduplication there are \(try! context.count(for: mainStorePilotRequest)) pilots")
        print("After deduplication there are \(try! context.count(for: mainStoreQualRequest)) quals")
        print("After deduplication there are \(try! context.count(for: mainStoreAttendanceRequest)) attendance records")
        print("After deduplication there are \(try! context.count(for: mainStoreTimesheetRequest)) timesheets")
        print("After deduplication there are \(try! context.count(for: mainStoreFlightRecordRequest)) flight records")
    }
}
