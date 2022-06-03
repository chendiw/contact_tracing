import ArgumentParser
import GRPC
import centralModel
import NIOCore
import NIOPosix

struct Central: ParsableCommand {
  @Option(help: "The port to listen on for new connections")
  var port = 1235
  var host = "172.31.43.1"

  func run() throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
      try! group.syncShutdownGracefully()
    }

    // Start the server and print its address once it has started.
    let server = Server.insecure(group: group)
      .withServiceProviders([CentralProvider()])
      .bind(host: self.host, port: self.port)

    server.map {
      $0.channel.localAddress
    }.whenSuccess { address in
      print("server started on port \(address!.port!)")
    }

    // Wait on the server's `onClose` future to stop the program from exiting.
    _ = try server.flatMap {
      $0.onClose
    }.wait()
  }
}

Central.main()
