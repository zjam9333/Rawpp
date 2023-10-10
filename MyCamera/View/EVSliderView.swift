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
                if (currentOffSet - lastInitOffset > 10) {
                    lastInitOffset += 10
                    print(lastInitOffset)
                    increaseEV()
                } else if (currentOffSet - lastInitOffset <= -10) {
                    lastInitOffset -= 10
                    print(lastInitOffset)
                    decreaseEV()
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
                        .fill(isSelected ? Color.yellow : Color.white)
                        .frame(width: isSelected ? 2 : 1, height: isInteger ? 12 : 8)
                }
            }
        }
        .gesture(drag)
    }
    
    func increaseEV() {
        print("increaseEV")
        guard let index = evs.firstIndex(of: value) else {
            print("ev index not found")
            return
        }
        let next = index + 1
        print("ev index found", index, "next", next, "total", evs.count)
        if next < evs.count {
            value = evs[next]
        }
        print("value", value)
    }
    
    func decreaseEV() {
        print("decreaseEV")
        guard let index = evs.firstIndex(of: value) else {
            print("ev index not found")
            return
        }
        let prev = index - 1
        print("ev index found", index, "prev", prev, "total", evs.count)
        if prev >= 0 {
            value = evs[prev]
        }
        print("value", value)
    }
}

struct EVSliderViewPreview: PreviewProvider {
    
    static var previews: some View {
        return _EVSliderViewPreviewV()
            .frame(width: 100, height: 100)
            .background(Color.black, ignoresSafeAreaEdges: .all)
    }
}

private struct _EVSliderViewPreviewV: View {
    @State var value: Float = 0
    var body: some View {
        EVSliderView(value: $value)
    }
}
