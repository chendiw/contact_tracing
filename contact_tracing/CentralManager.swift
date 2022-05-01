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
    
//    var centralDidUpdateStateCallback: ((CBManagerState) -> Void)?
    
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
    
    // TODO: think more about callback functions.
    func didUpdateValue(_ callback :@escaping CharacteristicDidUpdateValue) -> CentralManager {
        didUpdateValue = callback
        return self
    }

    func didReadRSSI(_ callback: @escaping DidReadRSSI)-> CentralManager {
        didReadRSSI = callback
        return self
    }

    func addPeripheral(_ peripheral: CBPeripheral) {
        let services = services.map {$0.getService()}
        let p = Peripheral(peripheral: peripheral, queue: queue, services: services, characteristicValue: didUpdateValue, rssiValue: didReadRSSI)
        peripherals[peripheral.identifier] = p
    }
    
    func disconnect(_ peripheral: Peripheral) {
        centralManager.cancelPeripheralConnection(peripheral.peripheral)
    }

    func disconnectAllPeripherals() {
        peripherals.forEach { _, peripheral in
            centralManager.cancelPeripheralConnection(peripheral.peripheral)
        }
    }

}

// extension: write necessary function of Delegete.
extension CentralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && running {
            startScan()
        }
//        centralDidUpdateStateCallback?(central.state)  // TODO: check whether do we need this. Do we need to
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let p = peripherals[peripheral.identifier] {
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
            // TODO: class Periperal need to have a public function `discoverServices()`. The centralManager can not see class CBPeripheral directly.
            p.discoverServices(cbuuids)  // TODO: check how to call this function. (Can we directly call Per
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals.removeValue(forKey: peripheral.identifier)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    }
    
}
