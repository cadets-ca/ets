//
//  ImageTransformer.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-03-31.
//
//

import Foundation
import UIKit
import CoreData

final class ImageToDataTransformer : ValueTransformer
{
    override class func allowsReverseTransformation() -> Bool
    {
        return true
    }
    
    override class func transformedValueClass() -> AnyClass
    {
        return NSData.self
    }
    
    override func transformedValue(_ value: Any?) -> Any?
    {
        if value is UIImage
        {
            return (value as! UIImage).jpegData(compressionQuality: 0.9 as CGFloat)
        }
        
        return nil
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any?
    {
        if let data = value as? Data
        {
            return UIImage(data: data)
        }
        
        return nil
    }
}
