//
//  Region.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class Region: NSManagedObject
{
    @NSManaged var name: String
    
    class var request: NSFetchRequest<Region>
    {
        return self.fetchRequest() as! NSFetchRequest<Region>
    }
    
    override func awakeFromInsert()
    {
        name = ""
    }
}
