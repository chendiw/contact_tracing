import ArgumentParser
import GRPC
import centralModel
import NIOCore
import NIOPosix
import Foundation

struct Central: ParsableCommand {
  @Option(help: "The host IP address")
  var host = "172.31.43.1"
  //var host = "localhost"

  @Option(help: "The port to listen on for new connections")
  var port = 1235

  @Option(help: "Type y to clean all records on server")
  var clean = "regular"

  func run() throws {
    if clean == "y" {
      do {
          // Get the document directory url
          let currentDirectoryUrl = URL(fileURLWithPath: ".")
          let directoryContents = try FileManager.default.contentsOfDirectory(
              at: currentDirectoryUrl,
              includingPropertiesForKeys: nil,
              options: .skipsHiddenFiles
          )
          print(directoryContents)
          for url in directoryContents where url.pathExtension == "txt" {
              try FileManager.default.removeItem(at: url)
          }
          print("Cleaned all files!")
      } catch {
          print(error)
      }
    } else {
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
        print("central server started on port \(address!.port!)")
      }

      // Wait on the server's `onClose` future to stop the program from exiting.
      _ = try server.flatMap {
        $0.onClose
      }.wait()
    }
  }

}

Central.main()
