import GRPC
import Foundation
import ArgumentParser
import testAuthModel
import NIOCore
import NIOPosix

// TAFile: UserId: UInt64 -> tokens: [UInt64]
// Store one TAFile per day, named by "Date.now.formatted()"

class TestAuthProvider: Testingauth_AuthProvider {
  var interceptors: Testingauth_AuthServerInterceptorFactoryProtocol?
  // var receivedTokens: [UInt64: [UInt64]] = [0:[0]]
  let daysUntilResult: Int = 2
  var daysUntilResultByUser: [UInt64: Int] = [0:0]
  let taID: UInt64 = UInt64.random(in: 0 ... UInt64.max)
  let keys = sigKeyGen()

  func startTest(request: Testingauth_PretestTokens, context: StatusOnlyCallContext) 
  -> EventLoopFuture<Testingauth_Ack> {
    // generate userId when start test
    print("server received start test")
    if !UserIdToTEKs.dayLoad(from: .receivedTEKFile, day: Date()).1 {
      TAFile.receivedTEKFile.createFile(url: TAFile.receivedTEKFile.dayURL(date: Date()))
    }
    let userId = assignUserId()
    saveUserProfileStart(userId: userId, tokens: request.pretest)
    
    // test file saved correct
    testSavedSuccess(userId: userId, targets: request.pretest)

    self.daysUntilResultByUser[userId] = self.daysUntilResult

    let response = Testingauth_Ack.with {
      $0.userID = userId
      $0.ack = true
    }

    return context.eventLoop.makeSucceededFuture(response)
  }

  func getResult(request: Testingauth_Check, context: StatusOnlyCallContext) 
  -> EventLoopFuture<Testingauth_TestResult> {
    let userId = request.userID
    let response = updateUserProfile(userId: userId, token: request.token)
    return context.eventLoop.makeSucceededFuture(response)
  }

  func assignUserId() -> UInt64 {
    return UInt64.random(in: 0 ... UInt64.max)
  }

  func saveUserProfileStart(userId: UInt64, tokens: [UInt64]) {
    var receivedTokens = UserIdToTEKs.dayLoad(from: .receivedTEKFile, day: Date()).0
    for t in tokens {
      if receivedTokens[userId] != nil {
        receivedTokens[userId]!.append(t)
      } else {
        receivedTokens[userId] = [t]
      }
    }
    receivedTokens.daySave(to: .receivedTEKFile, day: Date())
  }

  func updateUserProfile(userId: UInt64, token: UInt64) -> Testingauth_TestResult {
    var receivedTokens = UserIdToTEKs.dayLoad(from: .receivedTEKFile, day: Date()).0
    assert(receivedTokens[userId] != nil)
    receivedTokens[userId]!.append(token)
    receivedTokens.daySave(to: .receivedTEKFile, day: Date())

    // user has waited another day
    assert(self.daysUntilResultByUser[userId] != nil)
    self.daysUntilResultByUser[userId]! -= 1

    if self.daysUntilResultByUser[userId] == 0 {
      let ready: Bool = true

      // Generate sequence number based on received exposure keys
      var teks: Data = receivedTokens[userId]!.first!.data
      for t in receivedTokens[userId]! {
        if t.data != teks {
          teks.append(t.data)
        }
      }
      let seq: UInt64 = sign(pri_key: keys.0, content: teks).uint64

      // Test: seq/expKey relationship is verifiable
      testSigVerifiable(content: teks, seq: seq, pub_key: keys.1)

      // for testing purposes, result is generated randomly
      let result: UInt64 = [1, 0].randomElement()!

      var vrfyMsg: Data = self.taID.data
      vrfyMsg.append(seq.data)
      vrfyMsg.append(result.data)

      let signature: UInt64 = sign(pri_key: keys.0, content: vrfyMsg).uint64

      // Test: main msg body verifiable
      testSigVerifiable(content: vrfyMsg, seq: signature, pub_key: keys.1)

      let response = Testingauth_TestResult.with {
        $0.ready = ready
        $0.taID = self.taID
        $0.seq = seq
        $0.result = result
        $0.signature = signature
      }
      receivedTokens.removeValue(forKey: userId)
      receivedTokens.daySave(to: .receivedTEKFile, day: Date())
      return response
    } else {
      let response = Testingauth_TestResult.with {
        $0.ready = false
        $0.taID = self.taID
        $0.seq = 0
        $0.result = 0
        $0.signature = 0
      }
      return response
    }
  }
}

struct TestAuth: ParsableCommand {
  @Option(help: "The port to listen on for new connections")
  var port = 1234
  var host = "172.31.43.1"
  // var host = "localhost"

  func run() throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try! group.syncShutdownGracefully()
    }

    // Start the server and print its address once it has started.
    let server = Server.insecure(group: group)
      .withServiceProviders([TestAuthProvider()])
      .bind(host: self.host, port: self.port)

    server.map {
      $0.channel.localAddress
    }.whenSuccess { address in
      print("testauth server started on port \(address!.port!)")
    }

    // Wait on the server's `onClose` future to stop the program from exiting.
    _ = try server.flatMap {
      $0.onClose
    }.wait()
  }
}

TestAuth.main()
