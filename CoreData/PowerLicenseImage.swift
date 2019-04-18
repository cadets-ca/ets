//
//  PowerLicenseImage.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class PowerLicenseImage: NSManagedObject
{
    @NSManaged var image: AnyObject
    @NSManaged var pilot: Timesheets.Pilot
    
    class var request: NSFetchRequest<PowerLicenseImage>
    {
        return self.fetchRequest() as! NSFetchRequest<PowerLicenseImage>
    }
}
