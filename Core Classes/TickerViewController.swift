//
//  TickerViewController.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2015-01-04.
//
//

import Foundation
import UIKit

final class TickerViewController: UIViewController
{
    @IBOutlet var message: UILabel!
    @IBOutlet var gcImage: UIImageView!
    var gcName: String!

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        let effectView = view as? UIVisualEffectView
        effectView?.layer.cornerRadius = 18
        effectView?.layer.masksToBounds = true
        
        let GCImage = UIImage(named: gcName)
        self.gcImage.image = GCImage
    }
}
