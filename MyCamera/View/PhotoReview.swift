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
        .overlay(alignment: .topTrailing) {
            HStack {
                Spacer()
                Button {
                    presenting = false
                } label: {
                    Text("Close")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.gray)
                        .clipShape(Capsule(style: .circular))
                }
            }
            .frame(height: 44)
            .padding()
        }
    }
}
