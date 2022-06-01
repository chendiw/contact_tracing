import GRPC
import HelloWorldModel
import NIOCore

class AuthProvider: Helloworld_GreeterProvider {
  var interceptors: Helloworld_GreeterServerInterceptorFactoryProtocol?

  func sendReportToken(
    request: Helloworld_HelloRequest,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Helloworld_HelloReply> {
    let recipient = request.name.isEmpty ? "stranger" : request.name
    let response = Helloworld_HelloReply.with {
      $0.message = "Hello \(recipient)!"
    }
    return context.eventLoop.makeSucceededFuture(response)
  }
}