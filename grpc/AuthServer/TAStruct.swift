import Foundation

// Testing Authority Server Structs

extension Data {
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
}

public extension UInt64 {
    var data: Data {
        return Swift.withUnsafeBytes(of: self) { Data($0) }
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
    
    func dayURL(date: Date) -> URL {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let documentDirectoryUrl = NSURL(fileURLWithPath: documentDirectory)
        let fileUrl = documentDirectoryUrl.appendingPathComponent(dayFilename(date: date))!.appendingPathExtension("txt")
        return fileUrl
    }

    func dayFilename(date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let name = String(month) + "-" + String(day)
        print("[dayURL] Today's date is: \(name)")
        return self.rawValue + name
    }
}

typealias UserIdToTEKs = [UInt64: [UInt64]]
extension UserIdToTEKs {
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
