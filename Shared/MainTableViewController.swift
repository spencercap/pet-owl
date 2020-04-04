//
//  MainTableViewController.swift
//  SwiftStarter
//
//  Created by Stephen Schiffli on 10/16/15.
//  Copyright © 2015 MbientLab Inc. All rights reserved.
//

import UIKit
import MetaWear
import MetaWearCpp
import MBProgressHUD
import BoltsSwift

class MainTableViewController: UITableViewController, ScanTableViewControllerDelegate {
    var devices: [MetaWear] = []
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        updateList()
    }
    
    func updateList() {
        MetaWearScanner.shared.retrieveSavedMetaWearsAsync().continueOnSuccessWith(.mainThread) {
            self.devices = $0
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Scan table view delegate
    
    func scanTableViewController(_ controller: ScanTableViewController, didSelectDevice device: MetaWear) {
        navigationController?.popViewController(animated: true)
        
        let hud = MBProgressHUD.showAdded(to: UIApplication.shared.keyWindow!, animated: true)
        hud.label.text = "Programming..."
        device.initialDeviceSetup().continueWith(.mainThread) {
            hud.mode = .text
            hud.label.text = $0.error?.localizedDescription ?? "Success"
            hud.hide(animated: true, afterDelay: 2.5)
            self.updateList()
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell : UITableViewCell!
        if indexPath.row < devices.count {
            cell = tableView.dequeueReusableCell(withIdentifier: "MetaWearCell", for: indexPath)
            let cur = devices[indexPath.row]
            let name = cell.viewWithTag(1) as! UILabel
            name.text = cur.name
            
            let uuid = cell.viewWithTag(2) as! UILabel
            uuid.text = cur.mac
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "NoDeviceCell", for: indexPath)
        }
        return cell
    }
    

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < devices.count {
            performSegue(withIdentifier: "ViewDevice", sender: devices[indexPath.row])
        } else {
            performSegue(withIdentifier: "AddNewDevice", sender: nil)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.ƒ
        return indexPath.row < devices.count
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            devices[indexPath.row].eraseDevice()
            devices.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        if let scanController = segue.destination as? ScanTableViewController {
            scanController.delegate = self
        } else if let deviceController = segue.destination as? DeviceViewController {
            deviceController.device = (sender as! MetaWear)
        }
    }
}

extension MetaWear {
    // Call once to setup a device
    func initialDeviceSetup(temperaturePeriodMsec: UInt32 = 1000) -> Task<()> {
        return eraseDevice().continueWithTask { _ -> Task<Task<MetaWear>> in
            return self.connectAndSetup()
        }.continueOnSuccessWithTask { _ -> Task<()> in
            let state = DeviceState(temperaturePeriodMsec: temperaturePeriodMsec)
            return state.setup(self)
        }.continueWithTask { t -> Task<()> in
            if !t.faulted {
                self.remember()
            } else {
                self.eraseDevice()
            }
            return t
        }
    }
    
    // If you no longer need a device call this
    @discardableResult
    func eraseDevice() -> Task<MetaWear> {
        // Remove the on-disk state
        try? FileManager.default.removeItem(at: uniqueUrl)
        // Drop the device from the MetaWearScanner saved list
        forget()
        // Reset and clear all data from the device
        return connectAndSetup().continueOnSuccessWithTask {
            self.clearAndReset()
            return $0
        }
    }
}
