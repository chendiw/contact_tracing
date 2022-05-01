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

// Generated from "https://www.uuidgenerator.net/version4"
let serviceUUID = CBUUID.init(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
let service = CBMutableService(type: serviceUUID, primary:true)

let characteristicUUID = CBUUID.init(string:"34a30272-19e0-4900-a8e2-7d0bb0e23568")
// Temporarily set both property and permission to "read/write"
let characteristic = CBMutableCharacteristic.init(type:characteristicUUID, properties: [.read, .write], value: nil, permissions:[.writeable, .readable])


// Not used: Encapuslation of the service
//class Service {
//    private var serviceUUID: CBUUID
//    private var service: CBMutableService
//    init() {
//        serviceUUID = CBUUID.init(string:"5ad5b97a-49e6-493b-a4a9-b435c455137d")
//        service = CBMutableService(type: self.serviceUUID, primary:true)
//    }
//    public func getCBUUID() -> CBUUID {
//        return self.serviceUUID
//    }
//    public func  getService() -> CBMutableService {
//        return self.service
//    }
//}


