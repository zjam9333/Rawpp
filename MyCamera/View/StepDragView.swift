//
//  StepDragView.swift
//  MyCamera
//
//  Created by zjj on 2023/12/15.
//

import SwiftUI

struct StepDragView<Element>: View where Element: Equatable {
    @Binding var isDragging: Bool
    var stepDistance: CGFloat = 12
    @Binding var value: Element
    let items: [Element]
    var onStepToggled: () -> Void = {}
    
    class SomeObject: ObservableObject {
        var lastOffset: CGFloat = 0
    }
    
    @StateObject private var cacheObject = SomeObject()
    
    var body: some View {
        let drag = DragGesture()
            .onChanged { value in
                isDragging = true
                let currentOffSet = -(value.location.y - value.startLocation.y)
                let thres: CGFloat = stepDistance
                if (currentOffSet - cacheObject.lastOffset > thres) {
                    cacheObject.lastOffset += thres
                    toggleStep(step: 1)
                } else if (currentOffSet - cacheObject.lastOffset <= -thres) {
                    cacheObject.lastOffset -= thres
                    toggleStep(step: -1)
                }
            }
            .onEnded{ v in
                cacheObject.lastOffset = 0
                isDragging = false
            }
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .gesture(drag)
    }
    
    func toggleStep(step: Int) {
        onStepToggled()
        guard let index = items.firstIndex(of: value) else {
            if let fir = items.first {
                value = fir
            }
            return
        }
        let next = index + step
        if items.indices.contains(next) {
            value = items[next]
        }
    }
}
