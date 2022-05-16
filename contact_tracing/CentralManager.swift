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
    private var services: [MyService] = []  // TODO: Here uses the same type as periperal
    private var queue: DispatchQueue
    private var running: Bool = false // whether the central manager has started?
    private var commands: [Command] = []
    
    private var didUpdateValue: CharacteristicDidUpdateValue!
    private var didReadRSSI: DidReadRSSI!
    
    var centralDidUpdateStateCallback: ((CBManagerState) -> Void)?
    
    init(services: [MyService], queue: DispatchQueue){
        self.services = services
        self.queue = queue
        super.init()
        let options = [
            CBCentralManagerOptionShowPowerAlertKey: 1,
            CBCentralManagerOptionRestoreIdentifierKey: "CentralManager"
        ] as [String: Any]
        centralManager = CBCentralManager(delegate: self, queue: queue, options: options)  // self need to be the CBCentralManagerDelegate type
    }
    
    func restartScan() {
        // TODO: check do we need this function
    }
    
    func startScan() {
        while centralManager.state != .poweredOn {
        }
        print("Central Manager powered on!")
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: false as NSNumber]
        let cbuuids: [CBUUID] = services.map { $0.getServiceUUID() }
        centralManager.scanForPeripherals(withServices: cbuuids, options: options)
        running = true
        return
    }
    
    func stopScan() {
        centralManager.stopScan()
        running = false
    }
    
    func didUpdateValueCallback(_ callback :@escaping CharacteristicDidUpdateValue) -> CentralManager {
        didUpdateValue = callback
        return self
    }

    func didReadRSSICallback(_ callback: @escaping DidReadRSSI)-> CentralManager {
        didReadRSSI = callback
        return self
    }
    
    func addCommandCallback(command: Command) -> CentralManager {  // support chainning call
        self.commands.append(command)
        return self
    }

    func addPeripheral(_ peripheral: CBPeripheral) {
        let p = Peripheral(peripheral: peripheral, queue: queue, services: services, commands: commands, characteristicCallback: didUpdateValue, rssiCallback: didReadRSSI)
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
//        while (true) {
            if central.state == .poweredOn {
                startScan()
            }
            centralDidUpdateStateCallback?(central.state)
            return
//        }
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
        if let p = p {
            p.discoverMyService()
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
