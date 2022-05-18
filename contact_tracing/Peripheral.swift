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
    private var timer: Timer?
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
        print("execute command: \(command), next command is ")
        switch command {
//            case .read:
//                self.peripheral.readValue(for: toCBCharacteristic()!)
            case .write(let value):
                while toCBCharacteristic() == nil{
                    print("Have not find the service yet. So the toCBCharacteristic() returns nil.")}
                self.peripheral.writeValue(value!, for: toCBCharacteristic()!, type: CBCharacteristicWriteType.withResponse) //withresponse to log whether write is sucessful to backend
            case .readRSSI:
                self.peripheral.readRSSI()
            case .scheduleCommands(let newCommands, let withTimeInterval, let repeatCount):
                        if repeatCount == 0 {
                            // Schedule finished
                            if let c = nextCommand() {
                                executeCommand(c)
                            }
                            return
                        }
                        print("Before timer")
                        timer = Timer(timeInterval: withTimeInterval, repeats: false) { [weak self] _ in
                            self?.queue.async {
                                // Finish off current commands
                                var nextCommands = self?.commands ?? []
                                // Add new scheduled ocmmands for this round
                                nextCommands.append(contentsOf: newCommands)
                                // Mark the next scheduling event
                                nextCommands.append(.scheduleCommands(commands: newCommands, withTimeInterval: withTimeInterval, repeatCount: repeatCount - 1))
                                self?.commands = nextCommands
                                print("Current iteration of commands: \(self?.commands)")
                                if let c = self?.nextCommand() {
                                    print("next command after schedule: \(c)")
                                    self?.executeCommand(c)
                                }
                            }
                        }
                        RunLoop.current.add(timer!, forMode: .common)
                        
//            //verion2:
//                        timer = Timer(timeInterval: withTimeInterval, repeats: false) { [weak self] _ in
//                            self?.queue.async {
//                                // Scheduled commands get executed first,
//                                var nextCommands = newCommands
//                                // and then continue the schedule,
//                                nextCommands.append(.scheduleCommands(commands: newCommands, withTimeInterval: withTimeInterval, repeatCount: repeatCount - 1))
//                                // and then continue the rest.
//                                nextCommands.append(contentsOf: self?.commands ?? [])
//                                self?.commands = nextCommands
//                                self?.nextCommand()
//                            }
//                        }
                        RunLoop.current.add(timer!, forMode: .common)
            case .cancel(callback: let callback):
                callback(self)
        }
    }
    
    func nextCommand() -> Command? {
        if commands.count == 0 {
            return nil
        }
        let curCommand = commands.first
        commands.removeFirst()
        return curCommand
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
                print("Find service in toCBCharacteristic() ")
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
        
        for _ in discoveredCharacteristics {
            if let c = nextCommand() {
                executeCommand(c)
            }
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
        
        print("in didUpdateValueFor: \(characteristicValue)")
        
        // use callback characteristicCallback to make characteristicValue accessible to centralManager
        characteristicCallback?(self, characteristic as! CBMutableCharacteristic, characteristicValue, error)
        if let c = nextCommand() {
            executeCommand(c)
        }
    }
    
    // called after peripheral:readRSSI
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error != nil {
            print(error ?? "read RSSI error")
            return
        }
        
        // use callback rssiCallback to make RSSI accessible to centralManager
        rssiCallback?(self, RSSI, error)
        if let c = nextCommand() {
            executeCommand(c)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print(error ?? "write to characteristic error")
            return
        }
        if let c = nextCommand() {
            executeCommand(c)
        }
    }
}
