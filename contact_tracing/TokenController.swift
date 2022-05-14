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
        let emptyData:[Int:[TokenObject]] = [-1:[]]
        let plistContent = NSDictionary(dictionary: emptyData)
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
    var eninterval: Int
    var payload: Data
    var rssi: NSNumber
// TODO: Get gps location per ENInterval
//    let gps:
    
    init?(eninterval: Int, payload: Data, rssi: NSNumber) {
        self.eninterval = eninterval
        self.payload = payload
        self.rssi = rssi
    }
    
    required convenience init?(coder: NSCoder) {
        guard let eninterval = coder.decodeObject(forKey: "ENInterval") as? Int,
              let payload = coder.decodeObject(forKey: "payload") as? Data,
              let rssi = coder.decodeObject(forKey: "rssi") as? NSNumber
        else {
            return nil
        }
        self.init(eninterval: eninterval, payload: payload, rssi: rssi)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(self.payload, forKey: "ENInterval")
        coder.encode(self.payload, forKey: "payload")
        coder.encode(self.rssi, forKey: "rssi")
    }
    
    var dictionary: [String: Any] {
        return [
            "ENInterval": self.eninterval,
            "payload": self.payload,
            "rssi": self.rssi
        ]
    }
    
    var data: Data {
        return (try? JSONSerialization.data(withJSONObject: dictionary)) ?? Data()
    }

    var json: String {
        return String(data: data, encoding: .utf8) ?? String()
    }
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
        if let data = try? Data(contentsOf: from.url()) {
            let str = String(decoding: data, as: UTF8.self)
            print(str)
            if let tokenlist = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) {
                return tokenlist as! TokenList
            }
        } else {
            print("Initial \(from) empty")
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
    
//    func getTokensByENInterval(intervalValue: Int) -> [TokenObject]? {
//        return self[intervalValue]
//    }
    
    mutating func append(token: TokenObject) {
        self.append(token)
//        let curENInterval = ENInterval.value()
//        if self[curENInterval] == nil {
//            // curENInterval doesn't exist in tokenlist
//            self[curENInterval] = [token]
//        } else {
//            self[curENInterval]?.append(token) // self[curENInterval] shouldn't be nil
//        }
    }
    
    var lastENInterval: Int {
        guard let lastToken = self.lastTokenObject else {
            print("Last token object doesn't exist")
            return -1
        }
        return lastToken.eninterval
//        let sortedByKeyDictionary = self.sorted{$0.0 < $1.0}
//        return sortedByKeyDictionary.last?.key ?? 0 // default ENInterval: 0
    }
    
    var lastTokenObject: TokenObject? {
        return self.last
//        if self[lastENInterval] == nil {
//            print("\(lastENInterval) doesn't exist")
//            return nil
//        } else {
//            return self[lastENInterval]?.last ?? nil //default lastTokenObject to nil, should never return nil
//        }
    }
}

typealias ENInterval = TimeInterval
extension ENInterval {
    static func value() -> Int {
        return Int((Date().timeIntervalSince1970) / (10 * 60))
    }
}

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

        peripheralManager = PeripheralManager(peripheralName: peripheralName, queue: queue, service: ctService.getService())
            // CW: deleted [unowned self] because peripheralManager should always be around when closure finishes
            // CW: TODO: confirm why peripheral can go uninitialized --> is it the peripheralManager object that's passed in? But the type is CBCentral...
            .onReadClosure{[unowned self] (peripheral, tokenCharacteristic) in
                return self.myTokens.lastTokenObject?.payload // lastTokenObject should not be nil
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
                                    self.myTokens.lastTokenObject?.payload //lastTokenObject should not be nil
                ))
            .addCommandCallback(
                command: .read(from: tokenCharacteristic))
//
            .didUpdateValueCallback({ [unowned self] peripheral, ch, data, error in
//                if let dat = data, let peerToken = UserToken(data: dat) {
                if let dat = data, let peerToken = TokenObject(eninterval: ENInterval.value(), payload: dat, rssi: NSNumber.init(value: 0)) {
                    print("Read Successful from \(peerToken)")
                    self.peerTokens.append(token:peerToken)
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

