//
//  ShowPhotoViewController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-04-01.
//
//

import Foundation
import UIKit
import CoreData

final class ShowPhotoViewController : UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    var pilot: Pilot!
    var photoType = Photos.gliderLicense
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var toolBar: UIToolbar!

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.black
        
        switch photoType
        {
        case .gliderLicense:
            imageView.image = pilot.gliderLicenseImage?.image as? UIImage
            
        case .powerLicense:
            imageView.image = pilot.powerLicenseImage?.image as? UIImage
            
        case .pilotPhoto:
            imageView.image = pilot.photo?.image as? UIImage
            
        case .medical:
            imageView.image = pilot.medicalImage?.image as? UIImage
        }
    }
    
    @IBAction func removePhoto()
    {
        let deleteWarning = UIAlertController(title: nil, message: "Are you sure you want to remove this photo? It will be permanently deleted.", preferredStyle: .actionSheet)
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler:nil)
        deleteWarning.addAction(cancelButton)
        let deleteButton = UIAlertAction(title: "Remove Photo", style: .destructive, handler: {_ in self.deletePhoto()})
        deleteWarning.addAction(deleteButton)
        present(deleteWarning, animated:true, completion:nil)
    }
    
    func deletePhoto()
    {
        switch photoType
        {
        case .gliderLicense:
            if let oldImage = pilot.gliderLicenseImage
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            pilot.gliderLicenseImage = nil
            pilot.gliderThumbnailImage = nil
            
        case .powerLicense:
            if let oldImage = pilot.powerLicenseImage
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            pilot.powerLicenseImage = nil
            pilot.powerThumbnailImage = nil
            
        case .pilotPhoto:
            if let oldImage = pilot.photo
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            pilot.photo = nil
            pilot.photoThumbnailImage = nil
            
        case .medical:
            if let oldImage = pilot.medicalImage
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            pilot.medicalImage = nil
            pilot.medicalThumbnailImage = nil
        }
        
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        viewWillAppear(false)
        
        let refreshNotification = Notification(name: reloadPilotNotification, object: pilot,  userInfo: nil)
        NotificationCenter.default.post(refreshNotification)


    }
    
    override var prefersStatusBarHidden: Bool
    {
        return true
    }
    
    @IBAction func editPhoto()
    {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        if UIImagePickerController.isSourceTypeAvailable(.camera)
        {
            imagePicker.sourceType = .camera
        }
        
        else
        {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
            {
                imagePicker.sourceType = .photoLibrary
            }
            
            else
            {
                return
            }
        }
        
        imagePicker.modalPresentationStyle = .fullScreen
        present(imagePicker, animated:true, completion:nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
    {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage else {return}
        let workingImage: UIImage = photoType == .pilotPhoto ? image.cropToPortrait : image.convertImageToGrayScale
        
        let size = workingImage.size
        var ratio = 0 as CGFloat
        ratio = size.width > size.height ? 44 as CGFloat / size.width :44 as CGFloat / size.height
        let rect = CGRect(x: 0.0, y: 0.0, width: ratio * size.width, height: ratio * size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 2.0)
        
        workingImage.draw(in: rect)
        
        func createScaledImage()
        {
            ratio = (size.width > size.height) ? (320.0 / size.width) : (320.0 / size.height)
            let rect = CGRect(x: 0.0, y: 0.0, width: ratio * size.width, height: ratio * size.height)
            UIGraphicsBeginImageContextWithOptions(rect.size, true, 2.0)
            workingImage.draw(in: rect)
        }
        
        switch photoType
        {
        case .gliderLicense:
            if let oldImage = pilot.gliderLicenseImage
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            
            pilot.gliderThumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            let image = GliderLicenseImage(context: dataModel.managedObjectContext)
            pilot.gliderLicenseImage = image
            createScaledImage()
            image.image = UIGraphicsGetImageFromCurrentImageContext()!
            
        case .powerLicense:
            if let oldImage = pilot.powerLicenseImage
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            
            self.pilot.powerThumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            let image = PowerLicenseImage(context: dataModel.managedObjectContext)
            pilot.powerLicenseImage = image
            createScaledImage()
            image.image = UIGraphicsGetImageFromCurrentImageContext()!
            
        case .medical:
            if let oldImage = pilot.medicalImage
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            
            self.pilot.medicalThumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            let image = MedicalImage(context: dataModel.managedObjectContext)
            pilot.medicalImage = image
            createScaledImage()
            image.image = UIGraphicsGetImageFromCurrentImageContext()!
            
        case .pilotPhoto:
            if let oldImage = pilot.photo
            {
                pilot.managedObjectContext?.delete(oldImage)
            }
            
            self.pilot.photoThumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            let image = Photo(context: dataModel.managedObjectContext)
            pilot.photo = image
            createScaledImage()
            image.image = UIGraphicsGetImageFromCurrentImageContext()!
            let refreshNotification = Notification(name: reloadPilotNotification, object:pilot)
            NotificationCenter.default.post(refreshNotification)
        }
        
        UIGraphicsEndImageContext()
        
        NotificationCenter.default.post(name: pilotBeingEditedNotification, object:self)
        dismiss(animated: true, completion: nil)
        viewWillAppear(false)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        dismiss(animated: true, completion:nil)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
