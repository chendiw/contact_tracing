import Foundation

typealias ENInterval = TimeInterval
extension ENInterval {
    static func value() -> Int {
//        return Int((Date().timeIntervalSince1970) / (10 * 60))
        return Int((Date().timeIntervalSince1970) / 10)
    }
    
    static func valueAtDate(date: Date) -> Int {
//        return Int((date.timeIntervalSince1970) / (10 * 60))
        return Int((date.timeIntervalSince1970) / 10)
    }
}

public extension Data {
    var uint64: UInt64 {
          get {
              if count >= 8 {
                  return self.withUnsafeBytes { $0.load(as: UInt64.self) }
              } else {
                  return (self + Data(repeating: 0, count: 8 - count)).uint64
              }
          }
      }
    
    var int: Int {
        return self.withUnsafeBytes{pointer in return pointer.load(as: Int.self)}
    }
    
    var hex: String {
        return map {String(format: "%02x", $0)}.joined()
    }
    
    var string: String {
        return String(decoding: self, as: UTF8.self)
    }
    
    var base64: String {
        return self.base64EncodedString()
    }
}

public extension String {
    var data: Data {
        let result = try! Data.init(base64Encoded: self, options:.ignoreUnknownCharacters)
        return result!
    }
}

public extension UInt64 {
    var data: Data {
        return Swift.withUnsafeBytes(of: self) { Data($0) }
    }
}

public extension Date {
    var localDay: Int {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: self)
        return day
    }
    
    var localMinute: Int {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: self)
        return minute
    }
    
    var dateString: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: self)
        let month = calendar.component(.month, from: self)
        let name = String(month) + "-" + String(day)
        return name
    }
    
    var minuteString: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let name = String(hour) + "-" + String(minute)
        return name
    }
}


enum TAFile: String {
    case receivedTEKFile
    case resultsFile

    var rawValue: String {
        switch self {
          case .receivedTEKFile: return "receivedTEKFile"
          case .resultsFile: return "resultsFile"
        }
    }

    func createFile(url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else {
            return
        }
        let emptyData: [UInt64: [UInt64]] = [0:[0]]
        do {
            let data = try JSONEncoder().encode(emptyData)
            try data.write(to: url)
        } catch {
            print("Save EmptyData Error: \(error)")
        }
    }
    
    func deleteFile(url: URL) {
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
        // let fileUrl = documentDirectoryUrl.appendingPathComponent(self.rawValue)!.appendingPathExtension("txt")
        // Experiment
        let fileUrl = documentDirectoryUrl.appendingPathComponent(self.rawValue)!.appendingPathExtension("txt")
        return fileUrl
    }
    
    func dayURL(date: Date) -> URL {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let documentDirectoryUrl = NSURL(fileURLWithPath: documentDirectory)
        // let fileUrl = documentDirectoryUrl.appendingPathComponent(dayFilename(date: date))!.appendingPathExtension("txt")
        // Experiment
        let fileUrl = documentDirectoryUrl.appendingPathComponent(minuteFilename(date: date))!.appendingPathExtension("txt")
        return fileUrl
    }

    func dayFilename(date: Date) -> String {
        return self.rawValue + date.dateString
    }

    func minuteFilename(date: Date) -> String {
        return self.rawValue + date.minuteString
    }
}

typealias UserIdToTEKs = [UInt64: [UInt64]]
extension UserIdToTEKs {
    static func load(from: TAFile) -> (UserIdToTEKs, Bool) {
        do {
            let data = try Data(contentsOf: from.url())
            do {
                let arr = try JSONDecoder().decode(self, from: data)
                print("[load from file] the loaded data is: \(arr)")
                return (arr, true)
            } catch {
                print(error)
            }
        } catch {
        }
        return (UserIdToTEKs(), false)
    }

    func save(to: TAFile) {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: to.url())
            print("[DaySave], save to file name \(to.url())")
        } catch {
            print("Save to file error: \(error)")
        }
    }

  static func dayLoad(from: TAFile, day: Date) -> (UserIdToTEKs, Bool) {
    do {
        let data = try Data(contentsOf: from.dayURL(date: day))
        do {
            let arr = try JSONDecoder().decode(self, from: data)
            print("[load from file] the loaded data is: \(arr)")
            return (arr, true)
        } catch {
            print(error)
        }
    } catch {
    }
    return (UserIdToTEKs(), false)
  }

  func daySave(to: TAFile, day: Date) {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: to.dayURL(date: day))
            print("[DaySave], save to file name \(to.dayURL(date: day))")
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

// extension Bool {
//     var data: Data {
//         var _self = self
//         return NSData(bytes: &_self, length: MemoryLayout.size(ofValue: self))
//     }

//     init?(data: NSData) {
//         guard data.length == 1 else { return nil }
//         var value = false
//         data.getBytes(&value, length: MemoryLayout<Bool>.size)
//         self = value
//     }
// }

// typealias UserIdToResult = [UInt64: Bool]
// extension UserIdToResult {
//   static func load(from: TAFile) -> UserIdToResult {
//     if let data = try? Data(contentsOf: from.url()) {
//         do {
//             let arr = try JSONDecoder().decode(self, from: data)
//             print("[load from file] the loaded data is: \(arr)")
//             return arr
//         } catch {
//             print(error)
//         }
//     }
//     return UserIdToResult()
//   }

//   func save(to: TAFile) {
//     do {
//         let data = try JSONEncoder().encode(self)
//         try data.write(to: to.url())
//     } catch {
//         print("Save to file error: \(error)")
//     }
//   }

//   mutating func add(userId: UInt64, result: Bool) {
//     assert(self[userId]== nil) 
//     self[userId] = result
//   }
// }
