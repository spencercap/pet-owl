//
//  ScanViewController.swift
//  MetaWearApiTest
//
//  Created by Stephen Schiffli on 10/18/16.
//  Copyright © 2016 MbientLab. All rights reserved.
//

import Cocoa
import MetaWear
import MetaWearCpp

class ScanViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView!
    
    var scannerModel: ScannerModel!

    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.target = self
        tableView.doubleAction = #selector(ScanViewController.tableViewDoubleClick(sender:))
        scannerModel = ScannerModel(delegate: self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        scannerModel.isScanning = true
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        scannerModel.isScanning = false
    }
    
    
    
    // ~~~ VOS code ~~~
    
    @IBAction func streamStart(_ sender: Any) {
        print("stream start")
        
        // TODO figure out how get correct index of clicked row, but for now assume theres only 1 device
        // let index = tableView.clickedRow
        // print(index)
        let index = 0
        
        // some LED indicator
        let device = scannerModel.items[index].device
        guard !device.isConnectedAndSetup else {
            device.flashLED(color: .blue, intensity: 1.0, _repeat: 5)
            
            
            // start stream data
            let board = device.board
            
            mbl_mw_sensor_fusion_set_mode(board, MBL_MW_SENSOR_FUSION_MODE_NDOF)
            mbl_mw_sensor_fusion_set_acc_range(board, MBL_MW_SENSOR_FUSION_ACC_RANGE_8G)
            mbl_mw_sensor_fusion_write_config(board)

            let signal = mbl_mw_sensor_fusion_get_data_signal(board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION);
            // print("signal")
            // print(signal)

            mbl_mw_datasignal_subscribe(signal, bridge(obj: self)) { (context, data) in
                let quaternion: MblMwQuaternion = data!.pointee.valueAs()
                print(quaternion)
            }
            
            mbl_mw_sensor_fusion_enable_data(board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION);
            mbl_mw_sensor_fusion_start(board);
            
            print("started")
            return
        }
        
    }
    
    @IBAction func streamStop(_ sender: Any) {
        print("stream stop")
        
        let index = 0
        
        // some LED indicator
        let device = scannerModel.items[index].device
        guard !device.isConnectedAndSetup else {
            device.flashLED(color: .red, intensity: 1.0, _repeat: 5)
            
            let board = device.board
            let signal = mbl_mw_acc_get_acceleration_data_signal(board)
            mbl_mw_acc_stop(board)
            mbl_mw_acc_disable_acceleration_sampling(board)
            mbl_mw_datasignal_unsubscribe(signal)
            
            return
        }
        
    }
    
    // ~~~~ END VOS ~~~
    
    
    // MARK: NSTableViewDelegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scannerModel.items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "MetaWearCell"), owner: nil) as? NSTableCellView else {
            return nil
        }
        let device = scannerModel.items[row].device
        let uuid = cell.viewWithTag(1) as! NSTextField
        uuid.stringValue = device.peripheral.identifier.uuidString
        
        if let rssiNumber = device.averageRSSI() {
            let rssi = cell.viewWithTag(2) as! NSTextField
            rssi.stringValue = String(Int(rssiNumber.rounded()))
        }
        
        let connected = cell.viewWithTag(3) as! NSTextField
        if device.isConnectedAndSetup {
            connected.stringValue = "Connected!"
            connected.isHidden = false
        } else if scannerModel.items[row].isConnecting {
            connected.stringValue = "Connecting..."
            connected.isHidden = false
        } else {
            connected.isHidden = true
        }
                
        let name = cell.viewWithTag(4) as! NSTextField
        name.stringValue = device.name
        
        let signal = cell.viewWithTag(5) as! NSImageView
        if let movingAverage = device.averageRSSI() {
            if movingAverage < -80.0 {
                signal.image = #imageLiteral(resourceName: "wifi_d1")
            } else if movingAverage < -70.0 {
                signal.image = #imageLiteral(resourceName: "wifi_d2")
            } else if movingAverage < -60.0 {
                signal.image = #imageLiteral(resourceName: "wifi_d3")
            } else if movingAverage < -50.0 {
                signal.image = #imageLiteral(resourceName: "wifi_d4")
            } else if movingAverage < -40.0 {
                signal.image = #imageLiteral(resourceName: "wifi_d5")
            } else {
                signal.image = #imageLiteral(resourceName: "wifi_d6")
            }
        } else {
            signal.image = #imageLiteral(resourceName: "wifi_not_connected")
        }
        
        return cell
    }
    
    @objc func tableViewDoubleClick(sender: AnyObject) {
        let device = scannerModel.items[tableView.clickedRow].device
        guard !device.isConnectedAndSetup else {
            device.flashLED(color: .red, intensity: 1.0, _repeat: 3)
            mbl_mw_debug_disconnect(device.board)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.tableView.reloadData()
            }
            return
        }
        scannerModel.items[tableView.clickedRow].toggleConnect()
        tableView.reloadData()
    }
}

extension ScanViewController: ScannerModelDelegate {
    func scannerModel(_ scannerModel: ScannerModel, didAddItemAt idx: Int) {
        tableView.reloadData()
    }
    
    func scannerModel(_ scannerModel: ScannerModel, confirmBlinkingItem item: ScannerModelItem, callback: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            callback(true)
            self.tableView.reloadData()
        }
    }
    
    func scannerModel(_ scannerModel: ScannerModel, errorDidOccur error: Error) {
    }
}
