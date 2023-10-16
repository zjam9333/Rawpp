//
//  EVSliderView.swift
//  MyCamera
//
//  Created by zjj on 2023/10/10.
//

import SwiftUI

struct EVValue: Equatable, Hashable {
    let rawValue: Float
    
    var text: String {
        return String(format: "%.1f", rawValue)
    }
    
    static let zero = EVValue(rawValue: 0)
    
    static let presetEVs: [EVValue] = {
        let ints = integerValues.sorted { v1, v2 in
            return v1.rawValue < v2.rawValue
        }
        var steps = [EVValue]()
        for f in ints {
            steps.append(f)
            if f.rawValue < 5 {
                steps.append(.init(rawValue: f.rawValue + 0.33))
                steps.append(.init(rawValue: f.rawValue + 0.66))
            }
        }
        return steps
    }()
    
    static let integerValues: Set<EVValue> = {
        let floats: [EVValue] = (-5...5).map { r in
            return EVValue(rawValue: Float(r))
        }
        return Set(floats)
    }()
}
