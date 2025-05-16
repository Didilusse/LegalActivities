//
//  KalmanFilter.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation
class KalmanFilter {
    private var q: Double // Process noise
    private var r: Double // Measurement noise
    private var p: Double = 1.0 // Estimation error
    private var k: Double = 1.0 // Kalman Gain
    private var x: Double? // Estimated value
    
    init(q: Double = 0.1, r: Double = 5.0) {
        self.q = q
        self.r = r
    }
    
    func filter(_ measurement: Double) -> Double {
        if x == nil {
            x = measurement
            return measurement
        }
        
        // Prediction update
        p += q
        
        // Measurement update
        k = p / (p + r)
        x! += k * (measurement - x!)
        p *= (1 - k)
        
        return x!
    }
}
