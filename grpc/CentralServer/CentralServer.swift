import GRPC
import HelloWorldModel
import NIOCore

class CentralProvider: Central_CentralProvider {
  var interceptors: Central_CentralClientInterceptorFactoryProtocol?

  func sendExposureKeys(
    request: Central_ExposureKeys,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Ack> {
    // write tokens to file, with delimiters
    if (request.pos == 1) {
        FileManager.default.createDirectory(atPath: "pos-" + request.date1, withIntermediateDirectories: true, attributes: nil)
        let token1 = request.token1
        var token1Str = String(token1) + "$"
        let path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date1)
        if let stringData = token1Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        FileManager.default.createDirectory(atPath: "pos-" + request.date2, withIntermediateDirectories: true, attributes: nil)
        let token2 = request.token2
        var token2Str = String(token2) + "$"
        let path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date2)
        if let stringData = token2Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        FileManager.default.createDirectory(atPath: "pos-" + request.date3, withIntermediateDirectories: true, attributes: nil)
        let token3 = request.token3
        var token3Str = String(token3) + "$"
        let path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date3)
        if let stringData = token3Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        FileManager.default.createDirectory(atPath: "pos-" + request.date4, withIntermediateDirectories: true, attributes: nil)
        let token4 = request.token4
        var token4Str = String(token4) + "$"
        let path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date4)
        if let stringData = token4Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        FileManager.default.createDirectory(atPath: "pos-" + request.date5, withIntermediateDirectories: true, attributes: nil)
        let token5 = request.token5
        var token5Str = String(token5) + "$"
        let path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date5)
        if let stringData = token5Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }
    } else {
        FileManager.default.createDirectory(atPath: "neg-" + request.date1, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date1, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date1, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date1, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date1, withIntermediateDirectories: true, attributes: nil)
    }
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