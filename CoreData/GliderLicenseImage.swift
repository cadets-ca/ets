//
//  GliderLicenseImage.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-22.
//
//

import Foundation
import UIKit
import CoreData

final class GliderLicenseImage: NSManagedObject
{
    @NSManaged var image: AnyObject
    @NSManaged var pilot: Timesheets.Pilot
    
    class var request: NSFetchRequest<GliderLicenseImage>
    {
        return self.fetchRequest() as! NSFetchRequest<GliderLicenseImage>
    }
}
