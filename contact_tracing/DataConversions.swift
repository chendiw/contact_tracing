//
//  DataConversions.swift
//  contact_tracing
//
//  Created by Chendi Wu on 5/28/22.
//

import Foundation

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
