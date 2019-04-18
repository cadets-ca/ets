//
//  NotificationCenterDelegateExtension.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2016-08-10.
//
//

import Foundation
import UserNotifications

extension TimesheetsDataModel: UNUserNotificationCenterDelegate
{
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let identifier = response.actionIdentifier
        if identifier == "Undo"
        {
            aircraftAreaController?.undoLanding()
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let info = notification.request.content.userInfo
        
        if let x = info["Type"] as? String, x == "Landing Alert"
        {
            return
        }
        
        completionHandler(.alert)
    }
}
