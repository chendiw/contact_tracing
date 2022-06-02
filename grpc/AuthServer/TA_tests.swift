import Foundation
import CryptoKit


func testSavedSuccess(userId: UInt64, targets: [UInt64]) {
  let curTokens = UserIdToTEKs.dayLoad(from: .receivedTEKFile, day: Date()).0
  assert(curTokens[userId]!.count == targets.count)
  for i in 0..<curTokens[userId]!.count {
  	assert(curTokens[userId]![i] == targets[i])
  }
}

func testSigVerifiable(content: Data, seq: UInt64, pub_key: Curve25519.Signing.PublicKey) {
	let hash = SHA256.hash(data: content)
	assert(verifySign(pub_key: pub_key, signature: seq.data, digest: hash))
}
