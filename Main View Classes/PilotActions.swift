//
//  PilotActions.swift
//  Timesheets
//
//  Created by Paul Kirvan on 2014-12-05.
//
//

import Foundation
import UIKit

final class PilotActions : UITableViewController
{
    private var flightNames = [String]()
    
    enum SegueIdentifiers: String
    {
        case AddPilotSegue = "AddPilotSegue"
        case AddSquadronCadetsSegue = "AddSquadronCadetsSegue"
        case AddGuestsSegue = "AddGuestsSegue"
        case PilotCollectionViewSegue = "PilotCollectionViewSegue"
        case AddCadetsIndividually = "AddCadetsIndividually"
    }
    
    //MARK: - UIViewController Methods
    @objc func dismiss()
    {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad()
    {
        var flight = CampFlightInfo.initalizeFlightInfoList()
        flight = CampFlightInfo.filterToCurrentRegion(flight)
        flightNames = Array(flight.keys)
        flightNames.sort(by: <)

        tableView.layoutIfNeeded()
        preferredContentSize = CGSize(width: 320, height: tableView.contentSize.height)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        addOrRemoveDoneButtonGivenTraitCollection(presentingViewController?.traitCollection, controller: self, withDoneButtonAction: "dismiss")
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "dismiss")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        addOrRemoveDoneButtonGivenTraitCollection(controller: self, withDoneButtonAction: "dismiss")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier, let segueIdentifer = SegueIdentifiers(rawValue: identifier) else {fatalError("Invalid segue identifier \(segue.identifier ?? "nil")")}
        
        switch segueIdentifer
        {
        case .AddPilotSegue:
            let addPilot = segue.destination as? SignInPilotFromList
            addPilot?.delegate = dataModel
        
        case .AddSquadronCadetsSegue:
            let addCadets = segue.destination as? AddCadetsOrGuestsPopover
            addCadets?.typeOfPassengerBeingSignedIn = .cadet
    
        case .AddGuestsSegue:
            let addGuests = segue.destination as? AddCadetsOrGuestsPopover
            addGuests?.typeOfPassengerBeingSignedIn = .guest
            
        case .PilotCollectionViewSegue:
            break
            
        case .AddCadetsIndividually:
            break
        }
    }
    
    //MARK: - UITableViewController Methods
    private func flightActionSheet(message : String, for cell: UITableViewCell, handler: @escaping ((String) -> Void)) -> Void
    {
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        controller.popoverPresentationController?.sourceView = cell.contentView // fix #56
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        controller.addAction(cancel)

        for flightName in flightNames
        {
            let flightButton = UIAlertAction (title: flightName, style: .default){action in handler(flightName)}
            controller.addAction(flightButton)
        }

        self.present(controller, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath)
        switch cell?.textLabel?.text ?? ""
        {
            case "Sign in Flight":
                flightActionSheet(message: "Which flight do you want to sign in?", for: cell!) {
                        flightName in  dataModel.signInFlight(flightName)
                }

            case "Sign out Flight":
                flightActionSheet(message: "Which flight do you want to sign out?", for: cell!) {
                    flightName in dataModel.pilotAreaController?.signOutFlight(flightName)
                }

            case "Sign Out All Squadron Cadets":
                let clearCadetsAndGuests = UIAlertController(title: nil, message:"All squadron cadets will be signed out and removed from the list. This cannot be undone.", preferredStyle:.actionSheet)
                clearCadetsAndGuests.popoverPresentationController?.sourceView = cell!.contentView // fix #56

                let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
                clearCadetsAndGuests.addAction(cancel)
                
                let proceed = UIAlertAction(title: "Sign Out Squadron Cadets", style: .destructive){action in dataModel.pilotAreaController?.signOutSquadronCadets()}
                clearCadetsAndGuests.addAction(proceed)
                
                present(clearCadetsAndGuests, animated: true, completion: nil)

            default:
                break
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return dataModel.viewPreviousRecords ? 2 : 4        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        var numberOfRows = 0
        
        switch section
        {
            case 0:
            numberOfRows = dataModel.viewPreviousRecords ? 1 : 2
            
            case 1:
                numberOfRows = 2
            
            case 2:
                numberOfRows = 2
            
            case 3:
                numberOfRows = 1
            
            default:
            break
        }
        
        return numberOfRows
    }
}
