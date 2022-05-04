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
    
    // service defined in MainBackend, peripheralName is the local name of a Peripheral
    init(peripheralName: String, queue: DispatchQueue, service: CBMutableService) {
        self.peripheralName = peripheralName
        self.service = service
        self.queue = queue
        super.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    }
    
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {print("Peripheral Manager not powered on")
            return
        }
        
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
    
    func onReadClosure(_ callback: @escaping (CBCentral, MyCharacteristic) -> Data?) -> PeripheralManager {
        self.onReadClosure = callback
        return self
    }

}

// TODO: Does the PeripheralManager write to the charicteristic.value?
extension PeripheralManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if self.peripheralManager.state == .poweredOn {
            print("Peripheral powered on!")
            
//            service.characteristics = [characteristic]
            startAdvertising()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil {
            print("Peripheral Manager failed to start advertising: \(String(describing: error))")
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
}
