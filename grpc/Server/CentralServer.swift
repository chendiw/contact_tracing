import GRPC
import HelloWorldModel
import NIOCore

class CentralProvider: Central_CentralProvider {
  var interceptors: Central_CentralClientInterceptorFactoryProtocol?

  func sendExposureKeys(
    request: Central_ExposureKeys,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Ack> {
    // need to save tokens to appropriate file
    FileManager.default.createDirectory(atPath: "/ab/cd/", withIntermediateDirectories: true, attributes: nil)
    let response = Central_Ack.with {
      $0.ack = 1
    }
    return context.eventLoop.makeSucceededFuture(response)
  }

  func pollPositive(
    request: Central_Date,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Batch> {
    // need to pull tokens from appropriate file
    let response = Central_Batch.with {
      
    }
    return context.eventLoop.makeSucceededFuture(response)
  }

  func pollNegative(
    request: Central_Date,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Batch> {
    // need to pull tokens from appropriate file
    let response = Central_Batch.with {
      
    }
    return context.eventLoop.makeSucceededFuture(response)
  }
}