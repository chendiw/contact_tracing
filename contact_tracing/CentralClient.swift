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
    static func getPositiveCases() throws {
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

        let request = Central_Date.with {
            $0.date = "1/1/2022"
        }

        // Make the RPC call to the server.
        let getPosCases = central_client.pollPositive(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            //let response = try getPosCases.response.wait()
            let _ = try getPosCases.response.wait()
            print("Get Positive Cases: succeeded")
        } catch {
            print("Get Positive Cases failed: \(error)")
        }
    }
    
    static func getNegativeCases() throws {
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

        let request = Central_Date.with {
            $0.date = "1/1/2022"
        }

        // Make the RPC call to the server.
        let getNegCases = central_client.pollNegative(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            //let response = try getNegCases.response.wait()
            let _ = try getNegCases.response.wait()
            print("Get Negative Cases: succeeded")
        } catch {
            print("Get Negative Cases failed: \(error)")
        }
    }
    
    static func sendReportToken() throws {
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

        let request = Central_ExposureKeys.with {
            $0.token1 = 1209024
        }

        // Make the RPC call to the server.
        let report = central_client.sendExposureKeys(request)

        // wait() on the response to stop the program from exiting before the response is received.
        do {
            //let response = try getNegCases.response.wait()
            let _ = try report.response.wait()
            print("report token : succeeded")
        } catch {
            print("report token : \(error)")
        }
    }
}

