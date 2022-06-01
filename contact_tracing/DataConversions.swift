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
}

public extension String {
    var data: Data {
        return Data(self.utf8)
    }
}

public extension UInt64 {
    var data: Data {
        return Swift.withUnsafeBytes(of: self) { Data($0) }
    }
}
