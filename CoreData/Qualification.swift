//
//  Qualification.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class Qualification: NSManagedObject
{
    @NSManaged var nameOfQualification: String
    @NSManaged var pilotsWhoHaveIt: Set<Pilot>
    
    class var request: NSFetchRequest<Qualification>
    {
        return self.fetchRequest() as! NSFetchRequest<Qualification>
    }
    
    override func awakeFromInsert()
    {
        nameOfQualification = ""
    }
}
