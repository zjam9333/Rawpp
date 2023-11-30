//
//  ZoomView2.swift
//  ImageZoomTest
//
//  Created by zjj on 2023/11/30.
//

import SwiftUI

private let log = false

/// 覆盖print
private func print(_ items: Any..., separator: String = " ") {
    guard log else {
        return
    }
    let str = items.map { any in
        return String(describing: any)
    }.joined(separator: separator)
    Swift.print(str)
}

struct ZoomView<Content: View>: UIViewRepresentable {
    let presenting: Bool
    let contentAspectRatio: CGFloat
    @ViewBuilder let content: () -> Content
    
    init(presenting: Bool = true, contentAspectRatio: CGFloat = 1, content: @escaping () -> Content) {
        self.contentAspectRatio = contentAspectRatio
        self.content = content
        self.presenting = presenting
    }
    
    typealias UIViewType = UIScrollView
    typealias Coordinator = ScrollViewPresentCoordinator
    
    func makeUIView(context: Context) -> UIViewType {
        let scroll = UIScrollView()
        let child = context.coordinator.childView
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.addSubview(child)
        scroll.delegate = context.coordinator
        scroll.zoomScale = 1
        scroll.maximumZoomScale = 3
        return scroll
    }
    
    func makeCoordinator() -> ScrollViewPresentCoordinator {
        let c = ScrollViewPresentCoordinator(host: UIHostingController(rootView: content()))
        return c
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        print("updateUIView(_ uiView: UIViewType, context: Context)")
        if presenting == false {
            uiView.setZoomScale(1, animated: true)
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else {
            return nil
        }
        let size = CGSize(width: width, height: height)
        uiView.contentSize = size
        context.coordinator.updateSize(size: size, aspectRatio: contentAspectRatio)
        return size
    }
}

class ScrollViewPresentCoordinator: NSObject, UIScrollViewDelegate {
    private let host: UIViewController
    init(host: UIViewController) {
        self.host = host
    }
    
    var childView: UIView {
        return host.view
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return childView
    }
    
    func updateSize(size: CGSize, aspectRatio: CGFloat) {
        let rate = size.width / size.height
        let scaledSize: CGSize
        if rate > aspectRatio {
            let h = size.height
            let w = h * aspectRatio
            scaledSize = CGSize(width: w, height: h)
        } else {
            let w = size.width
            let h = w / aspectRatio
            scaledSize = CGSize(width: w, height: h)
        }
        childView.frame.size = scaledSize
        childView.frame.origin = .init(x: (size.width - scaledSize.width) / 2, y: (size.height - scaledSize.height) / 2)
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        print("scrollViewDidZoom(_ scrollView: UIScrollView)")
        let frame = childView.frame
        print("childView.frame", frame)
        let bounds = scrollView.bounds
        print("scrollView.bounds", bounds)
        if frame.width >= bounds.width {
            if frame.minX > 0 {
                childView.frame.origin.x = 0
            }
        } else {
            print("reset center x")
            childView.frame.origin.x = (bounds.width - frame.width) / 2
        }
        if frame.height >= bounds.height {
            if frame.minY > 0 {
                childView.frame.origin.y = 0
            }
        } else {
            print("reset center y")
            childView.frame.origin.y = (bounds.height - frame.height) / 2
        }
    }
}

