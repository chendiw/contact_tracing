//
//  Peripheral.swift
//  ble_peripheral
//
//  Created by Chendi Wu on 4/23/22.
//

import Foundation
import CoreBluetooth



class Peripheral: NSObject {
    let peripheral: CBPeripheral!
    
    private let queue: DispatchQueue
    private let services: [CBService]
    private let characteristicCallback: CharacteristicDidUpdateValue?  // Jiani: this is a typealias defined in CentralManager.swift
    private let rssiCallback: DidReadRSSI? // this is also a type alias
    
    
    init(peripheral: CBPeripheral, queue: DispatchQueue, services: [CBService], characteristicValue: CharacteristicDidUpdateValue?, rssiValue: DidReadRSSI?) {
            self.peripheral = peripheral
            self.queue = queue
            self.services = services
//            self.characteristicCallback = characteristicValue
//            self.rssiCallback = rssiValue
            super.init()
            self.peripheral.delegate = self
    }
    diCover() {
        return peripheral.discoverServices()
    }
    
//    func writeValueToCharacteristic(value: Data, forCharacteristic ch: CBCharacteristic, type: CBCharacteristicWriteType) {
//        // do we need to check characteristic property write?
//        self.peripheral.writeValue(value, for: ch, type: type)
//    }
}

extension Peripheral: CBPeripheralDelegate {
    
    // called after centralManager:didConnectPeripheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("Error discovering services for: \(peripheral.name ?? "default name")")
        }
        
        guard let discoveredServices = peripheral.services else { print("No services found in peripheral") }
        for discoveredService in discoveredServices {
            peripheral.discoverCharacteristics(<#T##characteristicUUIDs: [CBUUID]?##[CBUUID]?#>, for: discoveredService)
        }
    }
    
    // called after peripheral:discoverCharacteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("Error discovering characteristics for: \(service.uuid)")
        }
        
        guard let discoveredCharacteristics = service.characteristics else { print("No characteristics found for service")}
        for discoveredCharacteristic in discoveredCharacteristics {
            // TODO: ReadValue then save to somewhere?? Save to peerTokens?
            peripheral.readValue(for: discoveredCharacteristic)
            peripheral.readRSSI()
        }
    }
    
    // called after peripheral:readValue
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("Error reading value from: \(characteristic.uuid)")
        }
        
        guard let characteristicValue = characteristic.value else { print("Error reading characteristic value") }
        
        // use callback characteristicCallback to make characteristicValue accessible to centralManager
        characteristicCallback?(self, characteristic, characteristicValue, error)
    }
    
    // called after peripheral:readRSSI
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error != nil {
            print("Error reading value from: \(peripheral.name ?? "default name")")
        }
        
        // use callback rssiCallback to make RSSI accessible to centralManager
        rssiCallback?(self, RSSI, error)
    }
}
