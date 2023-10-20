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

struct CameraView: View {
    @StateObject var viewModel = CameraViewModel()
    
    var body: some View {
        
        VStack {
            topActions
            centerPreview
            bottomActions
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showPhoto) {
            if let data = viewModel.photo?.data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(viewModel.isAppInBackground ? 0 : 1)
                    .animation(.default, value: viewModel.isAppInBackground)
            } else {
                EmptyView()
            }
        }
        .onAppear {
            viewModel.configure()
        }
        .alert(isPresented: $viewModel.showAlertError) {
            Alert(title: Text(viewModel.alertError.title), message: Text(viewModel.alertError.message), primaryButton: .default(Text(viewModel.alertError.primaryButtonTitle), action: {
                viewModel.alertError.primaryAction?()
            }), secondaryButton: .cancel())
        }
    }
    
    @ViewBuilder private var topActions: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.touchFeedback()
                viewModel.switchFlash()
            } label: {
                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 20))
            }
            .accentColor(viewModel.isFlashOn ? .yellow : .white)
            .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            
            Button {
                viewModel.touchFeedback()
                viewModel.toggleFrontCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20))
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            .accentColor(.white)
            
            Spacer()
            
            Button {
                switch viewModel.exposureMode {
                case .auto:
                    viewModel.exposureMode = .manual
                case .manual:
                    viewModel.exposureMode = .auto
                }
            } label: {
                ZStack {
                    switch viewModel.exposureMode {
                    case .auto:
                        Text("AE")
                    case .manual:
                        Text("MANUAL")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(5)
                .frame(height: 24)
                .border(.white, width: 1)
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            
            Button {
                viewModel.touchFeedback()
                switch viewModel.rawOption {
                case .heif:
                    viewModel.rawOption = .raw
                case .raw:
                    viewModel.rawOption = .rawAndHeif
                case .rawAndHeif:
                    viewModel.rawOption = .heif
                }
            } label: {
                ZStack {
                    switch viewModel.rawOption {
                    case .heif:
                        Text("HEIF")
                    case .raw:
                        Text("RAW")
                    case .rawAndHeif:
                        Text("RAW+H")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(5)
                .frame(height: 24)
                .border(.white, width: 1)
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder private var centerPreview: some View {
        
        GeometryReader { geo in
            ZStack {
                CameraVideoLayerPreview(session: viewModel.session)
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .clipped()
                    .opacity(viewModel.isAppInBackground ? 0 : 1)
                    .animation(.default, value: viewModel.isAppInBackground)
                    .overlay {
                        if viewModel.isCapturing {
                            Color(.black).opacity(0.5)
                        }
                    }
            
                Group {
                    Group {
                        Color.white.frame(width: 1, height: 20)
                        Color.white.frame(width: 10, height: 1)
                    }
                    .opacity(!viewModel.showingEVIndicators ? 1 : 0)
                    
                    switch viewModel.exposureMode {
                    case .auto:
                        VStack {
                            exposureValueIndicator
                            Text(String(format: "EV %.1f", viewModel.exposureValue.floatValue))
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(alignment: .leading)
                        }
                        .opacity(viewModel.showingEVIndicators ? 1 : 0)
                    case .manual:
                        Text(String(format: "ISO %.0f SS %@", viewModel.ISO.floatValue, viewModel.shutterSpeed.description)).font(.system(size: 12))
                            .foregroundColor(.white)
                            .opacity(viewModel.showingEVIndicators ? 1 : 0)
                    }
                }
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                .animation(viewModel.showingEVIndicators ? .default : .default.delay(1), value: viewModel.showingEVIndicators)
                
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
//                    .border(.red)
                    .onTapGesture(count: 2) {
                        viewModel.exposureValue = .zero
                        viewModel.shutterSpeed = .percent100
                        viewModel.ISO = .iso100
                    }
                    .onTapGesture {
                        viewModel.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                //                                print(value)
                                //                                return
                                func dragToggled(step: Int, left: Bool) {
                                    viewModel.touchFeedback()
                                    switch viewModel.exposureMode {
                                    case .auto:
                                        viewModel.increaseEV(step: step)
                                    case .manual:
                                        if left {
                                            viewModel.increaseISO(step: step)
                                        } else {
                                            viewModel.increaseShutterSpeed(step: step)
                                        }
                                    }
                                }
                                
                                viewModel.showingEVIndicators = true
                                let currentOffSet = -(value.location.y - value.startLocation.y)
                                let isLeft = value.startLocation.x < (geo.size.width / 2)
                                let thres: CGFloat = 12
                                if (currentOffSet - viewModel.lastEVDragOffset > thres) {
                                    viewModel.lastEVDragOffset += thres
                                    dragToggled(step: 1, left: isLeft)
                                } else if (currentOffSet - viewModel.lastEVDragOffset <= -thres) {
                                    viewModel.lastEVDragOffset -= thres
                                    dragToggled(step: -1, left: isLeft)
                                }
                            }
                            .onEnded{ v in
                                viewModel.lastEVDragOffset = 0
                                viewModel.showingEVIndicators = false
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onEnded { amount in
                                viewModel.changeCamera(step: amount > 1 ? 1 : -1)
                            }
                    )
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width * 4 / 3)
    }
    
    @ViewBuilder private var bottomActions: some View {
        HStack {
            if let data = viewModel.photo?.data, let img = UIImage(data: data) {
                Button {
                    viewModel.touchFeedback()
                    viewModel.showPhoto = true
                } label: {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 74, height: 74)
                        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                }
                .opacity(viewModel.isAppInBackground ? 0 : 1)
                .animation(.default, value: viewModel.isAppInBackground)
            }
            
            Spacer()
        }
        .frame(height: 100)
        .padding(.horizontal, 20)
        .overlay(alignment: .center) {
            Button {
                viewModel.touchFeedback()
                viewModel.capturePhoto()
            } label: {
                let buttonSiz: CGFloat = 74
                let circleSiz = buttonSiz - 36
                Circle()
                    .foregroundColor(viewModel.isCapturing ? .gray : .white)
                    .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                    .overlay(alignment: .center) {
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                            .frame(width: circleSiz, height: circleSiz, alignment: .center)
                    }
            }
        }
        .overlay(alignment: .trailing) {
            let cameraLens: String = {
                switch (viewModel.cameraLens) {
                case .builtInWideAngleCamera:
                    return "WideAngle"
                case .builtInUltraWideCamera:
                    return "UltraWide"
                case .builtInTelephotoCamera:
                    return "Telephoto"
                default:
                    return viewModel.cameraLens.rawValue
                }
            }()
            let cameraPosition: String = {
                switch (viewModel.cameraPosition) {
                case .back:
                    return "Back"
                case .front:
                    return "Front"
                default:
                    return "Unknown"
                }
            }()
            VStack(alignment: .trailing, spacing: 8) {
                switch viewModel.exposureMode {
                case .auto:
                    Text(String(format: "EV %.1f", viewModel.exposureValue.floatValue)).font(.system(size: 12))
                        .foregroundColor(.white)
                case .manual:
                    Text(String(format: "ISO %.0f", viewModel.ISO.floatValue)).font(.system(size: 12))
                        .foregroundColor(.white)
                    Text("SS \(viewModel.shutterSpeed.description)").font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                Text("\(cameraPosition) \(cameraLens)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            .padding(10)
        }
    }
    
    @ViewBuilder var exposureValueIndicator: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(ExposureValue.presetExposureValues, id: \.self) { ev in
                let isSelected = viewModel.exposureValue == ev
                let isInteger = ExposureValue.integerValues.contains(ev)
                Color.clear
                    .frame(width: isSelected ? 2 : 1, height: 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(isSelected ? Color.red : Color.white)
                            .frame(height: isInteger ? 12 : 8)
                    }
                    .overlay(alignment: .top) {
                        if isSelected {
                            Image(systemName: "triangle.fill")
                                .resizable()
                                .rotationEffect(.degrees(180))
                                .accentColor(Color.red)
                                .frame(width: 4, height: 4)
                                .offset(y: -8)
                        }
                    }
                //                                .animation(.default, value: viewModel.exposureValue)
            }
        }
    }
    
}

struct CameraVideoLayerPreview: UIViewRepresentable {
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

struct CameraViewPreview: PreviewProvider {
    static var previews: some View {
        return CameraView()
            .border(.white, width: 1)
    }
}

extension View {
    func rotateWithVideoOrientation(videoOrientation: AVCaptureVideoOrientation) -> some View {
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
        return rotationEffect(degree).animation(.default, value: videoOrientation)
    }
}
