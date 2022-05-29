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
import CoreLocation

// Global static values
// uuid's generated from "https://www.uuidgenerator.net/version4"
public let serviceUUID = CBUUID.init(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
public let characteristicUUID = CBUUID.init(string:"34a30272-19e0-4900-a8e2-7d0bb0e23568")
public let peripheralName = "CT-Peripheral-test1"
public let tokenGenInterval: TimeInterval = 20 //re-exchange tokens per 10 min

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
        self.characteristic = CBMutableCharacteristic.init(type: uuid, properties: [CBCharacteristicProperties.read, CBCharacteristicProperties.write], value: self.value, permissions:[CBAttributePermissions.readable, CBAttributePermissions.writeable])
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
//    case read
    case write(value: Data?)
    case readRSSI
    case cancel(callback: (Peripheral) -> Void)
    case clear
    var description: String {
        switch self {
        case .write:
            return "write"
        case .readRSSI:
            return "readRSSI"
        case .cancel:
            return "cancel"
        case .clear:
            return "clear"
        }
    }
}

typealias UserToken = UInt64
extension UserToken {
    init?(data: Data) {
        var value: UserToken = 0
        guard data.count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { data.copyBytes(to: $0)} )
        self = value
    }
    
    static func next() -> UserToken {
        // https://github.com/apple/swift-evolution/blob/master/proposals/0202-random-unification.md#random-number-generator
        // This is cryptographically random
        let curRandom = UInt64.random(in: 0 ... UInt64.max)
        return UserToken(curRandom)
    }
}

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
            return
        }
        let emptyData:[String:Int] = ["Start":ENInterval.value()]
        let plistContent = NSDictionary(dictionary: emptyData)
        let success:Bool = plistContent.write(toFile: url.path, atomically: false)
        if success {
            print("File: \(url) creation successful")
        } else {
            print("Error creating file \(url)")
        }
    }
    
    static func deleteFile(url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            print("Cannot delete non-existent files: \(url)!")
            return
        }
        do {
            try fm.removeItem(atPath: url.path)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }
    
    func url() -> URL {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let documentDirectoryUrl = NSURL(fileURLWithPath: documentDirectory)
        let fileUrl = documentDirectoryUrl.appendingPathComponent(self.rawValue)!.appendingPathExtension("txt")
        return fileUrl
    }
}


struct TokenObject: Codable {
    var eninterval: Int
    var payload: Data
    var rssi: Int
    var lat: CLLocationDegrees  // latitute
    var long: CLLocationDegrees // logitude
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
            do {
                let arr = try JSONDecoder().decode(self, from: data)
                print("[load from file] the loaded data is: \(arr)")
                return arr
            } catch {
                print(error)
            }
        }
        return TokenList()
    }
    
    func save(to :File) {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: to.url())
        } catch {
            print("Save to file error: \(error)")
        }
    }

    

    mutating func append(curPayload: Data, rssi: Int, lat: CLLocationDegrees, long: CLLocationDegrees) {
        let token = TokenObject(eninterval: ENInterval.value(), payload: curPayload, rssi: rssi, lat: lat, long: long)
        self.append(token)
    }
    
    var lastENInterval: Int {
        guard let lastToken = self.lastTokenObject else {
            print("Last token object doesn't exist")
            return -1
        }
        return lastToken.eninterval
    }
    
    var lastTokenObject: TokenObject? {
        // let item = self.last! // at least one item should exist in the array
        return self.last!
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
    private var locationManager: LocationManager!
    
    public static func startFresh() {
        File.deleteFile(url: File.myTEKs.url())
        File.deleteFile(url: File.peerTokens.url())
    }

    public static func didFinishLaunching() {
        instance = TokenController()
    }
    
    @objc public static func scheduleStartScan() {
        instance.centralManager.startScan()
    }

    public static func start() {
        instance.peripheralManager.startAdvertising()
        let timer2 = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(scheduleStartScan), userInfo: nil, repeats: true)
        
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
    
    @objc public func generateMyToken() {
        // load from different files
         self.myTokens = TokenList.load(from: .myTEKs)
//        _ = self.myTokens.expire(keepInterval: KeepMyIdsInterval)
//        print("My token list size is : \(self.myTokens.count)")
        let curPayload = UserToken.next().data
//        print("My latest token payload: \(curPayload.uint64)")
        // Jiani: Only the payload field in myTokenList is useful
        self.myTokens.append(curPayload: curPayload, rssi: 0, lat: CLLocationDegrees(), long: CLLocationDegrees()) // TODO: Run this line per 10 min
        print("My token list last data is: \(self.myTokens.lastTokenObject?.payload.uint64)")
         self.myTokens.save(to: .myTEKs)

    }
    
    @objc public func scheduleCentralCommand() {
        self.centralManager
//            .addCommandCallback(command: .clear)
            .addCommandCallback(command: .readRSSI)
            .addCommandCallback(
                command: .write(value: self.myTokens.lastTokenObject?.payload //lastTokenObject should not be nil
            ))
        
    }

    public override init() {
        self.queue = DispatchQueue(label: "TokenController")
        self.myTokens = []
        self.peerTokens = []
        
        super.init()
        
        // init token files
        File.createFile(url: File.myTEKs.url())
        File.createFile(url: File.peerTokens.url())
        
        generateMyToken()
        
        let timer1 = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(generateMyToken), userInfo: nil, repeats: true)


//        if self.peerTokens.expire(keepInterval: KeepPeerIdsInterval) {
//            self.peerTokens.save(to: .peerTokens)
//        }

        // object of characteristic nad service
        let tokenCharacteristic = MyCharacteristic(characteristicUUID)
        let ctService = MyService(serviceUUID)
        ctService.addCharacteristic(tokenCharacteristic)

        var rssiList: [UUID: Int] = [:]  // a dict to store all preperial's rssi.

        self.locationManager = LocationManager()

        peripheralManager = PeripheralManager(peripheralName: peripheralName, queue: queue, service: ctService.getService())
            .onWriteClosure{[unowned self] (peripheral, tokenCharacteristic, data) in
                print("[Onwrite]Received peer token: \(data.uint64)")
                self.peerTokens = TokenList.load(from: .peerTokens)  // load old peerTokens
                var rssiValue = 0;
                if rssiList[peripheral.identifier] != nil{
                    rssiValue = rssiList[peripheral.identifier]!
                }
                print("[Read RSSI]peripheral=\(peripheral.identifier), RSSI=\(rssiValue)")
                let latNow = locationManager.getLatitude()
                let longNow = locationManager.getLongitude()
                print("[Read GPS]The current GPS is: \(latNow) \(longNow)")
                self.peerTokens.append(curPayload: data, rssi: rssiValue, lat: latNow, long: longNow)
                self.peerTokens.save(to: .peerTokens)
                return true
            }

        centralManager = CentralManager(services: [ctService], queue: queue)
            .addCommandCallback(command: .readRSSI)
            .didReadRSSICallback({ [unowned self] peripheral, RSSI, error in
                rssiList[peripheral.id] = Int(truncating: RSSI)  // change NSNumber to Ints
                print("[Store RSSI]peripheral=\(peripheral.id), RSSI=\(rssiList[peripheral.id]), error=\(String(describing: error))")
                guard error == nil else {
                    self.centralManager?.disconnect(peripheral)
                    return
                }
            })
            .addCommandCallback(
                command: .write(value: self.myTokens.lastTokenObject?.payload //lastTokenObject should not be nil
            ))

        let timer2 = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(scheduleCentralCommand), userInfo: nil, repeats: true)
            
        
    }
    
}
