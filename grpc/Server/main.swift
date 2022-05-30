import GRPC
import Foundation
import ArgumentParser
import testAuthModel
import NIOCore
import NIOPosix

// TAFile: UserId: UInt64 -> tokens: [UInt64]
// Store one TAFile per day, named by "Date.now.formatted()"

enum TAFile: String {
    case receivedTEKFile
    var rawValue: String {
        switch self {
          case .receivedTEKFile: return "receivedTEKFile"
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
        print("file url: \(fileUrl)")
        return fileUrl
    }
}

typealias UserIdToTEKs = [UInt64: [UInt64]]
extension UserIdToTEKs {
  static func load(from: TAFile) -> UserIdToTEKs {
    if let data = try? Data(contentsOf: from.url()) {
        do {
            let arr = try JSONDecoder().decode(self, from: data)
            print("[load from file] the loaded data is: \(arr)")
            return arr
        } catch {
            print(error)
        }
    }
    return UserIdToTEKs()
  }

  func save(to: TAFile) {
    do {
        let data = try JSONEncoder().encode(self)
        try data.write(to: to.url())
    } catch {
        print("Save to file error: \(error)")
    }
  }

  mutating func append(userId: UInt64, token: UInt64) {
    if self[userId] != nil {
      self[userId]!.append(token)
    } else {
      self[userId] = [token]
    }
  }
}

class TestAuthProvider: Testingauth_AuthProvider {
  var interceptors: Testingauth_AuthServerInterceptorFactoryProtocol?
  var receivedTokens: [UInt64: [UInt64]] = [0:[0]]
  let daysUntilResult: Int = 2

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
    
    let response = Testingauth_TestResult.with {
      $0.ready = true
      $0.result = 1
    }
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

  func updateUserProfile(userId: UInt64, token: UInt64) -> (Bool, UInt64) {
    self.receivedTokens = UserIdToTEKs.load(from: .receivedTEKFile)
    assert(self.receivedTokens[userId] != nil && self.receivedTokens[userId]!.count==3)
    self.receivedTokens[userId]!.append(token)
    if self.receivedTokens[userId]!.count == 3 + self.daysUntilResult {
      // return (true, )
    } else {
      return (false, 0)
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
      .withServiceProviders([TestAuthProvider()])
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

TestAuth.main()
