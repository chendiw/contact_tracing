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
    case write(to: MyCharacteristic, value: Data?)
    case readRSSI
    case cancel(callback: (Peripheral) -> Void)
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

// Two files storing myTEKs and peerTokens
// myTEKs: i (computed from ENIntervalNumber) -> TEK_i (14 pairs)
// peerTokens: ENIntervalNumber -> [Tokenobject{Bluetooth payload, RSSI, GPS location}] (144*14=2016 pairs)
enum File: String {
    case myTEKs
    case peerTokens
    
    var rawValue: String {
        switch self {
        case .myTEKs: return "myTEKs"
        case .peerTokens: return "peerTokens"
        }
    }
    
    static func createFile(url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else {
            print("\(url) already exists!")
            return
        }
        let emptyData:[String:String] = ["":""]
        let plistContent = NSDictionary(dictionary:emptyData)
        let success:Bool = plistContent.write(toFile: url.path, atomically: true)
        if success {
            print("File: \(url) creation successful")
        } else {
            print("Error creating file \(url)")
        }
    }
    
    func url() -> URL {
        // plist: simple key-value store in iOS: https://www.appypie.com/plist-property-list-swift-how-to
//        let fm = FileManager.default
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let documentDirectoryUrl = NSURL(fileURLWithPath: documentDirectory)
        let fileUrl = documentDirectoryUrl.appendingPathComponent(self.rawValue)!.appendingPathExtension("plist")
        return fileUrl
    }
}

class TokenObject: NSObject, NSCoding {
    var payload: Data
    var rssi: NSNumber
// TODO: Get gps location per ENInterval
//    let gps:
    
    init?(payload: Data, rssi: NSNumber) {
        self.payload = payload
        self.rssi = rssi
    }
    
    required convenience init?(coder: NSCoder) {
        guard let payload = coder.decodeObject(forKey: "payload") as? Data,
              let rssi = coder.decodeObject(forKey: "rssi") as? NSNumber
        else {
            return nil
        }
        self.init(payload: payload, rssi: rssi)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(self.payload, forKey: "payload")
        coder.encode(self.rssi, forKey: "rssi")
    }
    
    var dictionary: [String: Any] {
        return [
            "payload": self.payload,
            "rssi": self.rssi
        ]
    }
    
//    var data: Data {
//        return (try? JSONSerialization.data(withJSONObject: dictionary)) ?? Data()
//    }
//
//    var json: String {
//        return String(data: data, encoding: .utf8) ?? String()
//    }
}

typealias TokenList = [TokenObject]
extension TokenList {
    // Each token composed of:
    // - Rolling Proximity Identifier: AES-128 encrypted (16 bytes)
    // - Associated Encrypted Metadata: AES-CTR encrypted (16 bytes)
    // Assume max 1k contacts per day
    // Store tokens for 14 days
    // Max file size: 32 x 1k x 14 = 448k bytes
    
    static func load(from: File) -> TokenList {
        do {
            let data = try Data(contentsOf: from.url(), options: [])
            return try  NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! TokenList
        } catch {
            print(error)
        }
        return TokenList()
    }
    
    func save(to :File) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            try data.write(to: to.url(), options: [])
        } catch {
            print(error)
        }
    }
}

typealias ENInterval = TimeInterval
extension ENInterval {
    func value() -> Int {
        return Int((Date().timeIntervalSince1970) / (10 * 60))
    }
}

//typealias Tokens = [[UserToken: TimeInterval]]
//extension Tokens {
//    // Each token composed of:
//    // - Rolling Proximity Identifier: AES-128 encrypted (16 bytes)
//    // - Associated Encrypted Metadata: AES-CTR encrypted (16 bytes)
//    // Assume max 1k contacts per day
//    // Store tokens for 14 days
//    // Max file size: 32 x 1k x 14 = 448k bytes
//
//    static func load(from: File) -> Tokens {
//        do {
//            let data = try Data(contentsOf: from.url(), options: [])
//            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! Tokens
//        } catch {
//            print(error)
//        }
//        return Tokens()
//    }
//
//    func save(to: File) {
//        do {
//            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
//            try data.write(to: to.url(), options: [])
//        } catch {
//            print(error)
//        }
//    }
//    // a function that’s been marked as mutating can change any property within its enclosing value
//    mutating func expire(keepInterval: TimeInterval) -> Bool {
//        let count = self.count
//
//        // Delete old entries
//        let now = Date().timeIntervalSince1970
//        self = self.filter({ (item) -> Bool in
//            let val = item.values.first!
//            return val + keepInterval > now  // expires
//        })
//
//        // Return if we removed expired items
//        return count != self.count
//    }
//    mutating func append(_ userId: UserToken) {
//        let next = [userId: Date().timeIntervalSince1970]
//        self.append(next)
//    }
//    var last: UserToken {
//        let item = self.last! // at least one item should exist in the array
//        return item.keys.first!
//    }
//}


// Bluetooth token exchange controller
public class TokenController: NSObject {
    static var instance: TokenController!

    private let queue: DispatchQueue!
    private var peripheralManager: PeripheralManager!
    private var centralManager: CentralManager!
    private var started: Bool = false
    private var myTokens: TokenList!
    private var peerTokens: TokenList!
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
        // init token files
        File.createFile(url: File.myTEKs.url())
        File.createFile(url: File.peerTokens.url())
        
        // load from different files
        self.myTokens = TokenList.load(from: .myTEKs)
//        _ = self.myTokens.expire(keepInterval: KeepMyIdsInterval)
//        self.myTokens.append(UserToken.next()) // TODO: only when some time has passed
        self.myTokens.save(to: .myTEKs)

        self.peerTokens = TokenList.load(from: .peerTokens)
//        if self.peerTokens.expire(keepInterval: KeepPeerIdsInterval) {
//            self.peerTokens.save(to: .peerTokens)
//        }
        
        // object of characteristic nad service
        let tokenCharacteristic = MyCharacteristic(characteristicUUID)
        let ctService = MyService(serviceUUID)
        ctService.addCharacteristic(tokenCharacteristic)

        // CW: TODO: clarify general read flow and write flow
        peripheralManager = PeripheralManager(peripheralName: peripheralName, queue: queue, service: ctService.getService())
            // CW: deleted [unowned self] because peripheralManager should always be around when closure finishes
            // CW: TODO: confirm why peripheral can go uninitialized --> is it the peripheralManager object that's passed in? But the type is CBCentral...
            .onReadClosure{[unowned self] (peripheral, tokenCharacteristic) in
                return self.myTokens[-1].payload
//                    return self.myTokens.last.data()
            }
            .onWriteClosure{[unowned self] (peripheral, tokenCharacteristic, data) in
                // CW: TODO: why the whole userID typee
                // CW: TODO: confirm where the data field comes from
//                self.peerIds.append(data)
                self.peerTokens.save(to: .peerTokens)
                return true
            }
            
        centralManager = CentralManager(services: [ctService], queue: queue)
            // TODO: what does [unowned self] do?
            .didReadRSSICallback({ [unowned self] peripheral, RSSI, error in
                print("peripheral=\(peripheral.id), RSSI=\(RSSI), error=\(String(describing: error))")
                guard error == nil else {
                    self.centralManager?.disconnect(peripheral)
                    return
                }
            })
            // Ask periperal to write it's value to the characteristic
            .addCommandCallback(
                command: .write(to: tokenCharacteristic, value:
                                    self.myTokens[-1].payload
                ))
            .addCommandCallback(
                command: .read(from: tokenCharacteristic))
//
            .didUpdateValueCallback({ [unowned self] peripheral, ch, data, error in
//                if let dat = data, let peerToken = UserToken(data: dat) {
                if let dat = data, let peerToken = TokenObject(payload: dat, rssi: NSNumber.init(value: 0)) {
                    print("Read Successful from \(peerToken)")
                    self.peerTokens.append(peerToken)
                    self.peerTokens.save(to: .peerTokens)
                }
            })
            // TODO: need to disconnect? Or add cancel callback function
            .addCommandCallback(
                command: .cancel(callback: { [unowned self] peripheral in
                    self.centralManager?.disconnect(peripheral)
                }))
            
        
    }
    
}

