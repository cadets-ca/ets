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
    // TODO: this method does not seem to do much. Need to clarify reason for existance and possibly extract code (in
    //          the StoryBoard??).
    //       The only place that seem to need to display or hide (as the previous name implied) is in the gliding
    //          centre selection window where there is no need for a back or done button on the iPhone, while it is
    //          required on the iPad.
    func setControllerViewBackgroundColorAndBackButton(controller: UIViewController, withDoneButtonAction action: String)
    {
        controller.view.backgroundColor = UIColor.systemGroupedBackground
        let backButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target:controller, action:Selector(action))
        controller.navigationItem.rightBarButtonItem = backButton
    }
    
    func adjustBackgroundGivenTraitCollection(_ traitCollection: UITraitCollection?, controller: UIViewController)
    {
        if let presentingViewController = controller.presentingViewController
        {
            if (presentingViewController.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.compact)
            {
//                controller.view.backgroundColor = UIColor.groupTableViewBackground
            }
                
            else
            {
//                controller.view.backgroundColor = UIColor.clear
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
