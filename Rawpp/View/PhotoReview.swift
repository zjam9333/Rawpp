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
                        if let data = p.data, let img = UIImage(data: data) {
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
                    Circle()
                        .fill(ThemeColor.foreground.opacity(0.5))
                        .frame(width: 50)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(ThemeColor.background)
                        }
                }
            }
            .padding()
        }
    }
}

struct PhotoReviewPreview: PreviewProvider {
    static var previews: some View {
        return PhotoReview(photos: [.init(data: nil)], presenting: .constant(true))
    }
}

