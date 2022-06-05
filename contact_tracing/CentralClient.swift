//
//  CentralClient.swift
//  contact_tracing
//
//  Created by Angela Montemayor on 6/1/22.
//

import Foundation
import GRPC
import NIOCore
import NIOPosix

class CentralClient {
    var port: Int = 1235
    var host_ip: String = "54.80.128.235"
    
    func getPositiveCases(date: Date) throws  -> [UInt64] {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Make sure the group is shutdown when we're done with it.
        defer {
            try! group.syncShutdownGracefully()
        }
        
        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try GRPCChannelPool.with(
            target: .host(self.host_ip, port: self.port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }

        // Provide the connection to the generated client.
        let central_client = Central_CentralClient(channel: channel)

        let request = Central_Date.with {
            $0.date = date.dateString
        }

        // Make the RPC call to the server.
        let getPosCases = central_client.pollPositive(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try getPosCases.response.wait()
            print("Get Positive Cases: succeeded: \(response.token)")
            return response.token
        } catch {
            print("Get Positive Cases failed: \(error)")
            return []
        }
    }
    
    func getNegativeCases(date: Date) throws -> [UInt64]{
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Make sure the group is shutdown when we're done with it.
        defer {
            try! group.syncShutdownGracefully()
        }
        
        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try GRPCChannelPool.with(
            target: .host(self.host_ip, port: self.port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }

        // Provide the connection to the generated client.
        let central_client = Central_CentralClient(channel: channel)

        let request = Central_Date.with {
            $0.date = date.dateString
        }

        // Make the RPC call to the server.
        let getNegCases = central_client.pollNegative(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try getNegCases.response.wait()
            print("Get Negative Cases: succeeded: \(response.token)")
            return response.token
        } catch {
            print("Get Negative Cases failed: \(error)")
            return []
        }
    }
    
    func sendExposureKeys(result: Testingauth_TestResult) throws -> Int32 {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Make sure the group is shutdown when we're done with it.
        defer {
            try! group.syncShutdownGracefully()
        }
        
        // Configure the channel, we're not using TLS so the connection is `insecure`.
        let channel = try GRPCChannelPool.with(
            target: .host(self.host_ip, port: self.port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }

        // Provide the connection to the generated client.
        let central_client = Central_CentralClient(channel: channel)
        
        var date = Date()
        date = Calendar.current.date(byAdding: .minute, value: -1, to: date)!  // for test
        let dateFormatter = DateFormatter()
        
        print("Client side date1 raw: \(date)")
        print("Client side date1: \(date.minuteString)")
        print("Client side date2: \(Calendar.current.date(byAdding: .minute, value: -1, to: date)!.minuteString)")
        
        let request = Central_ExposureKeys.with { // this also works with
            $0.token1 = TokenList.dayLoad(from: .myExposureKeys, day: date).0[0].payload.uint64;
            $0.token2 = TokenList.dayLoad(from: .myExposureKeys, day: Calendar.current.date(byAdding: .minute, value: -1, to: date)!).0[0].payload.uint64;
            $0.token3 = TokenList.dayLoad(from: .myExposureKeys, day: Calendar.current.date(byAdding: .minute, value: -2, to: date)!).0[0].payload.uint64;
            $0.token4 = TokenList.dayLoad(from: .myExposureKeys, day: Calendar.current.date(byAdding: .minute, value: -3, to: date)!).0[0].payload.uint64;
            $0.token5 = TokenList.dayLoad(from: .myExposureKeys, day: Calendar.current.date(byAdding: .minute, value: -4, to: date)!).0[0].payload.uint64;
            $0.date1.date = date.minuteString;
            $0.date2.date = Calendar.current.date(byAdding: .minute, value: -1, to: date)!.minuteString;
            $0.date3.date = Calendar.current.date(byAdding: .minute, value: -2, to: date)!.minuteString;
            $0.date4.date = Calendar.current.date(byAdding: .minute, value: -3, to: date)!.minuteString;
            $0.date5.date = Calendar.current.date(byAdding: .minute, value: -4, to: date)!.minuteString;
            $0.result = Central_TestResult.with{
                $0.ready = result.ready
                $0.taID = result.taID
                $0.seq = result.seq
                $0.result = result.result
                $0.signature = result.signature
            };
        }

        // Make the RPC call to the server.
        let report = central_client.sendExposureKeys(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try report.response.wait()
            print("send exposure key : succeeded: \(response.ack)")
            return response.ack
        } catch {
            print("send exposure key : \(error)")
            return 0
        }
    }
}

