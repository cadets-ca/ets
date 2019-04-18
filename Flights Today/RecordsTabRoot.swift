//
//  RecordsTabRoot.swift
//  Flights Today
//
//  Created by Paul Kirvan on 2017-09-18.
//

import UIKit

class RecordsTabRootViewController: UISplitViewController
{
    var cloudKitController: CloudKitControllerTV!
    lazy var siteSelector: SiteSelection? = (viewControllers[0] as! UINavigationController).topViewController as? SiteSelection
    var recordViewer: FlightRecordsViewer!

    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        cloudKitController = (UIApplication.shared.delegate as! AppDelegate).cloudKitController
        recordViewer = viewControllers[1] as? FlightRecordsViewer
        tabBarController?.viewControllers?[0].title? = "Flight Records"
        tabBarController?.viewControllers?[1].title? = "Leaderboards"
        tabBarController?.viewControllers?[2].title? = "Pilots"
    }
}
