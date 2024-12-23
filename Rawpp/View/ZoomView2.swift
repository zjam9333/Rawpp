//
//  ZoomView2.swift
//  ImageZoomTest
//
//  Created by zjj on 2023/11/30.
//

import SwiftUI

struct ZoomView<Content: View>: UIViewRepresentable {
    let presenting: Bool
    let contentAspectRatio: CGFloat
    @ViewBuilder let content: () -> Content
    let shouldDragDismiss: (CGFloat) -> Void
    
    init(presenting: Bool = true, contentAspectRatio: CGFloat = 1, content: @escaping () -> Content, shouldDragDismiss: @escaping (CGFloat) -> Void) {
        self.contentAspectRatio = contentAspectRatio
        self.content = content
        self.presenting = presenting
        self.shouldDragDismiss = shouldDragDismiss
    }
    
    typealias UIViewType = UIScrollView
    typealias Coordinator = ScrollViewPresentCoordinator<Content>
    
    func makeUIView(context: Context) -> UIViewType {
        let coordinator = context.coordinator
        let scroll = coordinator.scrollView
        return scroll
    }
    
    func makeCoordinator() -> Coordinator {
        let c = ScrollViewPresentCoordinator(contentAspectRatio: contentAspectRatio, content: content())
        c.shouldDragDismiss = shouldDragDismiss
        return c
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        print("updateUIView(_ uiView: UIViewType, context: Context)")
        if presenting == false {
            uiView.setZoomScale(1, animated: true)
        }
        context.coordinator.contentAspectRatio = contentAspectRatio
    }
}

fileprivate class ZoomViewScrollView: UIScrollView {
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            let f = newValue
            let old = super.frame
            super.frame = f
            if old.size != f.size {
                frameDidChangedHandler()
            }
        }
    }
    
    var frameDidChangedHandler: () -> Void = {}
}

class ScrollViewPresentCoordinator<Content: View>: UIHostingController<Content>, UIScrollViewDelegate {
    var contentAspectRatio: CGFloat
    
    var shouldDragDismiss: (CGFloat) -> Void = { _ in }
    
    init(contentAspectRatio: CGFloat, content: Content) {
        self.contentAspectRatio = contentAspectRatio
        super.init(rootView: content)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var scrollView: UIScrollView {
        return myScrollView
    }
    private lazy var myScrollView: UIScrollView = {
        let m = ZoomViewScrollView()
        m.alwaysBounceVertical = true
        m.frameDidChangedHandler = { [weak self] in
            self?.updateChildViewFrameIfNeed()
        }
        return m
    }()
    
    var childView: UIView {
        return view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.addSubview(childView)
        scrollView.delegate = self
        scrollView.zoomScale = 1
        scrollView.maximumZoomScale = 3
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapGesture))
        tapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(tapGesture)
    }
    
    @objc func doubleTapGesture(_ tap: UITapGestureRecognizer) {
        print("doubleTapGesture", tap)
        if (scrollView.zoomScale > 1) {
            scrollView.setZoomScale(1, animated: true)
        } else if let imageV = self.viewForZooming(in: scrollView) {
            let center = tap.location(in: tap.view)
            var zoomRect = CGRect.zero
            zoomRect.origin = imageV.convert(center, from: scrollView)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    func updateChildViewFrameIfNeed() {
        let scrollFrame = scrollView.frame
        let size = scrollFrame.size
        scrollView.contentSize = size
        scrollView.zoomScale = 1
        let rate = size.width / size.height
        let scaledSize: CGSize
        if rate > contentAspectRatio {
            let h = size.height
            let w = h * contentAspectRatio
            scaledSize = CGSize(width: w, height: h)
        } else {
            let w = size.width
            let h = w / contentAspectRatio
            scaledSize = CGSize(width: w, height: h)
        }
        childView.frame.size = scaledSize
        childView.frame.origin = .init(x: (size.width - scaledSize.width) / 2, y: (size.height - scaledSize.height) / 2)
    }
    
    // MARK: UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return childView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let frame = childView.frame
        let bounds = scrollView.bounds
        if frame.width >= bounds.width {
            if frame.minX > 0 {
                childView.frame.origin.x = 0
            }
        } else {
            childView.frame.origin.x = (bounds.width - frame.width) / 2
        }
        if frame.height >= bounds.height {
            if frame.minY > 0 {
                childView.frame.origin.y = 0
            }
        } else {
            childView.frame.origin.y = (bounds.height - frame.height) / 2
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isZooming == false else {
            return
        }
        print(scrollView.contentOffset)
        shouldDragDismiss(scrollView.contentOffset.y)
    }
}
