//
//  Crypto.swift
//
//  Created by Chendi Wu on 5/24/22.
//
import Foundation
import CryptoKit

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
    let _ = resultKey.withUnsafeBytes {return Data(Array($0)).base64EncodedString()}
//    print("RPI Key base64: \(resultKey64)")
    return resultKey
}

// AES_128(RPIK_i, PaddedData_j)
// result: ciphertext||nonce||tag
func getRPI(rpi_key: SymmetricKey, nonce: Data?, eninterval: Int) -> Data {
    var plaintext = "EN-RPI".data(using: .utf8)! // 6 bytes
//    print("plaintext length: \(plaintext.count)")
    let padding = Data.init(count: 2) // 2 bytes
//    print("padding length: \(padding.count)")
    plaintext.append(padding)
    var interval_value = eninterval
    let interval = Data(bytes: &interval_value, count: MemoryLayout.size(ofValue: eninterval))
//    print("eninterval length: \(interval.count)")
    plaintext.append(interval) // 8 bytes -> Plaintext total: 16 bytes
    let sealedData = try! AES.GCM.seal(plaintext, using: rpi_key, nonce: AES.GCM.Nonce(data: nonce!))
//    print("Nonce: \(sealedData.nonce.withUnsafeBytes {Data(Array($0)).hex})")
//    print("Tag: \(sealedData.tag.hex)")
//    print("Ciphertext: \(sealedData.ciphertext.base64EncodedString())")
    var result = sealedData.ciphertext
    assert(result.count == 16)
    
    result.append(sealedData.nonce.withUnsafeBytes {Data(Array($0))})
    
    result.append(sealedData.tag)
    assert(sealedData.tag.count == 16)
    
    return result
}

// Decrypt RPI to get ENINterval
func getInterval(rpi_key: SymmetricKey, rpi: Data) -> Int {
    let ciphertext = rpi.subdata(in: 0..<16)
    let nonce_length = rpi.count - 16 * 2;
    let nonce = rpi.subdata(in: 16..<(16+nonce_length))
    let tag = rpi.subdata(in: (16+nonce_length)..<rpi.count)
    let sealedBox = try! AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
    let decryptedData = try! AES.GCM.open(sealedBox, using: rpi_key)
    return decryptedData.subdata(in: 8..<16).int
}

// HKDF(tek_i, UTF8("EN-AEMK"), 16)
func getAEMKey(tek: Data) -> SymmetricKey {
    let resultKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey.init(data: tek), info: "EN-AEMK".data(using: .utf8)!, outputByteCount: 16)
    return resultKey
}

// TODO: AES-128-CTR encrypt metadata

// Generate (private key, public key) pair for digital signature
func sigKeyGen() -> (Curve25519.Signing.PrivateKey, Curve25519.Signing.PublicKey) {
    let privateKey = Curve25519.Signing.PrivateKey();
    let publicKey = privateKey.publicKey
    let signingPublicKey = try! Curve25519.Signing.PublicKey(rawRepresentation: publicKey.rawRepresentation)
    return (privateKey, signingPublicKey)
}

// sign(TA_sk, concat_teks) TODO: add timestamp info to avoid replay attack
func sign(pri_key: Curve25519.Signing.PrivateKey, content: Data) -> Data {
    let hash = SHA256.hash(data: content)
    let digestSignature = try! pri_key.signature(for: Data(hash))
    return digestSignature
}

// verify(TA_pk, signature, concat_teks)
func verifySign(pub_key: Curve25519.Signing.PublicKey, signature: Data, digest: SHA256Digest) -> Bool {
    return pub_key.isValidSignature(signature, for: Data(digest))
}
