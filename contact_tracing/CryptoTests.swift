//
//  CryptoTests.swift
//
//  Created by Chendi Wu on 5/25/22.
//
import Foundation

public func testRegenRPI(nonce: Data) {
    // crypto test
    // Test RPI's are reproducible
    let tek = crng(count: 16)
    let nonce = nonce
    var firstRun:[String] = []
    for i in 0...5 {
        let cur_interval = i
        firstRun.append(getRPI(rpi_key: getRPIKey(tek: tek), nonce: nonce, eninterval: cur_interval).hex)
    }
    
    var secondRun:[String] = []
    for i in 0...5 {
        let cur_interval = i
        secondRun.append(getRPI(rpi_key: getRPIKey(tek: tek), nonce: nonce, eninterval: cur_interval).hex)
    }
    
    for i in 0...5 {
        if i != 5 {
            assert(firstRun[i] != firstRun[i+1])
            assert(secondRun[i] != secondRun[i+1])
        }
        assert(firstRun[i] == secondRun[i])
    }
    
    print("cryptoTestRegenRPI success!")
}

public func testDiffRPI(nonce: Data) {
    var teks:[Data] = []
    var rpis:Set<String> = []
    for _ in 0...20 {
        teks.append(crng(count: 16))
    }
    
    for i in 0...20 {
        for j in 0...144 {
            let inserted = rpis.insert(getRPI(rpi_key: getRPIKey(tek: teks[i]), nonce: nonce, eninterval: j).hex).0
            if (!inserted) {
                print("Test Diff RPI failed!")
            }
        }
    }
    print("Test Diff RPI success!")
}

public func testDecryptInterval() {
    
}
