//
//  RiskScoreController.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/5/25.
//

import Foundation

class RiskScoreController {
    private var riskScore: Int;
    
    init(){
        self.riskScore = -1  // Uninitialized risk Score
    }
    
    func getRisk() -> Int {
        return self.riskScore
    }
    
    func calculate() {
        // pull positive exposure key list and negtive exposure key list
        let positiveExpKey: [String] = []
        let negtiveExpKey: [String] = []
        
        let positiveTokens: [TokenObject] = []
        let negtiveTokens: [TokenObject] = []
        
        let date = Date()
        let calendar = Calendar.current
        let day = calendar.component(.hour, from: date)
        
        for i in 1...5 {
            let prevDate = Calendar.current.date(byAdding: .day, value: -i, to: date)
            let fileurl = File.dayURL(prevDate)
            
        }
        
        
    }
    
    
    
}
