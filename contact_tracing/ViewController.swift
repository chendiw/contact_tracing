//
//  ViewController.swift
//  ble_test
//
//  Created by Jiani Wang on 2022/4/22.
//

import UIKit
import CoreBluetooth


//class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
//    var centralManager: CBCentralManager!  // ! means this is an unwrapped optional variable and if we refer to it later we can check for null-safety.
//    var myPeripheral: CBPeripheral!
//
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {  // need to rewrite this fuction.
//        if central.state == CBManagerState.poweredOn {
//            print("BLE powered on") // Turned on
//            central.scanForPeripherals(withServices: nil, options: nil)
//        }
//        else {
//            print("Something wrong with BLE")
//            // Not on, but can have different issues
//        }
//    }
//
//    // rewrite some function: didDiscover delegate method
//    // This function is to define the behavior that find a peripheral
//    // Identify our peripheral by name, UUID, manufacturer ID, or basically anything that is part of the advertisement data
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        if let pname = peripheral.name {
//            if pname == "Jiani's" {
//                self.centralManager.stopScan()
//
//                self.myPeripheral = peripheral
//                self.myPeripheral.delegate = self
//
//                self.centralManager.connect(peripheral, options: nil)
//            }
//        }
//    }
//
//    // Once the connection is establishd, call this method.
//    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        self.myPeripheral.discoverServices(nil)  // ask peripheral to provide information about service
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view.
//        centralManager = CBCentralManager(delegate: self, queue: nil)
//    }
//
//}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("Start Bluetooth")
        TokenController.didFinishLaunching()
        TokenController.start()
    }
} 
