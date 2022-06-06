//
//  RiskScoreController.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/5/25.
//

import Foundation
import CoreLocation

class RiskScoreController {

    var nonce = TokenController.nonce
    private var riskScore: Double;
    private var riskDays: Int = 5; // How long time do we care about
    
    private var highRisk: Int = 70; // higher than 70 is high risk
    private var lowRisk: Int = 30; // lower than 30 is No risk, between 30-70 low risk
    
    private var GPSRange: Double = 3;  // distance in meters.
    
    private var RSSI_alpha = 1/(pow(10, 12.5)); // alpha set to 1/(10^12.5) after experiment
    
    private var centralClient: CentralClient = CentralClient()
    
    init(){
        self.riskScore = 0  // Uninitialized risk Score
    }
    
    func getRisk() -> Int {
        return Int(self.riskScore)
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
        // for i in 1.. 5 pull positive exposure key list and negtive exposure key list
        var positiveExpKey: [Date: [UInt64]] = [:] // call poll positive
        var negtiveExpKey: [Date: [UInt64]] = [:] // call poll negtive
        
        var positiveTokens: Set<UInt64> = []  // date -> token payload
        var negativeTokens: Set<UInt64> = []
        
        var allPeerTEKs: [Date: Set<UInt64>] = [:] // all peer tokens received over the past riskDays
        for i in 1...riskDays {
            // Using the positive key, caculate all the positive tokens
//            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            
            // Experiment
            let prevDate = Calendar.current.date(byAdding: .minute, value: -i, to: Date())!
            
            if !TokenList.dayLoad(from: .peerTokens, day: prevDate).1 {
                continue
            }
            // File exists
            let peerTEKs = TokenList.dayLoad(from: .peerTokens, day: prevDate).0
            allPeerTEKs[prevDate] = Set<UInt64>(peerTEKs.map{$0.payload.uint64})
            print("Peer tokens stored: \(allPeerTEKs)")
        }
        
        // Only poll for risk days
//        let lower_bound : Date = Calendar.current.date(byAdding: .day, value: -riskDays, to: Date())!
        // Experiment
        let lower_bound : Date = Calendar.current.date(byAdding: .minute, value: -riskDays, to: Date())!
        let upper_bound : Date = Date()
        
        // regenerate peer tokens from the exposure keys on prevDate
        // construct an aggregate set of positiveTokns/negativeTokens for all riskDay
        for prevDate in allPeerTEKs.keys {
            // Experiment
            if prevDate.localMinute - lower_bound.localMinute < 0 {
                continue
            }
            do {
                positiveExpKey[prevDate] = try self.centralClient.getPositiveCases(date: prevDate)
            } catch {
                print("Error when poll positive Exposure Keys")
                positiveExpKey[prevDate] = []
            }
            print("Polled positive expKeys: \(positiveExpKey[prevDate])")
            
            do {
                negtiveExpKey[prevDate] = try self.centralClient.getNegativeCases(date: prevDate)
            } catch {
                print("Error when poll negative Exposure Keys")
                negtiveExpKey[prevDate] = []
            }
            print("Polled negative expKeys: \(negtiveExpKey[prevDate])")

            // reproduce tokens for prevDate given exposure keys
            var posTokens: Set<UInt64> = Set()
            var negTokens: Set<UInt64> = Set()
            if positiveExpKey[prevDate]!.count != 0 {
                posTokens = regenRPIs(expKeys: positiveExpKey[prevDate]!, nonce: nonce)
            }
            if negtiveExpKey[prevDate]!.count != 0 {
                negTokens = regenRPIs(expKeys: negtiveExpKey[prevDate]!, nonce: nonce)
            }
//            print("regenerated positive tokens: \(posTokens)")
//            print("regenerated negative tokens: \(negTokens)")
            
            // Intersection between
            if (allPeerTEKs[prevDate] != nil) {
                print("Start computing intersection...")
                let segAll:Set<UInt64> = Set(allPeerTEKs[prevDate]!)
                print("segAll:\(segAll)")
                positiveTokens.formUnion(segAll.intersection(posTokens))
                negativeTokens.formUnion(segAll.intersection(negTokens))
                print("segall intersect pos: \(segAll.intersection(posTokens))")
                print("segall intersect neg: \(segAll.intersection(posTokens))")
            }
            print("Aggregate positive tokens: \(positiveTokens)")
            print("Aggregate negative tokens: \(negativeTokens)")
        }
        
        var positivePeers: [TokenObject] = []
//        var negtivePeers:  [TokenObject] = []
        var positiveGPS: [[CLLocationDegrees]] = [] // (lat, long)
        
        for prevDate in allPeerTEKs.keys {
            // File exists
            let peerTEKs = TokenList.dayLoad(from: .peerTokens, day: prevDate).0
            var payloadsHaveSeen: Set<UInt64> = []
            for token in peerTEKs {
                if payloadsHaveSeen.contains(token.payload.uint64) == false {
                    if positiveTokens.contains(token.payload.uint64) { // have positive report
                        positivePeers.append(token)
                        positiveGPS.append([token.lat, token.long])
                        let rssi = token.rssi
                        let dist = self.RSSI_alpha * pow(10, Double(rssi * (-1) / 4))
                        if dist < 1 {
                            self.riskScore += 20 * (1 + 0.128)
                        } else {
                            self.riskScore += 20 * (1 + 0.026)
                        }
                    }
                }
                payloadsHaveSeen.insert(token.payload.uint64)
            }
            print("Risk score after computing positives: \(self.riskScore)")
            
            payloadsHaveSeen = []
            for token in peerTEKs {
                if payloadsHaveSeen.contains(token.payload.uint64) == false {
                    if negativeTokens.contains(token.payload.uint64) {  // have negtive report
                        for locs in positiveGPS {
                            let positiveLoc = CLLocation(latitude: locs[0], longitude: locs[1])
                            let curloc = CLLocation(latitude: token.lat, longitude: token.long)
                            if positiveLoc.distance(from: curloc) < self.GPSRange {  // less than 3m -> Close enough to be indicator that virus is no longer contagious
                                let rssi = token.rssi
                                let dist = self.RSSI_alpha * pow(10, Double(rssi * (-1) / 4))
                                if dist < 1 {
                                    self.riskScore -= 4 * (1 + 0.128)
                                } else {
                                    self.riskScore -= 4 * (1 + 0.026)
                                }
                            }
                        }
                    }
                }
                payloadsHaveSeen.insert(token.payload.uint64)
            }
            print("Risk score after computing negatives: \(self.riskScore)")
        }
    }
}
