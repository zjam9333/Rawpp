//
//  EVSliderView.swift
//  MyCamera
//
//  Created by zjj on 2023/10/10.
//

import SwiftUI

struct EVSliderView: View {
    @Binding var value: Float
    
    private let evs: [Float] = [-2, -1.66, -1.33, -1, -0.66, -0.33, 0, 0.33, 0.66, 1, 1.33, 1.66, 2]
    
    private let integerValues: Set<Float> = [-2, -1, 0, 1, 2]
    
    @State private var lastInitOffset: CGFloat = 0
    
    var body: some View {
        let drag = DragGesture()
            .onChanged { value in
                let currentOffSet = value.location.x - value.startLocation.x
                let thres: CGFloat = 8
                if (currentOffSet - lastInitOffset > thres) {
                    lastInitOffset += thres
                    increaseEV(step: 1)
                } else if (currentOffSet - lastInitOffset <= -thres) {
                    lastInitOffset -= thres
                    increaseEV(step: -1)
                }
            }
            .onEnded{ v in
                lastInitOffset = 0
            }
        VStack {
            Text(String(format: "EV %.1f", value)).font(.system(size: 12)).foregroundColor(.white)
            HStack(alignment: .bottom, spacing: 4) {
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
        .gesture(drag)
    }
    
    func increaseEV(step: Int) {
        guard let index = evs.firstIndex(of: value) else {
            value = 0
            return
        }
        let next = index + step
        print("ev index found", index, "next", next, "total", evs.count)
        if evs.indices.contains(next) {
            value = evs[next]
        }
        print("value", value)
    }
}

struct EVSliderViewPreview: PreviewProvider {
    static var value: Float = 0
    static var previews: some View {
        let bindingFloat = Binding<Float> {
            return value
        } set: { v in
            value = v
        }
        return EVSliderView(value: bindingFloat)
            .frame(width: 100, height: 100)
            .background(Color.black, ignoresSafeAreaEdges: .all)
    }
}
