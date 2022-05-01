//
//  CentralManager.swift
//  ble_test
//
//  Created by Jiani Wang on 2022/4/24.
//

import Foundation
import CoreBluetooth

// typealias: input type and output type of a function
typealias CharacteristicDidUpdateValue = (Peripheral, CBMutableCharacteristic, Data?, Error?) -> Void
typealias DidReadRSSI = (Peripheral, NSNumber, Error?) -> Void


class CentralManager: NSObject {  // object-c subclass?
    private var centralManager: CBCentralManager!
    private var peripherals: [UUID: Peripheral] = [:]  // dict
    private let services: [Service] = []  // TODO: Here uses the same type as periperal
    private var queue: DispatchQueue
    private var running: Bool = false // whether the central manager has started?
    
    private var didUpdateValue: CharacteristicDidUpdateValue!
    private var didReadRSSI: DidReadRSSI!
    
    init(services: [Service]){  // TODO: use CBService instead of service
        self.services = services
        super.init()
        let options = [
            CBCentralManagerOptionShowPowerAlertKey: 1,
            CBCentralManagerOptionRestoreIdentifierKey: "CentralManager"
        ] as [String: Any]
        centralManager = CBCentralManager(delegate: self, queue: queue, options: options)  // self need to be the CBCentralManagerDelegate type
    }
    
    func start() {
        running = true
        startScan()
    }
    
    func stop() {
        stopScan()
        running = false
    }
    
    func restartScan() {
        // TODO: check do we need this function
    }
    
    private func startScan() {
        if centralManager.state != .poweredOn {
            return
        }
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: false as NSNumber]
        let cbuuids: [CBUUID] = services.map { $0.getCBUUID() }
        centralManager.scanForPeripherals(withServices: cbuuids, options: options)
    }
    
    private func stopScan() {
        centralManager.stopScan()
    }
    
    // TODO: check following functions
    func didUpdateValue(_ callback :@escaping CharacteristicDidUpdateValue) -> CentralManager {
        didUpdateValue = callback
        return self
    }

    func didReadRSSI(_ callback: @escaping DidReadRSSI)-> CentralManager {  // TODO: check extra argument
        didReadRSSI = callback
        return self
    }

    func disconnect(_ peripheral: Peripheral) {
        centralManager.cancelPeripheralConnection(peripheral.peripheral)
    }

    func disconnectAllPeripherals() {
        peripherals.forEach { _, peripheral in
            centralManager.cancelPeripheralConnection(peripheral.peripheral)
        }
    }

    func addPeripheral(_ peripheral: CBPeripheral) {
        let services = services.map {$0.getService()}
        let p = Peripheral(peripheral: peripheral, queue: queue, services: services, characteristicValue: didUpdateValue, rssiValue: didReadRSSI)
        peripherals[peripheral.identifier] = p
    }
}

// extension: write necessary function of Delegete.
extension CentralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && running {
            startScan()
        }
//        centralDidUpdateStateCallback?(central.state)  // TODO: check whether do we need this
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let p = peripherals[peripheral.identifier] {
            // We read RSSI after connect, and didDiscover shouldn't be called again because of "CBCentralManagerScanOptionAllowDuplicatesKey: false",
            // but still sometimes this is called, and since we know RSSI fluctuates, it's better to measure many times.
            didReadRSSI(p, RSSI, nil)  // TODO: check what RSSI is
        }

        if peripherals[peripheral.identifier] != nil {
            print("iOS Peripheral \(peripheral.identifier) has been discovered already")
            return
        }
        addPeripheral(peripheral)
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let p = peripherals[peripheral.identifier]
        let cbuuids = services.map{$0.getCBUUID()}
        if let p = p {
            // TODO: class Periperal need to have a public function `discoverServices()`
            p.discoverServices(cbuuids)  // TODO: check how to call this function. (Can we directly call Per
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals.removeValue(forKey: peripheral.identifier)
        startLongSession(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        endLongSession(peripheral)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    }
    
}
