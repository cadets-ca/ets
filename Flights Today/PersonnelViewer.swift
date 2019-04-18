//
//  PersonnelViewer.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2018-09-07.
//

import Foundation
import UIKit
import CloudKit

class PersonnelViewer: UICollectionViewController, siteSelectionDelegate
{
    var cloudKitController: CloudKitControllerTV!
    var siteSelector: SiteSelection!
    var gliderPilotRecords = [[PilotRecordData]]()
    var towPilotRecords = [[PilotRecordData]]()
    let gliderSectionHeaders = ["Guest", "Student",  "Basic Glider Pilot",  "Front Seat Famil",  "Rear seat Famil", "Glider Instructor", "Glider Check Pilot", "Glider Standards Pilot"]
    let towplaneSectionHeaders = ["None", "Tow Pilot", "Tow Check Pilot", "Tow Standards Pilot"]

    override func viewDidLoad()
    {
        super.viewDidLoad()
        cloudKitController = (UIApplication.shared.delegate as! AppDelegate).cloudKitController
        NotificationCenter.default.addObserver(self, selector: #selector(self.prepareRecords), name: newDataNotification, object: nil)
        collectionView?.allowsSelection = true
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize
    {
        let height = 300
        let collectionViewWidth = view.bounds.size.width
        let numberOfCells = CGFloat(3)
        let width = (collectionViewWidth - 60) / numberOfCells
        
        return CGSize(width: width, height: CGFloat(height))
    }
    
    @objc func prepareRecords()
    {
        gliderPilotRecords.removeAll()
        towPilotRecords.removeAll()
        var gliderPilots = Array(cloudKitController!.allGliderStaffRecords).map{$0.pilotData}.sorted(by: {$0.highestGliderQual < $1.highestGliderQual})
        var towPilots = Array(cloudKitController!.allTowStaffRecords).map{$0.pilotData}.sorted(by: {$0.highestTowQual < $1.highestTowQual})
        
        guard let siteSelector = siteSelector else {return}
        
        if siteSelector.selectedSite != "All"
        {
            gliderPilots = gliderPilots.filter({$0.glidingSite == siteSelector.selectedSite})
            towPilots = towPilots.filter({$0.glidingSite == siteSelector.selectedSite})
        }

        var pilotsOfQualLevel = [PilotRecordData]()
        var qualLevel = Int(0)
        
        for data in gliderPilots
        {
            if data.highestGliderQual == qualLevel
            {
                pilotsOfQualLevel.append(data)
            }
            
            else
            {
                if pilotsOfQualLevel.count > 0 {gliderPilotRecords.append(pilotsOfQualLevel.sorted(by: {$0.name < $1.name}))}
                pilotsOfQualLevel.removeAll()
                pilotsOfQualLevel.append(data)
                qualLevel = data.highestGliderQual
            }
        }
        if pilotsOfQualLevel.count > 0 {gliderPilotRecords.append(pilotsOfQualLevel.sorted(by: {$0.name < $1.name}))}
        
        pilotsOfQualLevel.removeAll()
        qualLevel = Int(0)
        
        for data in towPilots
        {
            if data.highestTowQual == qualLevel
            {
                pilotsOfQualLevel.append(data)
            }
                
            else
            {
                if pilotsOfQualLevel.count > 0 {towPilotRecords.append(pilotsOfQualLevel.sorted(by: {$0.name < $1.name}))}
                pilotsOfQualLevel.removeAll()
                pilotsOfQualLevel.append(data)
                qualLevel = data.highestTowQual
            }
        }
        if pilotsOfQualLevel.count > 0 {towPilotRecords.append(pilotsOfQualLevel.sorted(by: {$0.name < $1.name}))}

        collectionView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        cloudKitController.performInitialStaffFetch()
        siteSelector = (parent! as! RecordsTabRootViewController).siteSelector
        siteSelector.delegate = self
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return section < gliderPilotRecords.count ? gliderPilotRecords[section].count : towPilotRecords[section - gliderPilotRecords.count].count
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        return gliderPilotRecords.count + towPilotRecords.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as? PersonnelViewerHeader
        {
            var highestQual = 0
            if indexPath.section < gliderPilotRecords.count, let sampleData = gliderPilotRecords[indexPath.section].first
            {
                highestQual = sampleData.highestGliderQual
            }
            
            else
            {
                if let sampleData = towPilotRecords[indexPath.section - gliderPilotRecords.count].first
                {
                    highestQual = sampleData.highestTowQual
                }
            }
            
            let headerText = indexPath.section < gliderPilotRecords.count ? gliderSectionHeaders[highestQual] : towplaneSectionHeaders[highestQual]
            
            sectionHeader.label.text = headerText
            return sectionHeader
        }
        return UICollectionReusableView()
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GliderPilotCell", for: indexPath) as! PilotTVcell

        let recordData = indexPath.section < gliderPilotRecords.count ? gliderPilotRecords[indexPath.section][indexPath.row] : towPilotRecords[indexPath.section - gliderPilotRecords.count][indexPath.row]
        cell.name.text = recordData.name
        cell.currency.text = recordData.gliderAPC.militaryFormatShort
        cell.medical.text = recordData.medical.militaryFormatShort
        cell.FI.text = recordData.FIexpiry.militaryFormatShort
        cell.participantType.text = recordData.typeOfParticipant
        cell.dateModified.text = recordData.dateModified.militaryFormatShort + " \(recordData.dateModified.hoursAndMinutes)"
        cell.recordID.text = recordData.recordID.militaryFormatShort + " \(recordData.recordID.hoursAndMinutes)"
        
        return cell
    }
}
