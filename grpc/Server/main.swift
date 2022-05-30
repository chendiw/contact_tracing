import GRPC
import ArgumentParser
import testAuthModel
import NIOCore
import NIOPosix

class TestAuthProvider: Testingauth_AuthProvider {
  var interceptors: Testingauth_AuthServerInterceptorFactoryProtocol?

  func startTest(request: Testingauth_PretestTokens, context: StatusOnlyCallContext) 
  -> EventLoopFuture<Testingauth_Ack> {
    let response = Testingauth_Ack.with {
      $0.ack = true
    }
    return context.eventLoop.makeSucceededFuture(response)
  }

  func getResult(request: Testingauth_Check, context: StatusOnlyCallContext) 
  -> EventLoopFuture<Testingauth_TestResult> {
    let response = Testingauth_TestResult.with {
      $0.ready = true
      $0.result = 1
    }
    return context.eventLoop.makeSucceededFuture(response)
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
