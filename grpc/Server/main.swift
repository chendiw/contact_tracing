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
  var receivedTokens: [UInt64: [UInt64]] = [0:[0]]
  let daysUntilResult: Int = 2
  let taID: UInt64 = UInt64.random(in: 0 ... UInt64.max)
  let keys = sigKeyGen()

  func startTest(request: Testingauth_PretestTokens, context: StatusOnlyCallContext) 
  -> EventLoopFuture<Testingauth_Ack> {
    // generate userId when start test
    let userId = assignUserId()
    saveUserProfileStart(userId: userId, tokens: request.pretest)
    testSavedSuccess(userId: userId)
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
    self.receivedTokens = UserIdToTEKs.load(from: .receivedTEKFile)
    for t in tokens {
      self.receivedTokens.append(userId: userId, token: t)
    }
    self.receivedTokens.save(to: .receivedTEKFile)
  }

  func testSavedSuccess(userId: UInt64) {
    let curTokens = UserIdToTEKs.load(from: .receivedTEKFile)
    assert(curTokens[userId]!.count == 3)
  }

  func updateUserProfile(userId: UInt64, token: UInt64) -> Testingauth_TestResult {
    self.receivedTokens = UserIdToTEKs.load(from: .receivedTEKFile)
    assert(self.receivedTokens[userId] != nil)
    self.receivedTokens[userId]!.append(token)
    self.receivedTokens.save(to: .receivedTEKFile)
    if self.receivedTokens[userId]!.count == 3 + self.daysUntilResult {
      let ready: Bool = true

      var teks: Data = self.receivedTokens[userId]!.first!.data
      for t in self.receivedTokens[userId]! {
        if t.data != teks {
          teks.append(t.data)
        }
      }
      let seq: UInt64 = sign(pri_key: keys.0, content: teks).uint64

      // for testing purposes, result is generated randomly
      let result: UInt64 = [1, 0].randomElement()!

      var vrfyMsg: Data = self.taID.data
      vrfyMsg.append(seq.data)
      vrfyMsg.append(result.data)

      let signature: UInt64 = sign(pri_key: keys.0, content: vrfyMsg).uint64

      let response = Testingauth_TestResult.with {
        $0.ready = ready
        $0.taID = self.taID
        $0.seq = seq
        $0.result = result
        $0.signature = signature
      }
      print("Tokens before response: \(self.receivedTokens[userId])")
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

  func run() throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try! group.syncShutdownGracefully()
    }

    // Start the server and print its address once it has started.
    let server = Server.insecure(group: group)
<<<<<<< HEAD
      .withServiceProviders([TestAuthProvider()])
=======
      .withServiceProviders([CentralProvider()])
>>>>>>> origin/main
      .bind(host: "localhost", port: self.port)

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

<<<<<<< HEAD
TestAuth.main()
=======
Central.main()
>>>>>>> origin/main
