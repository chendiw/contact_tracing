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
    var fileName = String()
    var currentDirectoryUrl = URL(fileURLWithPath: ".")
    var fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
    // write tokens to file, with delimiters
    if (request.result.result == 1) {
        if request.hasDate1 {
          fileName = "pos-" + request.date1.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token1 = request.token1
          let token1Str = String(token1) + "$"
          do {
            try token1Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate2 {
          fileName = "pos-" + request.date2.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token2 = request.token2
          let token2Str = String(token2) + "$"
          do {
            try token2Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate3 {
          fileName = "pos-" + request.date3.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token3 = request.token3
          let token3Str = String(token3) + "$"
          do {
            try token3Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate4 {
          fileName = "pos-" + request.date4.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token4 = request.token4
          let token4Str = String(token4) + "$"
          do {
            try token4Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate5 {
          fileName = "pos-" + request.date5.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token5 = request.token5
          let token5Str = String(token5) + "$"
          do {
            try token5Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }
    } else {
        if request.hasDate2 {
          var fileName = "neg-" + request.date1.date
          var currentDirectoryUrl = URL(fileURLWithPath: ".")
          var fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token1 = request.token1
          let token1Str = String(token1) + "$"
          do {
            try token1Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate2 {
          fileName = "neg-" + request.date2.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token2 = request.token2
          let token2Str = String(token2) + "$"
          do {
            try token2Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate3 {
          fileName = "neg-" + request.date3.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token3 = request.token3
          let token3Str = String(token3) + "$"
          do {
            try token3Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate4 {
          fileName = "neg-" + request.date4.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token4 = request.token4
          let token4Str = String(token4) + "$"
          do {
            try token4Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }

        if request.hasDate5 {
          fileName = "neg-" + request.date5.date
          currentDirectoryUrl = URL(fileURLWithPath: ".")
          fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
          let token5 = request.token5
          let token5Str = String(token5) + "$"
          do {
            try token5Str.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
          } catch let error as NSError {
            print (error)
          }
        }
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
    let fileName = "pos-" + request.date
    let currentDirectoryUrl = URL(fileURLWithPath: ".")
    let fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
    let fileExists = (try? fileUrl.checkResourceIsReachable()) ?? false

    if (fileExists) {
      do {
        let contents = try String(contentsOf: fileUrl, encoding: .utf8)
        let lines = contents.split(separator:"$")
        let count = lines.count
        var resp: [UInt64] = []
        for i in 1...count {
          let keyStr = lines[i - 1]
          if let key = UInt64(keyStr) {
            resp.append(key)
          } else {
            // do nothing
          }
        }
        let response = Central_Batch.with {
          $0.token = resp;
        }
        return context.eventLoop.makeSucceededFuture(response)
      } catch {
        let response = Central_Batch.with {
          let x = UInt64(0)
          $0.token = [x];
        }
        return context.eventLoop.makeSucceededFuture(response)
      }
    } else {
      print("i didn't find a file with that date for pollPositive")
      let response = Central_Batch.with {
        let x = UInt64(0)
        $0.token = [x];
      }
      return context.eventLoop.makeSucceededFuture(response)
    }
  }

  func pollNegative(
    request: Central_Date,
    context: StatusOnlyCallContext
  ) -> EventLoopFuture<Central_Batch> {
    let fileName = "neg-" + request.date
    let currentDirectoryUrl = URL(fileURLWithPath: ".")
    let fileUrl = currentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("txt")
    let fileExists = (try? fileUrl.checkResourceIsReachable()) ?? false

    if (fileExists) {
      do {
        let contents = try String(contentsOf: fileUrl, encoding: .utf8)
        let lines = contents.split(separator:"$")
        let count = lines.count
        var resp: [UInt64] = []
        for i in 1...count {
          let keyStr = lines[i - 1]
          if let key = UInt64(keyStr) {
            resp.append(key)
          } else {
            // do nothing
          }
        }
        let response = Central_Batch.with {
          $0.token = resp;
        }
        return context.eventLoop.makeSucceededFuture(response)
      } catch {
        let response = Central_Batch.with {
          let x = UInt64(0)
          $0.token = [x];
        }
        return context.eventLoop.makeSucceededFuture(response)
      }
    } else {
      print("i didn't find a file with that date for pollNegative")
      let response = Central_Batch.with {
        let x = UInt64(0)
        $0.token = [x];
      }
      return context.eventLoop.makeSucceededFuture(response)
    }
  }
}