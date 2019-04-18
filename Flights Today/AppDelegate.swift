//
//  AppDelegate.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-15.
//

import UIKit
import CloudKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    var cloudKitController: CloudKitControllerTV?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        cloudKitController = CloudKitControllerTV()
        application.registerForRemoteNotifications()
        return true
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        print("Not registered")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        print("registered")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        print("Received notification!")

        let dict = userInfo as! [String: NSObject]
        let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary:dict)

        if cloudKitNotification.notificationType == .database
        {
            print("Received database notification!")
            cloudKitController?.performSubsequentFetch()
            completionHandler(.newData)
        }
        
        else
        {
            completionHandler(.noData)
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication)
    {
        cloudKitController?.performInitialFetch()
    }
}
