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
//    private var commands: [Command] = []
    private let services: [CBService] = []  // TODO: Here uses the same type as periperal
    private var queue: DispatchQueue
    private var running: Bool = false // whether the central manager has started?
    
    init(services: [CBService]){  // TODO: use CBService instead of service
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
        let cbuuids: [CBUUID] = services.map { $0.toCBUUID() }
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
        let p = Peripheral(peripheral: peripheral, queue: queue, services: services, didUpdateValue: didUpdateValue, didReadRSSI: didReadRSSI)
        peripherals[peripheral.identifier] = p
    }
}

// extension: write necessary function i
extension CentralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && running {
            startScanning()
        }
        centralDidUpdateStateCallback?(central.state)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double {
            // It seems iOS13.3.1 also sends TxPower, eg. 12. But iOS12.4.5 does not...
            // and we can't "read" TxPower afterwards, so this is the time we should save it.
            didDiscoverTxPower(peripheral.identifier, txPower)
        }
        if let p = peripherals[peripheral.identifier] {
            // We read RSSI after connect, and didDiscover shouldn't be called again because of "CBCentralManagerScanOptionAllowDuplicatesKey: false",
            // but still sometimes this is called, and since we know RSSI fluctuates, it's better to measure many times.
            didReadRSSI(p, RSSI, nil)
        }

        if peripherals[peripheral.identifier] != nil {
            log("iOS Peripheral \(peripheral.shortId) has been discovered already")
            return
        }
        addPeripheral(peripheral)
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let p = peripherals[peripheral.identifier]
        if let p = p {
            p.discoverServices()
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
