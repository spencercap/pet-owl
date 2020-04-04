/**
 * ManualTests.swift
 * MetaWear-Tests
 *
 * Created by Stephen Schiffli on 12/28/17.
 * Copyright 2017 MbientLab Inc. All rights reserved.
 *
 * IMPORTANT: Your use of this Software is limited to those specific rights
 * granted under the terms of a software license agreement between the user who
 * downloaded the software, his/her employer (which must be your employer) and
 * MbientLab Inc, (the "License").  You may not use this Software unless you
 * agree to abide by the terms of the License which can be found at
 * www.mbientlab.com/terms.  The License limits your use, and you acknowledge,
 * that the Software may be modified, copied, and distributed when used in
 * conjunction with an MbientLab Inc, product.  Other than for the foregoing
 * purpose, you may not use, reproduce, copy, prepare derivative works of,
 * modify, distribute, perform, display or sell this Software and/or its
 * documentation for any purpose.
 *
 * YOU FURTHER ACKNOWLEDGE AND AGREE THAT THE SOFTWARE AND DOCUMENTATION ARE
 * PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY, TITLE,
 * NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL
 * MBIENTLAB OR ITS LICENSORS BE LIABLE OR OBLIGATED UNDER CONTRACT, NEGLIGENCE,
 * STRICT LIABILITY, CONTRIBUTION, BREACH OF WARRANTY, OR OTHER LEGAL EQUITABLE
 * THEORY ANY DIRECT OR INDIRECT DAMAGES OR EXPENSES INCLUDING BUT NOT LIMITED
 * TO ANY INCIDENTAL, SPECIAL, INDIRECT, PUNITIVE OR CONSEQUENTIAL DAMAGES, LOST
 * PROFITS OR LOST DATA, COST OF PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY,
 * SERVICES, OR ANY CLAIMS BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY
 * DEFENSE THEREOF), OR OTHER SIMILAR COSTS.
 *
 * Should you have any questions regarding your right to use this Software,
 * contact MbientLab via email: hello@mbientlab.com
 */

import XCTest
import BoltsSwift
@testable import MetaWear
@testable import MetaWearCpp

class ManualTests: XCTestCase {
    func connectNearest() -> Task<MetaWear> {
        let source = TaskCompletionSource<MetaWear>()
        MetaWearScanner.shared.startScan(allowDuplicates: true) { (device) in
            if let rssi = device.averageRSSI(), rssi > -50 {
                MetaWearScanner.shared.stopScan()
                device.logDelegate = ConsoleLogger.shared
                device.connectAndSetup().continueWith { t -> () in
                    if let error = t.error {
                        source.trySet(error: error)
                    } else {
                        source.trySet(result: device)
                    }
                }
            }
        }
        return source.task
    }
    
    func testCancelPendingConnection() {
        let connectExpectation = XCTestExpectation(description: "connecting")
        MetaWearScanner.shared.retrieveSavedMetaWearsAsync().continueOnSuccessWith { array in
            array.first
            
        }
        MetaWearScanner.shared.startScan(allowDuplicates: true) { (device) in
            if device.rssi > -50 {
                MetaWearScanner.shared.stopScan()
                print("Remove battery from device...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                    print("Connecting...")
                    device.connectAndSetup().continueWith { t in
                        t.result?.continueWith { t in
                            
                        }
                        XCTAssertTrue(t.cancelled)
                        connectExpectation.fulfill()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        print("Cancel Connection...")
                        device.cancelConnection()
                    }
                }
            }
        }
        wait(for: [connectExpectation], timeout: 60)
    }
    
    func testJumpToBootloader() {
        let connectExpectation = XCTestExpectation(description: "connecting")
        connectNearest().continueWith { t in
            guard let device = t.result else {
                return
            }
            mbl_mw_debug_jump_to_bootloader(device.board)
            connectExpectation.fulfill()
        }
        wait(for: [connectExpectation], timeout: 60)
    }
    
    func testiBeacon() {
        let connectExpectation = XCTestExpectation(description: "connecting")
        connectNearest().continueWith { t in
            guard let device = t.result else {
                return
            }
            device.flashLED(color: .green, intensity: 1.0, _repeat: 2)
            mbl_mw_ibeacon_enable(device.board)
            mbl_mw_ibeacon_set_major(device.board, 1111)
            mbl_mw_ibeacon_set_minor(device.board, 2222)
            mbl_mw_debug_disconnect(device.board)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                connectExpectation.fulfill()
            }
        }
        wait(for: [connectExpectation], timeout: 60)
    }
    
    func testWhitelist() {
        let connectExpectation = XCTestExpectation(description: "connecting")
        connectNearest().continueWith { t in
            guard let device = t.result else {
                return
            }
            device.flashLED(color: .green, intensity: 1.0, _repeat: 2)
            var address = MblMwBtleAddress(address_type: 0, address: (0x70, 0x9e, 0x38, 0x95, 0x01, 0x00))
            mbl_mw_settings_add_whitelist_address(device.board, 0, &address)
            mbl_mw_settings_set_ad_parameters(device.board, 418, 0, MBL_MW_BLE_AD_TYPE_CONNECTED_DIRECTED)
            // mbl_mw_settings_set_whitelist_filter_mode(device.board, MBL_MW_WHITELIST_FILTER_SCAN_AND_CONNECTION_REQUESTS)
            mbl_mw_debug_disconnect(device.board)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                connectExpectation.fulfill()
            }
        }
        wait(for: [connectExpectation], timeout: 60)
    }
    
    func testClearMacro() {
        let connectExpectation = XCTestExpectation(description: "connecting")
        connectNearest().continueWith { t in
            guard let device = t.result else {
                return
            }
            mbl_mw_macro_erase_all(device.board)
            mbl_mw_debug_reset_after_gc(device.board)
            mbl_mw_debug_disconnect(device.board)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                connectExpectation.fulfill()
            }
        }
        wait(for: [connectExpectation], timeout: 60)
    }
}
