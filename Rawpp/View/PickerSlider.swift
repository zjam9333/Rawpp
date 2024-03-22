//
//  PickerSlider.swift
//  MyCamera
//
//  Created by zjj on 2024/2/22.
//

import SwiftUI

struct PickerSlider<Item>: View where Item: Equatable {
    @Binding var value: Item
    let items: [Item]
    var foregroundColor: Color = .blue
    var backgroundColor: Color = .gray
    var onEditingChanged: (Item) -> Void = { _ in }
    
    var selectedIndex: Int? {
        return items.firstIndex { i in
            i == value
        }
    }
    var count: Int {
        return items.count
    }
    
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(backgroundColor)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(foregroundColor)
                        .frame(width: geo.size.width * CGFloat((selectedIndex ?? 0) + 1) / CGFloat(count))
                        .animation(.smooth, value: value)
                }
                .clipShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let rate = val.location.x / geo.size.width
                            handleDragWidthRate(rate)
                        }
                        .onEnded { v in
                            onEditingChanged(value)
                        }
                )
        }
    }
    
    func handleDragWidthRate(_ rateInWidth: CGFloat) {
        let ind = Int(rateInWidth * CGFloat(count))
        if items.indices.contains(ind) {
            value = items[ind]
        }
    }
}
