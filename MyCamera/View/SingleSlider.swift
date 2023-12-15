//
//  SingleSlider.swift
//  JpegGreen
//
//  Created by zjj on 2023/12/14.
//

import SwiftUI

struct SingleSlider<Bound>: View where Bound: BinaryFloatingPoint {
    @Binding var value: Bound
    let range: ClosedRange<Bound>
    var foregroundColor: Color = .blue
    var backgroundColor: Color = .gray
    var onEditingChanged: (Bound) -> Void = { _ in }
    
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(backgroundColor)
                .overlay(alignment: .leading) {
                    let total = range.upperBound - range.lowerBound
                    let length = value - range.lowerBound
                    Rectangle()
                        .fill(foregroundColor)
                        .frame(width: geo.size.width * CGFloat(length / total))
                        .animation(.smooth, value: value)
                }
                .clipShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let rate = val.location.x / geo.size.width
                            handleDragWidthRate(Bound(rate))
                        }
                        .onEnded { v in
                            onEditingChanged(value)
                        }
                )
        }
    }
    
    func handleDragWidthRate(_ rateInWidth: Bound) {
        var rateInRange = (range.upperBound - range.lowerBound) * rateInWidth + range.lowerBound
        if rateInRange < range.lowerBound {
            rateInRange = range.lowerBound
        } else if (rateInRange > range.upperBound) {
            rateInRange = range.upperBound
        }
        value = rateInRange
    }
}

