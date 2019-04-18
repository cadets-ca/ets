//
//  GlidingDayComment.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class GlidingDayComment: NSManagedObject, RecordsChanges, HasID, AttachedToGlidingUnit
{
    @NSManaged var comment: String
    @NSManaged var date: Date
    @NSManaged var recordChangeTime: Date
    @NSManaged var recordID: Date
    @NSManaged var glidingCentre: Timesheets.GlidingCentre!

    class var request: NSFetchRequest<GlidingDayComment>
    {
        return self.fetchRequest() as! NSFetchRequest<GlidingDayComment>
    }
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        recordChangeTime = Date()
        recordID = Date()
        
        if managedObjectContext == dataModel.managedObjectContext
        {
            glidingCentre = dataModel.glidingCentre
        }
        
        comment = ""
    }
    
    override func willSave()
    {
        if shouldUpdateChangeTimes
        {
            let changeTime = Date()
            setPrimitiveValue(changeTime, forKey:"recordChangeTime")
        }
        super.willSave()
    }
    
    override func didSave()
    {
        if isDeleted == false, managedObjectContext == dataModel.managedObjectContext, observerMode == false, shouldUpdateChangeTimes == true
        {
            cloudKitController?.uploadCommentChanges(self)
        }
    }
    
    override var description: String
    {
        return "recordID:\(recordID) \r recordChangeTime \(recordChangeTime) \r comment \(comment)"
    }
}
