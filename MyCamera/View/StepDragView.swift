//
//  StepDragView.swift
//  MyCamera
//
//  Created by zjj on 2023/12/15.
//

import SwiftUI

struct StepDragView: View {
    @State private var lastOffset: CGFloat = 0
    @Binding var isDragging: Bool
    var stepDistance: CGFloat = 12
    let onStepToggled: (Int) -> Void
    
    var body: some View {
        let drag = DragGesture()
            .onChanged { value in
                isDragging = true
                let currentOffSet = -(value.location.y - value.startLocation.y)
                let thres: CGFloat = stepDistance
                if (currentOffSet - lastOffset > thres) {
                    lastOffset += thres
                    onStepToggled(1)
                } else if (currentOffSet - lastOffset <= -thres) {
                    lastOffset -= thres
                    onStepToggled(-1)
                }
            }
            .onEnded{ v in
                lastOffset = 0
                isDragging = false
            }
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .gesture(drag)
    }
}
