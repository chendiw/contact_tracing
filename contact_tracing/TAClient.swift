//
//  TAClient.swift
//  contact_tracing
//
//  Created by Chendi Wu on 5/28/22.
//

import Foundation
import GRPC
import NIOCore
import NIOPosix

struct TestResultMsg: Codable {
    var taID: UInt64
    var seq: UInt64
    var result: UInt64
    var signature: UInt64
}

public class TAClient {
    var port: Int = 1234
    var host_ip: String = "localhost"
    var client: Testingauth_AuthClient
    var tested: Bool = false
    var getResult: Bool = false
    var result: TestResultMsg = TestResultMsg(taID: 0, seq: 0, result: 0, signature: 0)
    var userId: UInt64 = 0
    
    init() {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        // Make sure the group is shutdown when we're done with it.
//        defer {
//          try! group.syncShutdownGracefully()
//        }

        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try! GRPCChannelPool.with(
          target: .host(host_ip, port: port),
          transportSecurity: .plaintext,
          eventLoopGroup: group
        )

        // Close the connection when we're done with it.
//        defer {
//          try! channel.close().wait()
//        }
        
        // Provide the connection to the generated client.
        self.client = Testingauth_AuthClient(channel: channel)
    }
    
    public func prepStartTest() {
        // Construct list of pretest tokens (currently set to 3)
        let num_pretestTokens = 3
        let allTokens = TokenList.load(from: .myTEKs)
        let pretestTokenObjects: [TokenObject] = allTokens.suffix(num_pretestTokens)
        var pretestTokens: [UInt64] = []
        for t in pretestTokenObjects {
            pretestTokens.append(t.payload.uint64)
            print("cur pretestToken: \(pretestTokens.last)")
        }
        
        // Form the request with the name, if one was provided.
        let request = Testingauth_PretestTokens.with {
            $0.pretest = pretestTokens
        }

        // Make the RPC call to the server.
        let requestStartTest = self.client.startTest(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try requestStartTest.response.wait()
            self.tested = response.ack
            self.userId = response.userID
            print("Ack received: \(response.ack)")
        } catch {
            print("Start test failed: \(error)")
        }
    }
    
    public func prepGetResult() {
        let curTokenObject: TokenObject = TokenList.load(from: .myTEKs).last!
        let curToken: UInt64 = curTokenObject.payload.uint64
        
        // Form the request with the name, if one was provided.
        let request = Testingauth_Check.with {
            $0.userID = self.userId
            $0.date = Date.now.formatted()
            $0.token = curToken
        }

        // Make the RPC call to the server.
        let requestGetResult = self.client.getResult(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try requestGetResult.response.wait()
            print("Test result received: \(response.result)")
            // if result is not empty string
            if response.ready == true {
                self.getResult = true
                self.result = TestResultMsg(taID: response.taID, seq: response.seq, result: response.result, signature: response.signature)
            }
        } catch {
            print("Get Result failed: \(error)")
        }
    }
    
}
