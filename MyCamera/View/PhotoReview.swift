//
//  PhotoReview.swift
//  MyCamera
//
//  Created by zjj on 2023/11/30.
//

import SwiftUI

struct PhotoReview: View {
    let photos: [Photo]
    @Binding var presenting: Bool
    
    @State var currentTag: Int = 0
    
    var body: some View {
        VStack {
            if photos.isEmpty == false {
                TabView(selection: $currentTag) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, p in
                        if let img = UIImage(data: p.data) {
                            let rate = img.size.width / img.size.height
                            ZoomView(presenting: index == currentTag, contentAspectRatio: rate) {
                                Image(uiImage: img)
                                    .resizable()
                            } shouldDragDismiss: { offset in
                                if offset < -100 {
                                    presenting = false
                                }
                            }
                            .tag(index)
                        } else {
                            EmptyView().tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .overlay(alignment: .bottom) {
            Group {
                Button {
                    presenting = false
                } label: {
                    Text("Close")
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(width: 280, height: 44)
                        .background(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding()
        }
    }
}
