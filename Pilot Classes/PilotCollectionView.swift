//
//  PilotCollectionView.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-05-12.
//
//

import Foundation
import UIKit
import CoreData

prefix operator ~>

prefix func ~> (closure: @escaping () -> ())
{
    mainQueue.async(execute: closure)
}

final class PilotCollectionView : UICollectionViewController
{
    var gliderFetchController: NSFetchedResultsController<Pilot>!
    var towplaneFetchController: NSFetchedResultsController<Pilot>!
    var gliderSectionHeaders = [String]()
    var towplaneSectionHeaders = [String]()
    var gliderAbbreviationExplanation: NSAttributedString?
    var towAbbreviationExplanation: NSAttributedString?
    lazy var gliderImage: UIImage = UIImage(assetIdentifier: .GliderLanding)
    lazy var towplaneImage: UIImage = UIImage(assetIdentifier: .ScoutLanding)
    let backgroundContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

    enum SegueIdentifiers: String
    {
        case ViewPilotInfoSegue = "ViewPilotInfoSegue"
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        backgroundContext.persistentStoreCoordinator = dataModel.managedObjectContext.persistentStoreCoordinator
        
        let gliderPilotRequest = Pilot.request
        gliderPilotRequest.predicate = NSPredicate(format: "inactive == NO AND glidingCentre == %@ AND highestGliderQual > 0", dataModel.glidingCentre)
        let gliderQualSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.highestGliderQual), ascending: false)
        let nameSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.fullName), ascending: true)
        gliderPilotRequest.sortDescriptors = [gliderQualSortDescriptor, nameSortDescriptor]
        gliderFetchController = NSFetchedResultsController(fetchRequest: gliderPilotRequest, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: "highestGliderQual", cacheName:nil)
        
        let towPilotRequest = Pilot.request
        towPilotRequest.predicate = NSPredicate(format: "inactive == NO AND glidingCentre == %@ AND highestScoutQual > 0", dataModel.glidingCentre)
        let scoutQualSortDescriptor = NSSortDescriptor(key: #keyPath(Pilot.highestScoutQual), ascending: false)
        towPilotRequest.sortDescriptors = [scoutQualSortDescriptor, nameSortDescriptor]
        towplaneFetchController = NSFetchedResultsController(fetchRequest: towPilotRequest, managedObjectContext: dataModel.managedObjectContext, sectionNameKeyPath: "highestScoutQual", cacheName:nil)
        
        do {
            try gliderFetchController.performFetch()
        } catch _ {
        }
        do {
            try towplaneFetchController.performFetch()
        } catch _ {
        }
        
        gliderSectionHeaders = ["Level 4+ Cadet", "Level 3 Cadet", "Level 2 Cadet", "Level 1 Cadet", "Guest", "Student", "Basic Glider Pilot", "Front Seat Famil", "Rear seat Famil", "Glider Instructor", "Glider Check Pilot", "Glider Standards Pilot"]
        
        towplaneSectionHeaders = ["None", "Tow Pilot", "Tow Check Pilot", "Tow Standards Pilot"]
        
        collectionView?.backgroundColor = (presentingViewController?.traitCollection.horizontalSizeClass == .compact) ? UIColor.groupTableViewBackground : UIColor.clear
        setPreferredContentSizeWithSize(presentingViewController!.view.frame.size)
    }
    
    func setPreferredContentSizeWithSize(_ size: CGSize)
    {
        let presentingViewWidth = size.width
        let maxNumberVisible = floor((presentingViewWidth + 5) / 195)
        let maxUsefulWidth = (maxNumberVisible * 195) - 5
        
        collectionView?.layoutIfNeeded()
        var preferredWidth = collectionView!.contentSize.width
        
        if preferredWidth > maxUsefulWidth
        {
            preferredWidth = maxUsefulWidth
        }
        
        preferredContentSize = CGSize(width: preferredWidth, height: collectionView!.contentSize.height)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        collectionView?.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize
    {
        let height = ((indexPath as NSIndexPath).section < gliderFetchController.sections!.count) ? 200 : 180
        let collectionViewWidth = view.bounds.size.width
        let numberOfCells = floor((collectionViewWidth + 5) / 190)
        let width = (collectionViewWidth + 5 - 5*numberOfCells) / numberOfCells
        
        return CGSize(width: width, height: CGFloat(height))
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        setPreferredContentSizeWithSize(size)
        collectionView?.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        adjustBackgroundGivenTraitCollection(previousTraitCollection, controller: self)
        collectionView?.layoutIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        for pilot in towplaneFetchController.fetchedObjects!
        {
            pilot.largePilotPhotoThumbnail = nil
            pilot._allTimeStatsCache = nil
            pilot._thisYearStatsCache = nil
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .ViewPilotInfoSegue:
            let editPilot = segue.destination as? EditPilotPopover
            let indexPath = collectionView!.indexPathsForSelectedItems![0]
            
            var pilot: Pilot
            let section = (indexPath as NSIndexPath).section
            let row = (indexPath as NSIndexPath).row
            
            if section < gliderFetchController.sections!.count
            {
                pilot = gliderFetchController.object(at: indexPath)
            }
                
            else
            {
                let relativeSection = section - gliderFetchController.sections!.count
                let path = IndexPath(row: row, section: relativeSection)
                pilot = towplaneFetchController.object(at: path)
            }
            
            editPilot?.pilot = pilot
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        performSegue(withIdentifier: "ViewPilotInfoSegue", sender:nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        if section < gliderFetchController.sections!.count
        {
            return gliderFetchController.sections![section].numberOfObjects
        }
            
        else
        {
            let relativeSection = section - (gliderFetchController.sections?.count ?? 0)
            return towplaneFetchController.sections?[relativeSection].numberOfObjects ?? 0
        }
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        return (gliderFetchController.sections?.count ?? 0) + (towplaneFetchController.sections?.count ?? 0)
    }
    
    func configureCell(_ cell: CollectionViewCellStylePilot, ofType type: VehicleType, onContext context: NSManagedObjectContext, forPilotWithID ID: NSManagedObjectID)
    {
        let pilot = context.object(with: ID) as! Pilot
        
        let name = pilot.fullName
        ~>{cell.name.text = name}
        
        if type == .glider
        {
            if pilot.largePilotPhotoThumbnail != nil
            {
                ~>{cell.photo.image = pilot.largePilotPhotoThumbnail}
            }
                
            else
            {
                ~>{cell.photo.image = self.gliderImage}
            }
        }
            
        else
        {
            if pilot.largePilotPhotoThumbnail != nil
            {
                ~>{cell.photo.image = pilot.largePilotPhotoThumbnail}
            }
                
            else
            {
                ~>{cell.photo.image = self.towplaneImage}
            }
        }
        
        ~>{cell.participantStatus.textColor = UIColor.black}
        
        switch pilot.typeOfParticipant
        {
        case "Staff Cadet":
            var text = "Staff Cadet"
            let threeMonthsFromNow = Date() + (90*24*60*60)
            
            switch pilot.ageOutDate
            {
            case Date.distantPast:
                ~>{cell.participantStatus.text = "Cadet"}
                
            case Date.distantPast ..< Date():
                text += " (Aged Out \(pilot.ageOutDate.militaryFormatShort))"
                ~>{cell.participantStatus.textColor = UIColor.red}
                ~>{cell.participantStatus.text = text}
                
            case Date() ..< threeMonthsFromNow:
                text += " (Until \(pilot.ageOutDate.militaryFormatShort))"
                ~>{cell.participantStatus.textColor = UIColor.orange}
                ~>{cell.participantStatus.text = text}
                
            default:
                text += " (Until \(pilot.ageOutDate.militaryFormatShort))"
                ~>{cell.participantStatus.text = text}
            }
            
        case "COATS":
            ~>{cell.participantStatus.text = "COATS"}
            
        case "Volunteer":
            ~>{cell.participantStatus.text = "Volunteer"}
            
        case "Civilian Instructor":
            ~>{cell.participantStatus.text = "Civilian Instructor"}
            
        default:
            break
        }
        
        let medicalExpiry = (type == .glider) ? pilot.medical : pilot.powerMedicalExpiryDate
        
        ~>{cell.medicalExpiryDate.text = medicalExpiry < Date() ? "Expired" : medicalExpiry.militaryFormatShort}
        ~>{cell.medicalExpiryDate.textColor = medicalExpiry < Date() ? UIColor.red : UIColor.black}
        
        let currencyCalculationResults = pilot.calculateCurrencyDateOnType(type)
        
        let currencyDate = currencyCalculationResults.canFlyUntilDate
        let APCexpiresBeforeCurrency = currencyCalculationResults.APCexpiresBeforeCurrency
        
        ~>{cell.currencyExpiryDate.text = APCexpiresBeforeCurrency ? "\(currencyDate.militaryFormatShort) (APC)" : currencyDate.militaryFormatShort}
        let tomorrow = Date() + (24*60*60)
        
        switch currencyDate
        {
        case Date.distantPast ..< Date():
            ~>{cell.currencyExpiryDate.textColor = UIColor.red}
            ~>{cell.currencyExpiryDate.text = APCexpiresBeforeCurrency ? "Expired APC" : "Expired"}
            
        case Date() ..< tomorrow:
            ~>{cell.currencyExpiryDate.textColor = UIColor.orange}
            
        default:
            ~>{cell.currencyExpiryDate.textColor = UIColor.black}
        }
        
        let pilotIsInstructor = pilot.gliderQual > .rearSeatFamil ? true : false
        ~>{cell.flightInstructorExpiryDate?.text = ""}
        
        if pilotIsInstructor
        {
            ~>{cell.flightInstructorExpiryDate?.text = pilot.fiExpiry < Date() ? "Expired" : pilot.fiExpiry.militaryFormatShort}
            ~>{cell.flightInstructorExpiryDate?.textColor = pilot.fiExpiry < Date() ? UIColor.red : UIColor.black}
        }
        
        let daysWorked = pilot.numberOfDaysWorkedAtGC(dataModel.glidingCentre)
        ~>{cell.numberOfDaysWorked.text = "\(daysWorked)"}
        
        let allTimePilotStats = pilot.allTimeStatsCache
        
        let gliderFlightsNumber = allTimePilotStats.gliderFlights + Int(pilot.gliderFlightsAdjustment)
        let winchLaunchNumber = allTimePilotStats.launchesAsWinchOperator
        let autoLaunchNumber = allTimePilotStats.launchesAsAutoDriver
        
        let gliderPICstring = String(fromMinutes: Double(allTimePilotStats.gliderPICminutes) + Double(pilot.gliderPIChoursAdjust))
        let gliderInstructorString = String(fromMinutes: Double(allTimePilotStats.gliderInstructorMinutes) + Double(pilot.gliderInstHoursAdjust))
        
        ~>{cell.totalGliderFlights?.text = "\(gliderFlightsNumber)"}
        ~>{cell.launchesAsWinchOperator?.text = "\(winchLaunchNumber)"}
        ~>{cell.launchesAsAutoTowDriver?.text = "\(autoLaunchNumber)"}
        
        let thisYearPilotStats = pilot.thisYearStatsCache
        let gliderFlightsThisYearNumber = thisYearPilotStats.gliderFlights
        
        ~>{cell.gliderFlightsInPast365days?.text = "\(gliderFlightsThisYearNumber)"}
        
        if type == .glider
        {
            ~>{cell.PICtime.text = gliderPICstring}
        }
        
        else
        {
            let TowPICstring = String(fromMinutes: Double(allTimePilotStats.towPICminutes))
            ~>{cell.PICtime.text = TowPICstring.decimalHoursValue}
            ~>{cell.towPIC?.text = cell.PICtime.text}
        }
        
        ~>{cell.instructorTime?.text = gliderInstructorString}
        
        let totalTowsNumber = allTimePilotStats.towAircraftTows
        let totalTowsThisYearNumber = thisYearPilotStats.towAircraftTows
        
        if (gliderFlightsThisYearNumber + totalTowsThisYearNumber == 0) && (gliderFlightsNumber + totalTowsNumber > 0)
        {
            pilot.inactive = true
            try! context.save()
            print("\(pilot.fullName) inactivated")
        }
        
        ~>{cell.totalTowFlights?.text = "\(totalTowsNumber)"}
        ~>{cell.towFlightsInPast365days?.text = "\(totalTowsThisYearNumber)"}
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell: CollectionViewCellStylePilot
        
        if (indexPath as NSIndexPath).section < gliderFetchController.sections!.count
        {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StandardCell", for: indexPath) as! CollectionViewCellStylePilot
        }
            
        else
        {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TowPilotCell", for: indexPath) as! CollectionViewCellStylePilot
        }
        
        cell.layer.cornerRadius = 5
        cell.layer.masksToBounds = true
        
        let pilot: Pilot
        let section = (indexPath as NSIndexPath).section
        let row = (indexPath as NSIndexPath).row
        let type: VehicleType
        
        if section < gliderFetchController.sections!.count
        {
            pilot = gliderFetchController.object(at: indexPath) 
            type = .glider
        }
            
        else
        {
            let relativeSection = section - gliderFetchController.sections!.count
            let path = IndexPath(row:row, section:relativeSection)
            pilot = towplaneFetchController.object(at: path) 
            type = .towplane
        }
        
        backgroundContext.perform{self.configureCell(cell, ofType: type, onContext: self.backgroundContext, forPilotWithID: pilot.objectID)}
        
        return cell
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let reusableView: UICollectionReusableView
        let section = (indexPath as NSIndexPath).section
        
        if kind == "UICollectionElementKindSectionHeader"
        {
            reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: "UICollectionElementKindSectionHeader", withReuseIdentifier: "Header", for: indexPath) as UICollectionReusableView
            
            let sectionTitle: String
            
            if section < gliderFetchController.sections!.count
            {
                let indexOfTitle = (gliderFetchController.sections![section]).name.intValueWithNegatives + 4
                sectionTitle = gliderSectionHeaders[indexOfTitle]
            }
                
            else
            {
                let relativeSection = section - gliderFetchController.sections!.count
                let indexOfTitle = (towplaneFetchController.sections![relativeSection]).name.intValueWithNegatives
                sectionTitle = towplaneSectionHeaders[indexOfTitle]
            }
            
            let qualLabel = reusableView.viewWithTag(1) as? UILabel
            qualLabel?.text = sectionTitle
        }
        
        else
        {
            reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: "UICollectionElementKindSectionFooter", withReuseIdentifier: "Footer", for: indexPath) as UICollectionReusableView

            let abbreviationKey = reusableView.viewWithTag(1) as? UILabel
            
            if gliderAbbreviationExplanation == nil
            {
                if let textOfBothAbbreviationExplanations = abbreviationKey?.attributedText
                {
                    gliderAbbreviationExplanation = textOfBothAbbreviationExplanations.attributedSubstring(from: NSMakeRange(0, 344))
                    towAbbreviationExplanation = textOfBothAbbreviationExplanations.attributedSubstring(from: NSMakeRange(344, 206))
                }
            }
            
            if gliderAbbreviationExplanation != nil
            {
                abbreviationKey?.attributedText = ((indexPath as NSIndexPath).section < gliderFetchController.sections!.count) ? gliderAbbreviationExplanation : towAbbreviationExplanation
            }
        }
        
        return reusableView
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: NSInteger) -> CGSize
    {
        let footerSize: CGSize
        
        if (section == (gliderFetchController.sections!.count - 1) || (section == (numberOfSections(in: collectionView) - 1)))
        {
            let x = collectionView.bounds.width
            let y = 50000 / x
            footerSize = CGSize(width: x, height: y)
        }
            
        else
        {
            footerSize = CGSize(width: 0, height: 0)
        }
        
        return footerSize
    }
}
