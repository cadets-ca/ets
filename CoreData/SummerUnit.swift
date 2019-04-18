//
//  SummerUnit.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class SummerUnit: NSManagedObject
{
    @NSManaged var name: String
    @NSManaged var pilots: Set<Pilot>
    
    class var request: NSFetchRequest<SummerUnit>
    {
        return self.fetchRequest() as! NSFetchRequest<SummerUnit>
    }
    
    override var description: String
    {
        return "\(name) contains \(pilots.count) pilots."
    }
    
    override var debugDescription: String
    {
        return description
    }
    
    override func awakeFromInsert()
    {
        name = ""
    }
}
