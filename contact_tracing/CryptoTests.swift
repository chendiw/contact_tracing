//
//  CryptoTests.swift
//
//  Created by Chendi Wu on 5/25/22.
//
import Foundation
import CryptoKit

//public func testRegenRPI(nonce: Data) {
//    // crypto test
//    // Test RPI's are reproducible
//    let tek = crng(count: 16)
//    let nonce = nonce
//    var firstRun:[String] = []
//    for i in 0...5 {
//        let cur_interval = i
//        firstRun.append(getRPI(rpi_key: getRPIKey(tek: tek), nonce: nonce, eninterval: cur_interval).hex)
//    }
//
//    var secondRun:[String] = []
//    for i in 0...5 {
//        let cur_interval = i
//        secondRun.append(getRPI(rpi_key: getRPIKey(tek: tek), nonce: nonce, eninterval: cur_interval).hex)
//    }
//
//    for i in 0...5 {
//        if i != 5 {
//            assert(firstRun[i] != firstRun[i+1])
//            assert(secondRun[i] != secondRun[i+1])
//        }
//        assert(firstRun[i] == secondRun[i])
//    }
//
//    print("cryptoTestRegenRPI success!")
//}

//public func testDiffRPI(nonce: Data) {
//    var teks:[Data] = []
//    var rpis:Set<String> = []
//    for _ in 0...20 {
//        teks.append(crng(count: 16))
//    }
//
//    for i in 0...20 {
//        for j in 0...144 {
//            let inserted = rpis.insert(getRPI(rpi_key: getRPIKey(tek: teks[i]), nonce: nonce, eninterval: j).hex).0
//            if (!inserted) {
//                print("Test Diff RPI failed!")
//            }
//        }
//    }
//    print("Test Diff RPI success!")
//}

//public func testRegenRPI() {
//    let nonce = TokenController.nonce
//    // generate expKey
//    let expKey = ExpKey.next()
//    print("initial expKey: \(expKey)")
//    var shouldReceiveTokens: Set<UInt64> = Set()
//    for i in 0..<12 {
//        let rpi_key: SymmetricKey = getRPIKey(tek: expKey.data)
//        let curENInterval = ENInterval.valueAtDate(date: Calendar.current.date(byAdding: .minute, value: -i, to: Date())!)
//        let rpi: Data = getRPI(rpi_key: rpi_key, nonce: nonce, eninterval: curENInterval)
//        shouldReceiveTokens.insert(rpi.uint64)
//    }
//
//    // Write to a file as CS does
//    let fileName = "pos-" + Date().minuteString
//    let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
//    let currentDirectoryUrl = NSURL(fileURLWithPath: documentDirectory)
//    let fileUrl = currentDirectoryUrl.appendingPathComponent(fileName)!.appendingPathExtension("txt")
//    let token1 = expKey
//    let token1Str = String(token1) + "$"
//    do {
//        try token1Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
//    } catch let error as NSError {
//        print (error)
//    }
//
//    // Read from the file to fetch expkey
//    let contents = try! String(contentsOf: fileUrl, encoding: .utf8)
//    let lines = contents.split(separator:"$")
//    let count = lines.count
//    var resp: [UInt64] = []
//    for i in 1...count {
//      let keyStr = lines[i - 1]
//      if let key = UInt64(keyStr) {
//        resp.append(key)
//      } else {
//        // do nothing
//      }
//    }
//    print("Read expKey: \(resp)")
//
//    let regen = regenRPIs(expKeys: [expKey], nonce: nonce)
//    print(regen.intersection(shouldReceiveTokens))
//}
