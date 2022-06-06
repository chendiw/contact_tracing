//
//  Crypto.swift
//
//  Created by Chendi Wu on 5/24/22.
//
import Foundation
import CryptoKit
//import CryptoSwift
// CRNG(16)
func crng(count: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: count)

    // Fill bytes with secure random data
    let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    
    if status == errSecSuccess {
        // success
        let data = Data(bytes: bytes, count: count)
//        print("Generated tek: \(data.hex)")
        return data
    } else {
        print("Error generating random bytes")
        print(status)
        return Data()
    }
}

// HKDF(tek_i, UTF8("EN-RPIK"), 16)
// Experiment with whether tek_i should be UserToken.data() or result from crng(16)
func getRPIKey(tek: Data) -> SymmetricKey {
    let resultKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey.init(data: tek), info: "EN-RPIK".data(using: .utf8)!, outputByteCount: 16)
    let resultKey64 = resultKey.withUnsafeBytes {return Data(Array($0)).base64EncodedString()}
//    print("RPI Key base64: \(resultKey64)")
    return resultKey
}

// AES_128(RPIK_i, PaddedData_j)
// result: ciphertext(RPI)||nonce||tag = bluetooth payload
func getRPI(rpi_key: SymmetricKey, nonce: Data, eninterval: UInt64) -> Data {
    var plaintext = "EN-RPI".data(using: .utf8)! // 6 bytes
//    print("plaintext length: \(plaintext.count)")
    var interval_value = eninterval
    let interval = Data(bytes: &interval_value, count: MemoryLayout.size(ofValue: eninterval))
//    print("eninterval length: \(interval.count)")
    plaintext.append(interval) // 8 bytes -> Plaintext total: 16 bytes
    let padding = Data.init(count: 2) // 2 bytes
//    print("padding length: \(padding.count)")
    plaintext.append(padding)
//    print("nonce is: \(nonce.uint64)")
    let sealedData = try! AES.GCM.seal(plaintext, using: rpi_key, nonce: AES.GCM.Nonce(data: nonce))
//    print("Nonce: \(sealedData.nonce.withUnsafeBytes {Data(Array($0)).hex})")
//    print("Tag: \(sealedData.tag.hex)")
//    print("Ciphertext: \(sealedData.ciphertext.base64EncodedString())")
    var result = sealedData.ciphertext // Data
    assert(result.count == 16)
    result.append(nonce)
    assert(result.count == 32)
    
//    result.append(sealedData.nonce.withUnsafeBytes {Data(Array($0))})
//
//    result.append(sealedData.tag)
//    assert(sealedData.tag.count == 16)
    
    return result
}

// Decrypt RPI to get ENINterval
//func getInterval(rpi_key: SymmetricKey, rpi: Data) -> Int {
//    let ciphertext = rpi.subdata(in: 0..<16)
//    let nonce_length = rpi.count - 16 * 2;
//    let nonce = rpi.subdata(in: 16..<(16+nonce_length))
//    let tag = rpi.subdata(in: (16+nonce_length)..<rpi.count)
//    let sealedBox = try! AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
//    let decryptedData = try! AES.GCM.open(sealedBox, using: rpi_key)
//    return decryptedData.subdata(in: 8..<16).int
//}

// HKDF(tek_i, UTF8("EN-AEMK"), 16)
func getAEMKey(tek: Data) -> SymmetricKey {
    let resultKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey.init(data: tek), info: "EN-AEMK".data(using: .utf8)!, outputByteCount: 16)
    return resultKey
}

// Generate (private key, public key) pair for digital signature
func sigKeyGen() -> (P256.Signing.PrivateKey, P256.Signing.PublicKey) {
    let privateKey = P256.Signing.PrivateKey();
    let publicKey = privateKey.publicKey
//    let signingPublicKey = try! Curve25519.Signing.PublicKey(rawRepresentation: publicKey.rawRepresentation)
//    return (privateKey, signingPublicKey)
    return (privateKey, publicKey)
}

// sign(TA_sk, concat_teks) TODO: add timestamp info to avoid replay attack
func sign(pri_key: P256.Signing.PrivateKey, content: Data) -> Data {
    let hash = SHA256.hash(data: content)
    let digestSignature = try! pri_key.signature(for: Data(hash))
//    print(digestSignature.rawRepresentation)
//    let digestSignature = try! pri_key.signature(for: content)
    return digestSignature.derRepresentation
}

// verify(TA_pk, signature, concat_teks)
func verifySign(pub_key: P256.Signing.PublicKey, signature: Data, digest: SHA256Digest) -> Bool {
    let sig = try! P256.Signing.ECDSASignature(derRepresentation: signature)
    return pub_key.isValidSignature(sig, for: Data(digest))
}

// Generate start (inclusive) and end (inclusive) of ENInterval in the past 5 days
func regenENInterval(date: Date) -> (UInt64, UInt64){
//    let start = ENInterval.valueAtDate(date: Calendar.current.date(byAdding: .day, value: -5, to: date)!)
    // Experiment
    let start = ENInterval.valueAtDate(date: Calendar.current.date(byAdding: .minute, value: -5, to: date)!)
    let end = ENInterval.value()
//    print("Regenerating tokens for interval range: \(start), \(end)")
    return (start, end)
}

// Reproduce all rpis for a list of exposure keys in the past 5 days
func regenRPIs(expKeys: [UInt64], nonce: Data) -> Set<UInt64> {
    var allRPIs = Set<UInt64>.init()
    for expKey in expKeys {
        if expKey == 0 {
            continue
        }
        let allENInterevals = regenENInterval(date: Date())
//        print("regen nonce: \(nonce.uint64)")
        for i in allENInterevals.0..<(allENInterevals.1+1) {
            if !allRPIs.insert(getRPI(rpi_key: getRPIKey(tek: expKey.data), nonce: nonce, eninterval: i).uint64).0 {
                print("RPI repeated! Highly unlikely: \(expKey.data.uint64)")
            }
        }
    }
    return allRPIs
}

