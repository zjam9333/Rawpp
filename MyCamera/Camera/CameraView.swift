//
//  File.swift
//  MyCamera
//
//  Created by zjj on 2021/9/15.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI
import PhotosUI

@MainActor struct CameraView: View {
    @StateObject var model = CameraViewModel()
    @EnvironmentObject var orientationListener: OrientationListener
    @EnvironmentObject var locationManager: LocationManager
    
    @State var pickerSelectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer().frame(height: 20)
//                    Text("\(orientation.videoOrientation)" + "")
                    HStack(spacing: 10) {
                        Button {
                            model.switchFlash()
                        } label: {
                            Image(systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20, weight: .medium, design: .default))
                        }
                        .accentColor(model.isFlashOn ? .yellow : .white)
                        .rotateWithVideoOrientation(videoOrientation: orientationListener.videoOrientation)
                        
                        Button {
                            switch model.rawOption {
                            case .jpegOnly:
                                model.rawOption = .rawOnly
                            case .rawOnly:
                                model.rawOption = .rawAndJpeg
                            case .rawAndJpeg:
                                model.rawOption = .jpegOnly
                            }
                        } label: {
                            switch model.rawOption {
                            case .jpegOnly:
                                Text("JPEG")
                            case .rawOnly:
                                Text("RAW")
                            case .rawAndJpeg:
                                Text("RAW+J")
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(5)
                        .border(.white, width: 1)
                        .rotateWithVideoOrientation(videoOrientation: orientationListener.videoOrientation)
                    }
                    .padding(.horizontal, 20)
                    
                    ZStack {
                        CameraPreview(session: model.session)
                            .onAppear {
                                model.configure()
                            }
                            .alert(isPresented: $model.showAlertError) {
                                Alert(title: Text(model.alertError.title), message: Text(model.alertError.message), primaryButton: .default(Text(model.alertError.primaryButtonTitle), action: {
                                    model.alertError.primaryAction?()
                                }), secondaryButton: .cancel())
                            }
//                            .scaleEffect(x: 0.2, y: 0.2)
                        if model.isCapturing {
                            Color(.black).opacity(0.5)
                        }
                        
                        Group {
                            Color.white.frame(width: 1, height: 20)
                            Color.white.frame(width: 20, height: 1)
                        }
                        
//                        TouchView { point, size in
//                            calculateFocusPoint(point, in: size)
//                        }
                    }
                    .padding(.vertical, 10)
                    .onTapGesture {
                        model.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
                    }
                    
                    HStack {
                        Button {
//                            model.flipCamera()
                        } label: {
                            if let img = model.photo?.image  {
                                PhotosPicker(selection: $pickerSelectedItems, maxSelectionCount: 0, selectionBehavior: .default, matching: nil, preferredItemEncoding: .automatic) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 45, height: 45)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        .rotateWithVideoOrientation(videoOrientation: orientationListener.videoOrientation)
                                }
                            } else {
                                Rectangle().fill(.clear).frame(width: 45, height: 45)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            model.capturePhoto()
                        }, label: {
                            let buttonSiz: CGFloat = 74
                            Circle()
                                .foregroundColor(model.isCapturing ? .gray : .white)
                                .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1)
                                        .frame(width: buttonSiz - 20, height: buttonSiz - 20, alignment: .center)
                                )
                        })
                        
                        Spacer()
                        
                        ZStack {
                            Text("EV").font(.system(size: 12))
                                .offset(x: -24)
                            Picker(selection: $model.exposureBias) {
                                let evs: [Float] = [-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2].reversed()
                                ForEach(evs, id: \.self) { ev in
                                    Text(String(format: "%.1f", ev)).font(.system(size: 12))
                                }
                            } label: {
                                Text("EV")
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 100)
                        }
                        .frame(width: 45, height: 100)
                        .rotateWithVideoOrientation(videoOrientation: orientationListener.videoOrientation)
                        .offset(x: -20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            orientationListener.startListen()
        }
    }
    
    func calculateFocusPoint(_ point: CGPoint, in size: CGSize) {
        // TODO: 根据手机方向翻转point
//        var point = point
//        var size = size
//        let videoOrientation = orientation.videoOrientation
//        switch videoOrientation {
//        case .portraitUpsideDown:
//            point = .init(x: size.width - point.x, y: size.height - point.y)
//        case .landscapeRight:
//            point = .init(x: point.y, y: size.width - point.x)
//            size = .init(width: size.height, height: size.width)
//        case .landscapeLeft:
//            point = .init(x: size.height - point.y, y: point.x)
//            size = .init(width: size.height, height: size.width)
//        default:
//            break
//        }
//        let interest = CGPoint(x: point.x / size.width, y: point.y / size.height)
//        print("PointOfInterest Rotated", interest)
//        model.focus(pointOfInterest: interest)
        model.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
    }
}

extension View {
    @ViewBuilder func rotateWithVideoOrientation(videoOrientation: AVCaptureVideoOrientation) -> some View {
        var degree: Angle {
            switch videoOrientation {
            case .portraitUpsideDown:
                return .degrees(180)
            case .landscapeLeft:
                return .degrees(-90)
            case .landscapeRight:
                return .degrees(90)
            default:
                return .zero
            }
        }
        rotationEffect(degree).animation(.default, value: videoOrientation)
    }
}

struct CameraPreview: UIViewRepresentable {
    // 1.
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        view.contentMode = .scaleAspectFill
#if targetEnvironment(simulator)
        view.layer.borderColor = UIColor.gray.cgColor
        view.layer.borderWidth = 1
#endif
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
}

struct TouchView: UIViewRepresentable {
    typealias TouchHandler = (CGPoint, CGSize) -> Void
    
    class MyView: UIView {
        let touchHander: TouchHandler
        
        init(touchHander: @escaping TouchHandler) {
            self.touchHander = touchHander
            super.init(frame: .zero)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizer(sender:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func tapGestureRecognizer(sender: UITapGestureRecognizer) {
            let p = sender.location(in: self)
            guard bounds.contains(p) else {
                return
            }
            touchHander(p, bounds.size)
        }
    }
    
    let touchHandler: TouchHandler
    
    func makeUIView(context: Context) -> MyView {
        let view = MyView(touchHander: touchHandler)
        return view
    }
    
    func updateUIView(_ uiView: MyView, context: Context) {
        
    }
}
