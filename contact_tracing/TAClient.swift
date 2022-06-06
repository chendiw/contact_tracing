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

public class TAClient {
    var port: Int = 1234
    var host_ip: String = "54.80.128.235"
    let pretest_days: Int = 3
    
//    var client: Testingauth_AuthClient
    var tested: Bool = false
    var getResult: Bool = false
    var result: Testingauth_TestResult = Testingauth_TestResult.with {
        $0.ready = false
        $0.taID = 0
        $0.seq = String()
        $0.result = 0
        $0.signature = String()
    }
    var userId: UInt64 = 0
    
    public func prepStartTest() {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        // Make sure the group is shutdown when we're done with it.
        defer {
          try! group.syncShutdownGracefully()
        }

        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try! GRPCChannelPool.with(
          target: .host(host_ip, port: port),
          transportSecurity: .plaintext,
          eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
          try! channel.close().wait()
        }
        
        // Provide the connection to the generated client.
        let client = Testingauth_AuthClient(channel: channel)
        
        var pretestExpKeys: [UInt64] = []
        for i in 0...self.pretest_days{
//            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            //Experiment
            let prevDate = Calendar.current.date(byAdding: .minute, value: -i, to: Date())!
            if !TokenList.dayLoad(from: .myExposureKeys, day: prevDate).1 {
                break
            }
            // File exists
            pretestExpKeys.append(TokenList.dayLoad(from: .myExposureKeys, day: prevDate).0[0].payload.uint64)
        }
        print("Sent pretestExpKeys: \(pretestExpKeys) at: \(Date().minuteString)")
        
        // Form the request with the name, if one was provided.
        let request = Testingauth_PretestTokens.with {
            $0.pretest = pretestExpKeys
        }

        // Make the RPC call to the server.
        let requestStartTest = client.startTest(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try requestStartTest.response.wait()
            self.tested = response.ack
            self.userId = response.userID
            print("Ack received: \(response.ack) with userId: \(self.userId)")
        } catch {
            print("Start test failed: \(error)")
        }
    }
    
    public func prepGetResult() -> Testingauth_TestResult {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        // Make sure the group is shutdown when we're done with it.
        defer {
          try! group.syncShutdownGracefully()
        }

        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try! GRPCChannelPool.with(
          target: .host(host_ip, port: port),
          transportSecurity: .plaintext,
          eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
          try! channel.close().wait()
        }
        
        // Provide the connection to the generated client.
        let client = Testingauth_AuthClient(channel: channel)
        
        assert(TokenList.dayLoad(from: .myExposureKeys, day: Date()).1)
        let curTokenObject: TokenObject = TokenList.dayLoad(from: .myExposureKeys, day: Date()).0.first!
        let curToken: UInt64 = curTokenObject.payload.uint64
        
        print("Request update at date: \(Date().dateString) for token: \(curToken)")
        // Form the request with the name, if one was provided.
        let request = Testingauth_Check.with {
            $0.userID = self.userId
            $0.date = Date().dateString
            $0.token = curToken
        }

        // Make the RPC call to the server.
        let requestGetResult = client.getResult(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try requestGetResult.response.wait()
            print("Test result received: \(response.result)")
            // if result is not empty string
            if response.ready == true {
                self.getResult = true
                self.result = Testingauth_TestResult.with {
                    $0.ready = true
                    $0.taID = response.taID
                    $0.seq = response.seq
                    $0.result = response.result
                    $0.signature = response.signature
                }
                print("Test result ready! Result is: \(response.result)")
            } else {
                print("Test result not ready!")
            }
        } catch {
            print("Get Result failed: \(error)")
        }
        return self.result
    }
    
}
