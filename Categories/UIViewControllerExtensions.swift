//
//  UITableViewControllerExtensions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-08.
//
//

import Foundation
import UIKit

extension UIViewController
{
    func addOrRemoveDoneButtonGivenTraitCollection(_ traitCollection: UITraitCollection?, controller: UIViewController, withDoneButtonAction action: String)
    {
        if let presentingViewController = controller.presentingViewController
        {
            if (presentingViewController.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.compact)
            {
                controller.view.backgroundColor = UIColor.groupTableViewBackground
                let backButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target:controller, action:Selector(action))
                controller.navigationItem.rightBarButtonItem = backButton
            }
                
            else
            {
                controller.view.backgroundColor = UIColor.clear
                controller.navigationItem.rightBarButtonItem = nil
            }
        }
    }
    
    func adjustBackgroundGivenTraitCollection(_ traitCollection: UITraitCollection?, controller: UIViewController)
    {
        if let presentingViewController = controller.presentingViewController
        {
            if (presentingViewController.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.compact)
            {
                controller.view.backgroundColor = UIColor.groupTableViewBackground
            }
                
            else
            {
                controller.view.backgroundColor = UIColor.clear
            }
        }
    }
    
    class func presentOnTopmostViewController(_ controllerToPresent: UIViewController)
    {
        let rootController = ((UIApplication.shared.delegate as! TimesheetsAppDelegate).window!.rootViewController!)
        var topViewController = rootController
        
        while let child = topViewController.presentedViewController
        {
            if child is UIAlertController
            {
                topViewController.dismiss(animated: true){topViewController.present(controllerToPresent, animated:true, completion:nil)}
                return
            }
            
            topViewController = child
        }
        
        topViewController.present(controllerToPresent, animated:true, completion:nil)
    }
}
