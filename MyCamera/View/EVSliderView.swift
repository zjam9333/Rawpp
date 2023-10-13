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

struct EVSliderView: View {
    
    @Binding var value: EVValue
    let evs: [EVValue]
    
    private let integerValues = EVValue.integerValues
    
    var body: some View {
        HStack(spacing: 8) {
            Text(String(format: "EV %.1f", value.rawValue)).font(.system(size: 12)).foregroundColor(.white)
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(evs, id: \.self) { ev in
                    let isSelected = value == ev
                    let isInteger = integerValues.contains(ev)
                    Rectangle()
                        .fill(isSelected ? Color.yellow : Color.white.opacity(0.8))
                        .frame(width: isSelected ? 2 : 1, height: isInteger ? 12 : 8)
                        .animation(.default, value: value)
                }
            }
        }
    }
}

struct EVSliderViewPreview: PreviewProvider {
    static var previews: some View {
        return EVSliderView(value: .constant(.zero), evs: EVValue.presetEVs)
            .frame(width: 100, height: 100)
            .background(Color.black, ignoresSafeAreaEdges: .all)
    }
}
