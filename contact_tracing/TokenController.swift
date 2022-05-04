//
//  TokenController.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/4/30.
//

// TODO: another controller. How to change ht
import Foundation
import CoreBluetooth
import UserNotifications
import UIKit

// Global static values
// uuid's generated from "https://www.uuidgenerator.net/version4"
public let serviceUUID = CBUUID.init(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
public let characteristicUUID = CBUUID.init(string:"34a30272-19e0-4900-a8e2-7d0bb0e23568")
public let peripheralName = "CT-Peripheral"

class MyService {
    private var uuid: CBUUID
    private var service: CBMutableService
    private var characteristic: MyCharacteristic?
    
    init(_ uuid: CBUUID) {
        self.uuid = uuid
        self.service = CBMutableService(type: uuid, primary:true)
        self.characteristic = nil
    }
    
    public func getService() -> CBMutableService {
        return self.service
    }
    
    public func getServiceUUID() -> CBUUID {
        return self.uuid
    }
    
    public func addCharacteristic(_ c: MyCharacteristic) {
        self.characteristic = c
        self.service.characteristics = [c.getCharacteristic()]
    }
}

class MyCharacteristic {
    private var uuid: CBUUID
    private var value: Data? = nil
    private var characteristic: CBMutableCharacteristic
    
    init(_ uuid: CBUUID) {
        self.uuid = uuid
        self.characteristic = CBMutableCharacteristic.init(type: uuid, properties: [.read, .write], value: self.value, permissions:[.writeable, .readable])
    }
    
    public func getCharacteristic() -> CBMutableCharacteristic {
        return self.characteristic
    }
    
    public func getCharacteristicUUID() -> CBUUID {
        return self.uuid
    }
    
    public func getCharacteristicValue() -> Data? {
        return self.value
    }
    
    public static func fromCBCharacteristic(_ c: CBCharacteristic) -> MyCharacteristic? {
        return MyCharacteristic(c.uuid)
    }
}

enum Command {
    case read(from: MyCharacteristic)
    case write(to: MyCharacteristic, value: Data)
    case readRSSI
//    case scheduleCommands(commands: [Command], withTimeInterval: TimeInterval, repeatCount: Int) //TODO
}

// We dropped 32bit support, so UInt = UInt64, and is converted to NSNumber when saving to PLists
//typealias UserToken = UInt
//
//extension UserToken {
//    func data() -> Data {
//        return Swift.withUnsafeBytes(of: self) { Data($0) }
//    }
//    init?(data :Data) {
//        var value: UserToken = 0
//        guard data.count >= MemoryLayout.size(ofValue: value) else { return nil }
//        _ = Swift.withUnsafeMutableBytes(of: &value, { data.copyBytes(to: $0)} )
//        self = value
//    }
//    static func next() -> UserToken {
//        // https://github.com/apple/swift-evolution/blob/master/proposals/0202-random-unification.md#random-number-generator
//        // This is cryptographically random
//        return UserToken(UInt64.random(in: 0 ... UInt64.max))
//    }
//}

let KeepMyIdsInterval: TimeInterval = 60*60*24*7*2 // 2 weeks = 14 days
let KeepPeerIdsInterval: TimeInterval = 60*60*24*7*2 // 2 weeks = 14 days

// TODO: check what files do here.
enum File: String {
    case myTokens
    case peerTokens
    func url() -> URL {
        // plist: simple key-value store in iOS: https://www.appypie.com/plist-property-list-swift-how-to
        // FileManager.default.urls(): find the user's documents directory isn't very memorable
        let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectoryUrl.appendingPathComponent("\(self.rawValue).plist")
    }
}

// TODO: check what IDs do here
typealias Tokens = [[UserToken: TimeInterval]]
extension Tokens {
    // 8Byte + 8Bytes = 16Bytes for one record.
    // You're going to see .. max 1k people in a day.
    // We want to keep records for 4 weeks.
    // max: 16B x 1k x 28 = 448kBytes
    static func load(from: File) -> Tokens {
        do {
            let data = try Data(contentsOf: from.url(), options: [])
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! Tokens
        } catch {
            print(error)
        }
        return Tokens()
    }
    func save(to: File) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            try data.write(to: to.url(), options: [])
        } catch {
            print(error)
        }
    }
    // a function that’s been marked as mutating can change any property within its enclosing value
    mutating func expire(keepInterval: TimeInterval) -> Bool {
        let count = self.count

        // Delete old entries
        let now = Date().timeIntervalSince1970
        self = self.filter({ (item) -> Bool in
            let val = item.values.first!
            return val + keepInterval > now  // expires
        })

        // Return if we removed expired items
        return count != self.count
    }
    mutating func append(_ userId: UserToken) {
        let next = [userId: Date().timeIntervalSince1970]
        self.append(next)
    }
    var last: UserToken {
        let item = self.last! // at least one item should exist in the array
        return item.keys.first!
    }
}

public class TokenController: NSObject {
    static var instance: TokenController!

    private let queue: DispatchQueue!
    private var peripheralManager: PeripheralManager!
    private var centralManager: CentralManager!
    private var started: Bool = false
    private var myTokens: Tokens!
    private var peerTokens: Tokens!
    private var backgroundTaskId: UIBackgroundTaskIdentifier?

    public static func didFinishLaunching() {
        instance = TokenController()
    }

    public static func start() {
        instance.peripheralManager.startAdvertising()
        instance.centralManager.startScan()
        

        // request user permission
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, error in
            print("granted: \(granted), error: \(String(describing: error))")
        }
    }

    public static func stop() {
        instance.peripheralManager.stopAdvertising()
        instance.centralManager.stopScan()
    }

    public override init() {
        self.queue = DispatchQueue(label: "TokenController")

        super.init()
        // load from different files
        self.myTokens = Tokens.load(from: .myTokens)
        _ = self.myTokens.expire(keepInterval: KeepMyIdsInterval)
        self.myTokens.append(UserToken.next()) // TODO only when some time has passed
        self.myTokens.save(to: .myTokens)

        self.peerTokens = Tokens.load(from: .peerTokens)
        if self.peerTokens.expire(keepInterval: KeepPeerIdsInterval) {
            self.peerTokens.save(to: .peerTokens)
        }
        
        let tokenCharacteristic = MyCharacteristic(characteristicUUID)
        let ctService = MyService(serviceUUID)
        ctService.addCharacteristic(tokenCharacteristic)

        // CW: TODO: clarify general read flow and write flow
        peripheralManager = PeripheralManager(peripheralName: peripheralName, queue: queue, service: ctService.getService())
            // CW: deleted [unowned self] because peripheralManager should always be around when closure finishes
            // CW: TODO: confirm why peripheral can go uninitialized --> is it the peripheralManager object that's passed in? But the type is CBCentral...
            .onReadClosure{[unowned self] (peripheral, tokenCharacteristic) in
                    return self.myTokens.last.data()
            }
            .onWriteClosure{[unowned self] (peripheral, tokenCharacteristic, data) in
                // CW: TODO: why the whole userID typee
                // CW: TODO: confirm where the data field comes from
                self.peerIds.append(data)
                self.peerIds.save(to: .peerIds)
                return true
            }
            
        centralManager = CentralManager(queue: queue, services: [ctService.getService()])
            // TODO: [check understanding] DidReadRSSI is only a function signature, the function body is defined here?
            .didReadRSSI({ [unowned self] peripheral, RSSI, error in
                print("peripheral=\(peripheral.shortId), RSSI=\(RSSI), error=\(String(describing: error))")

                guard error == nil else {
                    self.centralManager?.disconnect(peripheral)
                    return
                }
            })
//            // TODO: need to define similar call back function.
//            // TODO: CentralManager write itself's token to
//            .write(to: service, value: { [unowned self] peripheral in
//                    self.myTokens.last.data()
//            })
//            // TODO: how to call read()? Need CentralManager to add a callback function?
//            .read(from: .ReadWriteId)
            // TODO: Is this correct way to call back
            .didUpdateValue({ [unowned self] peripheral, ch, data, error in
                if let dat = data, let peerToken = UserToken(data: dat) {
                    log("Read Successful from \(peerToken)")
                    self.peerTokens.append(peerToken)
                    self.peerTokens.save(to: .peerIds)
                }
            })
            // TODO: need to disconnect? Or add cancel callback function
            .cancel(callback: { [unowned self] peripheral in
                    self.centralManager?.disconnect(peripheral)
            })
        
    }
    
}

