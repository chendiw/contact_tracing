//
//  MyPeripheralManager.swift
//  ble_peripheral
//
//  Created by Chendi Wu on 4/20/22.
//

import Foundation
import CoreBluetooth

class PeripheralManager: NSObject {
    var peripheralManager: CBPeripheralManager!
    
    private var started: Bool = false
    private let peripheralName: String
    private let queue: DispatchQueue
    private let service: CBMutableService
    
    private var onReadClosure: ((CBCentral, MyCharacteristic) -> Data?)?
    private var onWriteClosure: ((CBCentral, MyCharacteristic, Data) -> Bool)?
    
    // service defined in MainBackend, peripheralName is the local name of a Peripheral
    init(peripheralName: String, queue: DispatchQueue, service: CBMutableService) {
        self.peripheralName = peripheralName
        self.service = service
        self.queue = queue
        super.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    }
    
    func startAdvertising() {
        guard self.peripheralManager.state == .poweredOn else {print("Peripheral Manager not powered on")
            return
        }
        
        // clear all previous services
        self.peripheralManager.removeAllServices()
        
        // add new service upon start
        self.peripheralManager.add(self.service)
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: peripheralName,
            CBAdvertisementDataServiceUUIDsKey: [self.service.uuid],
//            CBAdvertisementDataOverflowServiceUUIDsKey: self.service.uuid //if running peripheral in background mode, service uuid can only be discovered in the overflow area
        ]
        
        self.peripheralManager.startAdvertising(advertisementData)
        started = self.peripheralManager.isAdvertising
    }
    
    func stopAdvertising() {
        self.peripheralManager.stopAdvertising()
        started = self.peripheralManager.isAdvertising
    }
    
    func onReadClosure(_ callback: @escaping (CBCentral, MyCharacteristic) -> Data?) -> PeripheralManager {
        self.onReadClosure = callback
        return self
    }

    func onWriteClosure(callback: @escaping (CBCentral, MyCharacteristic, Data) -> Bool) -> PeripheralManager {
        self.onWriteClosure = callback
        return self
    }
}

// TODO: Does the PeripheralManager write to the charicteristic.value?
extension PeripheralManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if self.peripheralManager.state == .poweredOn {
            print("Peripheral powered on!")
//            startAdvertising()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil {
            print("Peripheral Manager failed to start advertising: \(String(describing: error))")
        } else {
            print("Peripheral Manager started advertising!")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let requestedMyChar = MyCharacteristic.fromCBCharacteristic(request.characteristic) else {
            print("Failed conversion to MyCharacteristic in read request")
            return
        }
        let requestedCharValue = requestedMyChar.getCharacteristicValue()

        // check if request offset is longer than characteristic value
        if request.offset > requestedCharValue?.count ?? -1 {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        
        if let data = onReadClosure!(request.central, requestedMyChar) {
            request.value = data
            peripheral.respond(to: request, withResult: .success)
            return
        }
        
        peripheral.respond(to: request, withResult: .unlikelyError)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        if requests.count == 0 {
            return
        }
        for request in requests {
            guard let requestedMyChar = MyCharacteristic.fromCBCharacteristic(request.characteristic)else {
                print("Failed conversion to MyCharacteristic in write request")
                return
            }
            guard let requestValue = request.value else {
                print("No value from write request.")
                return
            }
            if onWriteClosure!(request.central, requestedMyChar, requestValue) {
                peripheral.respond(to: requests[0], withResult: .success)
                break
            }
        }
        peripheral.respond(to: requests[0], withResult: .unlikelyError)
    }
}
