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
import CryptoKit

// Global static values
// uuid's generated from "https://www.uuidgenerator.net/version4"
public let serviceUUID = CBUUID.init(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
public let characteristicUUID = CBUUID.init(string:"34a30272-19e0-4900-a8e2-7d0bb0e23568")
public let peripheralName = "CT-Peripheral-test1"
public let tokenGenInterval: TimeInterval = 60 //re-exchange tokens per 10 min, testing with per min
public let expKeyInterval: TimeInterval = 10*60 // re-generate exposure key per day (1440*60s), testing with per 10 min

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

typealias ExpKey = UInt64
extension ExpKey {
    init?(data: Data) {
        var value: ExpKey = 0
        guard data.count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { data.copyBytes(to: $0)} )
        self = value
    }
    
    static func next() -> ExpKey {
        let curRandom = UInt64.random(in: 0 ... UInt64.max)
        return ExpKey(curRandom)
    }
}

let KeepMyIdsInterval: TimeInterval = 60*60*24*7*2 // 2 weeks = 14 days
let KeepPeerIdsInterval: TimeInterval = 60*60*24*7*2 // 2 weeks = 14 days
// Two files storing myTEKs and peerTokens
// myTEKs: i (computed from ENIntervalNumber) -> TEK_i (14 pairs)
// peerTokens: ENIntervalNumber -> [Tokenobject{Bluetooth payload, RSSI, GPS location}] (144*14=2016 pairs)
enum File: String {
    case myTokens
    case peerTokens
    case myExposureKeys

    var rawValue: String {
        switch self {
            case .myTokens: return "myTokens"
            case .peerTokens: return "peerTokens"
            case .myExposureKeys: return "myExposureKeys"
        }
    }
    
    func createFile(url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else {
            return
        }
        let emptyData: [TokenObject] = []
        do {
            let data = try JSONEncoder().encode(emptyData)
            try data.write(to: url)
        } catch {
            print("Save EmptyData Error: \(error)")
        }
    }
    
    func deleteFile(url: URL) {
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
    
    func dayURL(date: Date) -> URL {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let documentDirectoryUrl = NSURL(fileURLWithPath: documentDirectory)
        let fileUrl = documentDirectoryUrl.appendingPathComponent(dayFilename(date: date))!.appendingPathExtension("txt")
        return fileUrl
    }
    
    func dayFilename(date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let name = String(month) + "-" + String(day)
        print("[dayURL] Today's date is: \(name)")
        return self.rawValue + name
    }
    
    static func deleteAll() {
        do {
            // Get the document directory url
            let documentDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            print("documentDirectory", documentDirectory.path)
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: documentDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for url in directoryContents where url.pathExtension == "txt" {
                try FileManager.default.removeItem(at: url)
            }
            print("Cleaned all files!")
        } catch {
            print(error)
        }
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
    static func dayLoad(from: File, day: Date) -> TokenList {
        if let data = try? Data(contentsOf: from.dayURL(date: day)) {
            do {
                let arr = try JSONDecoder().decode(self, from: data)
                print("[load from file] the loaded data is: \(arr)")
                return arr
            } catch {
                print("This is the error when dayLoad: ", error)
            }
        }
        return TokenList()
    }
    
    func daySave(to: File, day: Date) {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: to.dayURL(date: day))
            print("[DaySave], save to file name \(to.dayURL(date: day))")
        } catch {
            print("Save to file error: \(error)")
        }
    }

    mutating func append(curPayload: Data, rssi: Int, lat: CLLocationDegrees, long: CLLocationDegrees) {
        let token = TokenObject(eninterval: ENInterval.value(), payload: curPayload, rssi: rssi, lat: lat, long: long)
        self.append(token)
    }

    var lastTokenObject: TokenObject? {
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
    private var myExposureKey: TokenObject! = nil
    private var myTokens: TokenList! = []
    private var peerTokens: TokenList! = []
    private var backgroundTaskId: UIBackgroundTaskIdentifier?
    private var locationManager: LocationManager!
    
    public static func startFresh() {
        File.deleteAll()
    }

    public static func didFinishLaunching() {
        instance = TokenController()
    }
    
    @objc public static func scheduleStartScan() {
        instance.centralManager.startScan()
    }

    public static func start() {
        instance.peripheralManager.startAdvertising()
        
        // Every time we generate a new token, scan for peripherals and exchange tokens
        let timerStartScan = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(scheduleStartScan), userInfo: nil, repeats: true)
        
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
        // load current date's exposure key
        let readTodayExpKey = TokenList.dayLoad(from: .myExposureKeys, day: Date())
        assert(readTodayExpKey.count == 1)
        self.myExposureKey = readTodayExpKey.first!
        
        // Generate RPI key from exposure key
        let rpi_key: SymmetricKey = getRPIKey(tek: self.myExposureKey.payload)
        
        // Generate RPI with random nonce, result: RPI (16 bytes)||nonce||tag (16 bytes)
        let rpi: Data = getRPI(rpi_key: rpi_key, nonce: crng(count: 16), eninterval: ENInterval.value())
        
        // Append and save my new RPI to file
        self.myTokens = TokenList.dayLoad(from: .myTokens, day: Date())
        self.myTokens.append(curPayload: rpi, rssi: 0, lat: CLLocationDegrees(), long: CLLocationDegrees()) // TODO: Run this line per 10 min
        print("My token list last data is: \(self.myTokens)")
        self.myTokens.daySave(to: .myTokens, day: Date())

    }
    
    @objc public func scheduleCentralCommand() {
        self.centralManager
//            .addCommandCallback(command: .clear)
            .addCommandCallback(command: .readRSSI)
            .addCommandCallback(
                command: .write(value: self.myTokens.last!.payload //lastTokenObject should not be nil
            ))
        
    }

    public override init() {
        self.queue = DispatchQueue(label: "TokenController")
        super.init()
        
        // Generate my token for the first time
        generateMyToken()
        // Schedule token generation per `tokenGenInterval`
        let timerTokenGen = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(generateMyToken), userInfo: nil, repeats: true)

        // object of characteristic and service
        let tokenCharacteristic = MyCharacteristic(characteristicUUID)
        let ctService = MyService(serviceUUID)
        ctService.addCharacteristic(tokenCharacteristic)

        var rssiList: [UUID: Int] = [:]  // a dict to store all preperial's rssi.

        self.locationManager = LocationManager()

        peripheralManager = PeripheralManager(peripheralName: peripheralName, queue: queue, service: ctService.getService())
            .onWriteClosure{[unowned self] (peripheral, tokenCharacteristic, data) in
                print("[Onwrite]Received peer token: \(data.uint64)")
                self.peerTokens = TokenList.dayLoad(from: .peerTokens, day: Date())  // load today's peerTokens
                var rssiValue = 0;
                if rssiList[peripheral.identifier] != nil {
                    rssiValue = rssiList[peripheral.identifier]!
                }
                print("[Read RSSI]peripheral=\(peripheral.identifier), RSSI=\(rssiValue)")
                let latNow = locationManager.getLatitude()
                let longNow = locationManager.getLongitude()
                print("[Read GPS]The current GPS is: \(latNow) \(longNow)")
                self.peerTokens.append(curPayload: data, rssi: rssiValue, lat: latNow, long: longNow)
                self.peerTokens.daySave(to: .peerTokens, day: Date())
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

        let timerTokenExchange = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(scheduleCentralCommand), userInfo: nil, repeats: true)
            
        
    }
    
}
