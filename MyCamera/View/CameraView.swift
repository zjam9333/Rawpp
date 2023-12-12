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
        .fullScreenCover(isPresented: $viewModel.showPhoto) {
            PhotoReview(photos: viewModel.photos, presenting: $viewModel.showPhoto)
        }
        .sheet(isPresented: $viewModel.showSetting) {
            let raw = viewModel.photos.first  { p in
                return p.raw != nil
            }?.raw
            SettingView(rawImage: raw, presenting: $viewModel.showSetting)
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
                viewModel.touchFeedback()
                viewModel.shutterTimer.toggleNext()
            } label: {
                let t = Int(viewModel.shutterTimer.rawValue)
                HStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.system(size: 20))
                        .accentColor(t > 0 ? .yellow : .white)
                    if t > 0 {
                        Text("\(t)")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Button {
                viewModel.touchFeedback()
                switch viewModel.exposureMode {
                case .auto:
                    viewModel.exposureMode = .manual
                case .manual:
                    viewModel.exposureMode = .auto
                }
            } label: {
                Group {
                    switch viewModel.exposureMode {
                    case .auto:
                        Text("AE")
                    case .manual:
                        Text("MANUAL")
                            .foregroundColor(.red)
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(5)
                .frame(height: 24)
                .border(.white, width: 1)
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
                    .border(.gray, width: 1)
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
                        Text(String(format: "iso %.0f ss %@", viewModel.ISO.floatValue, viewModel.shutterSpeed.description))
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .opacity(viewModel.showingEVIndicators ? 1 : 0)
                    }
                }
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                .animation(viewModel.showingEVIndicators ? .default : .default.delay(1), value: viewModel.showingEVIndicators)
                
                gestureContainer(size: geo.size)
                
                if let timer = viewModel.timerSeconds {
                    let seconds = Int(timer.value) + 1
                    Circle()
                        .foregroundColor(.black.opacity(0.5))
                        .frame(width: 100, height: 100, alignment: .center)
                        .overlay(alignment: .center) {
                            Text("\(seconds)")
                                .foregroundColor(.white)
                                .font(.system(size: 72))
                        }
                }
            }
        }
        .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width * 4 / 3)
    }
    
    @ViewBuilder private var bottomActions: some View {
        HStack {
            if let data = viewModel.photos.first?.data, let img = UIImage(data: data) {
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
            .clipShape(Rectangle())
            .onTapGesture {
                viewModel.showSetting = true
            }
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
    
    @ViewBuilder func strokeText(text: String, radius: CGFloat, borderColor: Color) -> some View {
        ZStack{
            ZStack{
                Text(text).offset(x:  radius, y:  radius)
                Text(text).offset(x: -radius, y: -radius)
            }
            .foregroundColor(borderColor)
            Text(text)
        }
    }
    
    @ViewBuilder func gestureContainer(size: CGSize) -> some View {
        
        Group {
            switch viewModel.exposureMode {
            case .auto:
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        stepDragGesture(onDraging: { b in
                            viewModel.showingEVIndicators = b
                        }, onStepToogled: { step in
                            viewModel.touchFeedback()
                            viewModel.increaseEV(step: step)
                        }, offsetSetter: { value in
                            viewModel.lastEVDragOffset = value
                        }, offsetGetter: {
                            return viewModel.lastEVDragOffset
                        })
                    )
            case .manual:
                HStack {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            stepDragGesture(onDraging: { b in
                                viewModel.showingEVIndicators = b
                            }, onStepToogled: { step in
                                viewModel.touchFeedback()
                                viewModel.increaseISO(step: step)
                            }, offsetSetter: { value in
                                viewModel.lastEVDragOffset = value
                            }, offsetGetter: {
                                return viewModel.lastEVDragOffset
                            })
                        )
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            stepDragGesture(onDraging: { b in
                                viewModel.showingEVIndicators = b
                            }, onStepToogled: { step in
                                viewModel.touchFeedback()
                                viewModel.increaseShutterSpeed(step: step)
                            }, offsetSetter: { value in
                                viewModel.lastEVDragOffset = value
                            }, offsetGetter: {
                                return viewModel.lastEVDragOffset
                            })
                        )
                }
            }
        }
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
            MagnificationGesture()
                .onEnded { amount in
                    viewModel.changeCamera(step: amount > 1 ? 1 : -1)
                }
        )
        .frame(width: viewModel.videoOrientation.isLandscape ? size.height : size.width, height: viewModel.videoOrientation.isLandscape ? size.width : size.height)
        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
        .frame(width: size.width, height: size.height)
    }
    
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
    
    func stepDragGesture(onDraging: @escaping (Bool) -> Void, onStepToogled: @escaping (Int) -> Void, offsetSetter: @escaping (CGFloat) -> Void, offsetGetter: @escaping () -> CGFloat) -> some Gesture {
        return DragGesture()
            .onChanged { value in
                onDraging(true)
                let currentOffSet = -(value.location.y - value.startLocation.y)
                let thres: CGFloat = 12
                let lastOffset = offsetGetter()
                if (currentOffSet - lastOffset > thres) {
                    offsetSetter(lastOffset + thres)
                    onStepToogled(1)
                } else if (currentOffSet - lastOffset <= -thres) {
                    offsetSetter(lastOffset - thres)
                    onStepToogled(-1)
                }
            }
            .onEnded{ v in
                offsetSetter(0)
                onDraging(false)
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
