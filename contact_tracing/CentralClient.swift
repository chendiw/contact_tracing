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
    func getPositiveCases() throws  -> [UInt64] {
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
            target: .host("localhost", port: 1234),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }

        // Provide the connection to the generated client.
        let central_client = Central_CentralClient(channel: channel)

        /*let formatter = DateFormatter()
        let now = Date()
        let dateString = formatter.string(from:now)*/
        let request = Central_Date.with {
            $0.date = "date1"
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
    
    func getNegativeCases() throws -> [UInt64]{
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
            target: .host("localhost", port: 1234),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }

        // Provide the connection to the generated client.
        let central_client = Central_CentralClient(channel: channel)

        let formatter = DateFormatter()
        let now = Date()
        let dateString = formatter.string(from:now)
        let request = Central_Date.with {
            $0.date = dateString
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
    
    func sendExposureKeys() throws {
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
            target: .host("localhost", port: 1234),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )

        // Close the connection when we're done with it.
        defer {
            try! channel.close().wait()
        }

        // Provide the connection to the generated client.
        let central_client = Central_CentralClient(channel: channel)
        
        let date = Date()
        let dateFormatter = DateFormatter()
        
        let request = Central_ExposureKeys.with { // this also works with
            $0.token1 = TokenList.dayLoad(from: .myExposureKeys, day: date).0[0].payload.uint64;
            $0.token2 = TokenList.dayLoad(from: .myExposureKeys, day: date).0[0].payload.uint64;
            $0.token3 = TokenList.dayLoad(from: .myExposureKeys, day: date).0[0].payload.uint64;
            $0.token4 = TokenList.dayLoad(from: .myExposureKeys, day: date).0[0].payload.uint64;
            $0.token5 = TokenList.dayLoad(from: .myExposureKeys, day: date).0[0].payload.uint64;
            $0.date1.date = dateFormatter.string(from: date);
            $0.date2.date = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: date)!);
            $0.date3.date = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -2, to: date)!);
            $0.date4.date = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -3, to: date)!);
            $0.date5.date = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -4, to: date)!);
            $0.pos = 1; // TODO: this needs to be updatted to be the value from the test
        }

        // Make the RPC call to the server.
        let report = central_client.sendExposureKeys(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            let response = try report.response.wait()
            print("report token : succeeded: \(response.ack)")
        } catch {
            print("report token : \(error)")
        }
    }
}

