//
//  MyPeripheralManager.swift
//  ble_peripheral
//
//  Created by Chendi Wu on 4/20/22.
//

import Foundation
import CoreBluetooth

// Generated from "https://www.uuidgenerator.net/version4"
let serviceUUID = CBUUID.init(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
let service = CBMutableService(type: serviceUUID, primary:true)
let characteristicUUID = CBUUID.init(string:"34a30272-19e0-4900-a8e2-7d0bb0e23568")
// Temporarily set both property and permission to "read/write"
let characteristic = CBMutableCharacteristic.init(type:characteristicUUID, properties: [.read, .write], value: nil, permissions:[.writeable, .readable])

class PeripheralManager: NSObject {
    let peripheralManager: CBPeripheralManager!
    
    private var started: Bool = false
    private let peripheralName: String
    private let queue: DispatchQueue
    private let service: CBMutableService
    
    // service defined in MainBackend, peripheralName is the local name of a Peripheral
    init(peripheralName: String, queue: DispatchQueue, service: CBMutableService) {
        self.peripheralName = peripheralName
        self.service = service
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    }
    
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {print("Peripheral Manager not powered on")}
        
        // clear all previous services
        peripheralManager.removeAllServices()
        
        // add new service upon start
        peripheralManager.add(self.service)
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: peripheralName,
            CBAdvertisementDataServiceUUIDsKey: self.service.uuid,
            CBAdvertisementDataOverflowServiceUUIDsKey: self.service.uuid //if running peripheral in background mode, service uuid can only be discovered in the overflow area
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        started = peripheralManager.isAdvertising
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        started = peripheralManager.isAdvertising
    }

}

extension PeripheralManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if self.peripheralManager.state == .poweredOn {
            print("Peripheral powered on!")
            
            service.characteristics = [characteristic]
            startAdvertising()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil {
            print("Peripheral Manager failed to start advertising: \(String(describing: error))")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let requestedCharID = request.characteristic.uuid
        if requestedCharID != characteristicUUID {
            print("Requesting characteristic uuid unmatch!")
        }
        // check if request offset is longer than characteristic value
        if request.offset > characteristic.value?.count ?? -1 {
            peripheral.respond(to: request, withResult: .invalidOffset)
        }
        request.value = characteristic.value
        peripheral.respond(to: request, withResult: .success)
    }
}
