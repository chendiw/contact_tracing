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
    private let services: [MyService]
    private var discoveredService: CBService?
    private var discoveredCharacteristic: CBCharacteristic?
    private var commands: [Command]
    private let characteristicCallback: CharacteristicDidUpdateValue?  // Jiani: this is a typealias defined in CentralManager.swift
    private let rssiCallback: DidReadRSSI? // this is also a type alias
    
    var id: UUID {
        return self.peripheral.identifier
    }

    init(peripheral: CBPeripheral, queue: DispatchQueue, services: [MyService], commands: [Command], characteristicCallback: CharacteristicDidUpdateValue?, rssiCallback: DidReadRSSI?) {
            self.peripheral = peripheral
            self.queue = queue
            self.services = services
            self.commands = commands
            self.characteristicCallback = characteristicCallback
            self.rssiCallback = rssiCallback

            super.init()
            self.peripheral.delegate = self
    }
    
    func executeCommand(_ command: Command) {
        switch command {
        case .read(let from):
            self.peripheral.readValue(for: from.getCharacteristic())
        case .write(let value):
            self.peripheral.writeValue(value!, for: toCBCharacteristic()!, type: CBCharacteristicWriteType.withResponse) //withresponse to log whether write is sucessful to backend
        case .readRSSI:
            self.peripheral.readRSSI()
//        case .scheduleCommands(let commands, let withTimeInterval, let repeatCount):
//            break
        case .cancel(callback: let callback):
            callback(self)
        }
    }
    
    func nextCommand() -> Command? {
        print("I'm confused")
        print("commands I have: \(commands)")
        if commands.count == 0 {
            print("No next command.")
            return nil
        }
        commands.removeFirst()
        return commands.first
    }
    
    // called in centralManager:didConnectPeripheral
    func discoverMyService() {
        var serviceUUIDs: [CBUUID] = []
        for s in self.services {
            serviceUUIDs.append(s.getServiceUUID())
        }
        // serviceUUIDs should contain only 1 elem: our service uuid
        assert(serviceUUIDs.count == 1)
        self.peripheral.discoverServices(serviceUUIDs)
    }
    
    func toCBCharacteristic() -> CBCharacteristic? {
        let targetServiceUUID = CBUUID(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
        let targetCharUUID = CBUUID(string: "34a30272-19e0-4900-a8e2-7d0bb0e23568")

        if let services = self.peripheral.services {
            let foundService = services.first { service in
                targetServiceUUID.isEqual(service.uuid)
            }
            if let c12cs = foundService?.characteristics {
                return c12cs.first { c in
                    targetCharUUID.isEqual(c.uuid)
                }
            }
        }
        return nil
    }
}

extension Peripheral: CBPeripheralDelegate {
    
    // called after peripheral.discoverServices
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print(error ?? "discover service error")
        }
        
        guard let discoveredServices = peripheral.services else { print("No services found in peripheral")
            return
        }
        for discoveredService in discoveredServices {
            // return all characteristics of the service
            peripheral.discoverCharacteristics(nil, for: discoveredService)
        }
    }
    
    // called after peripheral:discoverCharacteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print(error ?? "discover characteristic error")
        }
        
        guard let discoveredCharacteristics = service.characteristics else { print("No characteristics found for service")
            return
        }
        
        assert(discoveredCharacteristics.count == 1)
        for _ in discoveredCharacteristics {
            executeCommand(nextCommand()!)
        }
    }
    
    // called after peripheral:readValue
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error ?? "read characteristic value error")
        }
        
        guard let characteristicValue = characteristic.value else { print("Error reading characteristic value")
            return
        }
        
        // use callback characteristicCallback to make characteristicValue accessible to centralManager
        characteristicCallback?(self, characteristic as! CBMutableCharacteristic, characteristicValue, error)
        executeCommand(nextCommand()!)
    }
    
    // called after peripheral:readRSSI
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error != nil {
            print(error ?? "read RSSI error")
            return
        }
        
        // use callback rssiCallback to make RSSI accessible to centralManager
        rssiCallback?(self, RSSI, error)
        executeCommand(nextCommand()!)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error ?? "write to characteristic error")
            return
        }
        executeCommand(nextCommand()!)
    }
}
