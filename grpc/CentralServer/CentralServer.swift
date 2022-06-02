import GRPC
import centralModel
import NIOCore
import Foundation

class CentralProvider: Central_CentralProvider {
  var interceptors: Central_CentralServerInterceptorFactoryProtocol?

  func sendExposureKeys(
    request: Central_ExposureKeys,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Ack> {
    // write tokens to file, with delimiters
    if (request.pos == 1) {
        do {
          try FileManager.default.createDirectory(atPath: "pos-" + request.date1.date, withIntermediateDirectories: true, attributes: nil)
        } catch {
          print(error)
        }
        let token1 = request.token1
        let token1Str = String(token1) + "$"
        var path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date1.date)
        if let stringData = token1Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        do {
          try FileManager.default.createDirectory(atPath: "pos-" + request.date2.date, withIntermediateDirectories: true, attributes: nil)
        } catch {
          print(error)
        }
        let token2 = request.token2
        let token2Str = String(token2) + "$"
        path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date2.date)
        if let stringData = token2Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        do {
          try FileManager.default.createDirectory(atPath: "pos-" + request.date3.date, withIntermediateDirectories: true, attributes: nil)
        } catch {
          print(error)
        }
        let token3 = request.token3
        let token3Str = String(token3) + "$"
        path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date3.date)
        if let stringData = token3Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        do {
          try FileManager.default.createDirectory(atPath: "pos-" + request.date4.date, withIntermediateDirectories: true, attributes: nil)
        } catch {
          print(error)
        }
        let token4 = request.token4
        let token4Str = String(token4) + "$"
        path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date4.date)
        if let stringData = token4Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }

        do {
          try FileManager.default.createDirectory(atPath: "pos-" + request.date5.date, withIntermediateDirectories: true, attributes: nil)
        } catch {
          print(error)
        }
        let token5 = request.token5
        let token5Str = String(token5) + "$"
        path = FileManager.default.urls(for: .documentDirectory,
                                    in: .userDomainMask)[0].appendingPathComponent("pos-" + request.date5.date)
        if let stringData = token5Str.data(using: .utf8) {
                try? stringData.write(to: path)
        }
    } else {
        /*
        FileManager.default.createDirectory(atPath: "neg-" + request.date1.date, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date2.date, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date3.date, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date4.date, withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createDirectory(atPath: "neg-" + request.date5.date, withIntermediateDirectories: true, attributes: nil)
        */
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
      let x = UInt64(123)
      $0.token = [x];
    }
    return context.eventLoop.makeSucceededFuture(response)
  }

  func pollNegative(
    request: Central_Date,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Batch> {
    // need to pull tokens from appropriate file
    let response = Central_Batch.with {
      let x = UInt64(123)
      $0.token = [x];
    }
    return context.eventLoop.makeSucceededFuture(response)
  }
}