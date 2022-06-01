//
//  RiskScoreController.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/5/25.
//

import Foundation
import CoreLocation

class RiskScoreController {
    private var riskScore: Int;
    private var riskDays: Int = 5; // How long time do we care about
    
    private var highRisk: Int = 70; // higher than 70 is high risk
    private var lowRisk: Int = 30; // lower than 30 is No risk, between 30-70 low risk
    private var baseRisk: Int = 50;
    
    private var GPSRange: Int = 5;  // distance in meters.
    
    
    init(){
        self.riskScore = -1  // Uninitialized risk Score
    }
    
    func getRisk() -> Int {
        return self.riskScore
    }
    
    func calculate() {
        // for i in 1.. 5 pull positive exposure key list and negtive exposure key list
        let positiveExpKey: [Date: [String]] = [:]  // call poll positive
        let negtiveExpKey: [Date: [String]] = [:] // call poll negtive
        
        // generate all the positive tokens in last
        var positiveTokens: [Data] = []  // date -> token payload
        var negtiveTokens: [Data] = []
        
        let date = Date()
        let calendar = Calendar.current
        let day = calendar.component(.hour, from: date)
        
        var positivePeers: [TokenObject] = []
        var negtivePeers:  [TokenObject] = []
        var positiveGPS: [[CLLocationDegrees]] = [] // (lat, long)
        
        for i in 1...riskDays {
            // Using the positive key, caculate all the positive tokens
            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: date)!
            let fileurl = File.peerTokens.dayURL(date: prevDate)
            let peerTEKs = TokenList.load(from: .peerTokens)
            var payloadsHaveSeen: [Data] = []
            for token in peerTEKs {
                if payloadsHaveSeen.contains(token.payload) == false {
                    if positiveTokens.contains(token.payload) {
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
                    if negtiveTokens.contains(token.payload) {  // have negtive report
                        var isSameLocation: Bool = false;
                        for locs in positiveGPS {
                            let positiveLoc = CLLocation(latitude: locs[0], longitude: locs[1])
                            let curLoc = CLLocation(latitude: token.lat, longitude: token.long)
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
