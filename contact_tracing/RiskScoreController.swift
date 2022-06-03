//
//  RiskScoreController.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/5/25.
//

import Foundation
import CoreLocation

class RiskScoreController {
    //TODO: get global nonce from TokenController.nonce
    var nonce = TokenController.nonce
    private var riskScore: Int;
    private var riskDays: Int = 5; // How long time do we care about
    
    private var highRisk: Int = 70; // higher than 70 is high risk
    private var lowRisk: Int = 30; // lower than 30 is No risk, between 30-70 low risk
    private var baseRisk: Int = 50;
    
    private var GPSRange: Int = 5;  // distance in meters.
    
    private var centralClient: CentralClient = CentralClient()
    
    
    init(){
        self.riskScore = -1  // Uninitialized risk Score
    }
    
    func getRisk() -> Int {
        return self.riskScore
    }
    
    func getLevel() -> String {
        if self.riskScore >= 70 {
            return "High Risk"
        }else if self.riskScore <= 30 {
            return "Low Risk"
        }else{
            return "Midium Risk"
        }
    }
    
    func calculate() {
        let date = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        // for i in 1.. 5 pull positive exposure key list and negtive exposure key list
        var positiveExpKey: [Date: [UInt64]] = [:] // call poll positive
        var negtiveExpKey: [Date: [UInt64]] = [:] // call poll negtive
        
        
        var positiveTokens: Set<UInt64> = []  // date -> token payload
        var negtiveTokens: Set<UInt64> = []
        
        var allPeerTEKs: [UInt64] = []
        for i in 1...riskDays {
            // Using the positive key, caculate all the positive tokens
            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: date)!
            if !TokenList.dayLoad(from: .peerTokens, day: prevDate).1 {
                break
            }
            // File exists
            let peerTEKs = TokenList.dayLoad(from: .peerTokens, day: prevDate).0
            for tks in peerTEKs{
                allPeerTEKs.append(tks.payload.uint64)
            }
            print("AllPeerTEKs is \(allPeerTEKs)")
        }
        
        for i in 1...riskDays{
            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: date)!
            // TODO: call the pollpositive function here.
            var posExpKeys: [UInt64] = []
            var negExpKeys: [UInt64] = []
            do {
                posExpKeys = try self.centralClient.getPositiveCases()
                negExpKeys = try self.centralClient.getPositiveCases()
            } catch {
                print("Error when poll positive Exposure Keys and Negtive Exposuer keys")
            }
            positiveExpKey[prevDate] = posExpKeys
            negtiveExpKey[prevDate] = negExpKeys
            let posTokens: Set<UInt64> = regenRPIs(expKeys: posExpKeys, nonce: nonce)
            let negTokens: Set<UInt64>  = regenRPIs(expKeys: negExpKeys, nonce: nonce)
            // Intersection between
            let segAll:Set<UInt64> = Set(allPeerTEKs)
            
            positiveTokens = segAll.intersection(posTokens)
            negtiveTokens = segAll.intersection(negTokens)
            
        }
        
        var positivePeers: [TokenObject] = []
//        var negtivePeers:  [TokenObject] = []
        var positiveGPS: [[CLLocationDegrees]] = [] // (lat, long)
        
        for i in 1...riskDays {
            // Using the positive key, caculate all the positive tokens
            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: date)!
            if !TokenList.dayLoad(from: .peerTokens, day: prevDate).1 {
                break
            }
            // File exists
            let peerTEKs = TokenList.dayLoad(from: .peerTokens, day: prevDate).0
            var payloadsHaveSeen: [Data] = []
            for token in peerTEKs {
                if payloadsHaveSeen.contains(token.payload) == false {
                    if positiveTokens.contains(token.payload.uint64) {
                        positivePeers.append(token)
                        positiveGPS.append([token.lat, token.long])
                        self.riskScore = min(self.riskScore + 10, self.baseRisk)
                    }
                }
                payloadsHaveSeen.append(token.payload)
            }
            payloadsHaveSeen = []
            for token in peerTEKs {
                if payloadsHaveSeen.contains(token.payload) == false {
                    if negtiveTokens.contains(token.payload.uint64) {  // have negtive report
//                        var isSameLocation: Bool = false;
                        for locs in positiveGPS {
                            let positiveLoc = CLLocation(latitude: locs[0], longitude: locs[1])
                            let
                            = CLLocation(latitude: token.lat, longitude: token.long)
                            if positiveLoc.distance(from: curLoc) < 5 {  // less than 5m -> In the same room
                                self.riskScore = max(0, self.riskScore - 10)
                            }
                        }
                    }
                }
                payloadsHaveSeen.append(token.payload)
            }
            // TODO: add rssi. How to devide a reasonable
            
        }
    }
}
