//
//  RiskScoreController.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/5/25.
//

import Foundation
import CoreLocation

class RiskScoreController {

//    var nonce = TokenController.nonce
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
        var negativeExpKey: [Date: [UInt64]] = [:] // call poll negtive
        var posExpKeySet: [UInt64] = []
        var negExpKeySet: [UInt64] = []
        
        var positiveTokens: [Data: Set<UInt64>] = [:] // nonce --> set: Currently update riskscore by the number of positive contact cases instead of taking duration into account
        var negativeTokens: [Data: Set<UInt64>] = [:]
        
        var allPeerTEKs: [Data: Set<UInt64>] = [:] // nonce --> peer tokens corresponding to a nonce received over the past riskDays
        var prevDates: [Date] = []
        for i in 0..<riskDays {
            prevDates.append(Calendar.current.date(byAdding: .minute, value: -i, to: Date())!)
        }
        
        for prevDate in prevDates {
            // Using the positive key, caculate all the positive tokens
//            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            
            if !TokenList.dayLoad(from: .peerTokens, day: prevDate).1 {
                continue
            }
            // File exists
            let peerTEKs = TokenList.dayLoad(from: .peerTokens, day: prevDate).0
            for tokenobj in peerTEKs {
                if allPeerTEKs[tokenobj.nonce] == nil {
                    allPeerTEKs[tokenobj.nonce] = Set([tokenobj.payload.uint64])
                } else {
                    allPeerTEKs[tokenobj.nonce] = allPeerTEKs[tokenobj.nonce]!.union(Set([tokenobj.payload.uint64]))
                }
            }
        }
//        print("All peer tokens over risk period: \(allPeerTEKs)")
        
        // Only poll for risk days
//        let lower_bound : Date = Calendar.current.date(byAdding: .day, value: -riskDays, to: Date())!
        // Experiment
        let lower_bound : Date = Calendar.current.date(byAdding: .minute, value: -riskDays, to: Date())!
        let upper_bound : Date = Date()
        
        // regenerate peer tokens from the exposure keys on prevDate
        // construct an aggregate set of positiveTokns/negativeTokens for all riskDay
//        for prevDate in allPeerTEKs.keys {
        for prevDate in prevDates {
            // Experiment
            do {
                positiveExpKey[prevDate] = try self.centralClient.getPositiveCases(date: prevDate)
//                print("Polled positive expKeys: \(positiveExpKey[prevDate]) on date \(prevDate.minuteString)")
                posExpKeySet.append(positiveExpKey[prevDate]![0])
            } catch {
                print("Error when poll positive Exposure Keys")
                positiveExpKey[prevDate] = []
            }
            
            do {
                negativeExpKey[prevDate] = try self.centralClient.getNegativeCases(date: prevDate)
//                print("Polled negative expKeys: \(negativeExpKey[prevDate]) on date \(prevDate.minuteString)")
                negExpKeySet.append(negativeExpKey[prevDate]![0])
            } catch {
                print("Error when poll negative Exposure Keys")
                negativeExpKey[prevDate] = []
            }
        }
        
        for nonce in allPeerTEKs.keys {
            var posTokens = regenRPIs(expKeys: posExpKeySet, nonce: nonce)
            var negTokens = regenRPIs(expKeys: negExpKeySet, nonce: nonce)
            positiveTokens[nonce] = posTokens.intersection(allPeerTEKs[nonce]!)
            negativeTokens[nonce] = negTokens.intersection(allPeerTEKs[nonce]!)
            print("Aggregate positive tokens: \(positiveTokens)")
            print("Aggregate negative tokens: \(negativeTokens)")
        }
        
        var positivePeers: [TokenObject] = []
        var positiveGPS: [[CLLocationDegrees]] = [] // (lat, long)
        
        for nonce in allPeerTEKs.keys {
            for prevDate in prevDates {
                // File exists
                let peerTEKs = TokenList.dayLoad(from: .peerTokens, day: prevDate).0
                var nonceHaveSeen: Set<UInt64> = Set()
                for token in peerTEKs {
                    if nonceHaveSeen.contains(token.nonce.uint64) == false {
                        if positiveTokens[nonce]!.contains(token.payload.uint64) { // have positive report
                            positivePeers.append(token)
                            positiveGPS.append([token.lat, token.long])
                            let rssi = token.rssi
                            let dist = self.RSSI_alpha * pow(10, Double(rssi * (-1) / 4))
                            if dist < 1 {
                                self.riskScore += 10 * (1 + 0.128)
                            } else {
                                self.riskScore += 10 * (1 + 0.026)
                            }
//                            break
                        }
                    }
                    nonceHaveSeen.insert(token.nonce.uint64)
                }
//                print("Risk score after computing positives: \(self.riskScore)")
                
                nonceHaveSeen = []
                for token in peerTEKs {
                    if nonceHaveSeen.contains(token.nonce.uint64) == false {
                        if negativeTokens[nonce]!.contains(token.payload.uint64) {  // have negtive report
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
//                                break
                            }
                        }
                    }
                    nonceHaveSeen.insert(token.nonce.uint64)
                }
//                print("Risk score after computing negatives: \(self.riskScore)")
            }
        }
        print("Updated risk score: \(self.riskScore)")
    }
}
