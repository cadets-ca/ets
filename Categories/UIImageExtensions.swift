//
//  UIImageExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-03.
//
//

import Foundation
import UIKit

extension UIImage
{
    enum AssetIdentifier: String
    {
        case Clouds = "CloudBackdropLandscape"
        case FullBeacon = "FullBeacon"
        case IntermediateBeacon = "IntermediateBeacon"
        case LowBeacon = "LowBeacon"
        case Candles = "Candles"
        case BlueCell = "BlueCell"
        case GreenCell = "GreenCell"
        case RedCell = "RedCell"
        case YellowCell = "YellowCell"
        case GreenCheckmark = "GreenCheckmark"
        case EmptyCheckmark = "EmptyCheckmark"
        case AircraftTab = "AircraftTab"
        case Canada = "Canada"
        case Person = "Person"
        case Stopwatch = "Stopwatch"
        case PersonOutline = "PersonOutline"
        case GliderLanding = "GliderLanding"
        case GliderLandingFilled = "GliderLandingFilled"
        case GliderTakeoff = "GliderTakeoff"
        case GliderTakeoffFilled = "GliderTakeoffFilled"
        case ScoutLanding = "ScoutLanding"
        case ScoutLandingFilled = "ScoutLandingFilled"
        case ScoutTakeOff = "ScoutTakeOff"
        case ScoutTakeOffFilled = "ScoutTakeOffFilled"
    }
    
    convenience init!(assetIdentifier: AssetIdentifier)
    {
        self.init(named: assetIdentifier.rawValue)
    }
    
    func croppedImage(_ bounds: CGRect) -> UIImage
    {
        let imageRef = cgImage?.cropping(to: bounds)!
        return UIImage(cgImage: imageRef!, scale: 1.0, orientation: .up)
    }
    
    var cropToPortrait: UIImage
    {
        let width = size.width
        let height = size.height
        var returnImage = self
        
        if width > height
        {
            let newWidth = height * 0.75
            let spareWidth = width - newWidth
            
            let rect = CGRect(x: (spareWidth/2), y: 0.0, width: newWidth, height: height)
            
            returnImage = croppedImage(rect)
        }
        
        return returnImage
    }
    
    var convertImageToGrayScale: UIImage
    {
        let imageRect = (size.width > size.height) ? CGRect(x: 0, y: 0, width: size.width, height: size.height) : CGRect(x: 0, y: 0, width: size.height, height: size.width)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = Int(imageRect.size.width)
        let height = Int(imageRect.size.height)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context?.draw(cgImage!, in: imageRect)
        let imageRef = context?.makeImage()
        return UIImage(cgImage: imageRef!, scale: 1.0, orientation: imageOrientation)
    }
}

final class BackgroundImage
{
    var landscapeBackground: UIImage?
    var portraitBackground: UIImage?
    lazy var cloudImage: UIImage = UIImage(assetIdentifier: .Clouds)
    
    func crop(_ bounds: CGRect) -> UIImage
    {
        let imageRef = cloudImage.cgImage?.cropping(to: bounds)!
        return UIImage(cgImage: imageRef!, scale: 1.0, orientation: UIImage.Orientation.up)
    }
    
    func resizeImage(_ image: UIImage, newSize: CGSize) -> UIImage
    {
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        let imageRef = image.cgImage
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        // Set the quality level to use when rescaling
        context!.interpolationQuality = CGInterpolationQuality.high
        let flipVertical = __CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height)
    
        context?.concatenate(flipVertical)
        // Draw into the context, this scales the image
        context?.draw(imageRef!, in: newRect)
        
        // Get the resized image from the context and a UIImage
        let newImageRef = context?.makeImage()
        let newImage = UIImage(cgImage: newImageRef!)
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func getBackground(_ requiredImageSize: CGSize) -> UIImage
    {
        let scaleFactor = UIScreen.main.scale
        var returnImage: UIImage?
        
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask , true) as [String]
        let pathName = "Clouds\(requiredImageSize.width)x\(requiredImageSize.height).png"
        let filePath = paths[0].stringByAppendingPathComponent(pathName)
        
        returnImage = UIImage(contentsOfFile: filePath)
        
        if let imageFound = returnImage
        {
//            print("The size of the image required is \(requiredImageSize)")
//            print("The size of the image found is \(imageFound.size)")
            
            if (imageFound.size.width != requiredImageSize.width * scaleFactor) || (imageFound.size.height != requiredImageSize.height * scaleFactor)
            {
                returnImage = nil
            }
        }
        
        if returnImage == nil
        {
            let basicImageSize = cloudImage.size
            let desiredAspect = requiredImageSize.height / requiredImageSize.width
            let rawImageAspect = basicImageSize.height / basicImageSize.width
            
            if desiredAspect >= rawImageAspect
            {
                let desiredWidth = basicImageSize.height / desiredAspect
                let cropRect = CGRect(x: 0, y: 0, width: desiredWidth, height: basicImageSize.height)
                returnImage = crop(cropRect)
            }
            
            else
            {
                let desiredHeight = basicImageSize.width * desiredAspect
                let imageCentre = basicImageSize.height / 2 - desiredHeight / 2
                let cropRect = CGRect(x: 0, y: imageCentre, width: basicImageSize.width, height: desiredHeight)
                returnImage = crop(cropRect)
            }
                        
            returnImage = resizeImage(returnImage!, newSize: CGSize(width: requiredImageSize.width, height: requiredImageSize.height))
//            #warning("turn this back on!")
            let _ = ((try? returnImage!.pngData()?.write(to: URL(fileURLWithPath: filePath), options: [.atomic])) as ()??)
        }
        
        return returnImage!
    }
}
