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
            SettingView(presenting: $viewModel.showSetting)
        }
        .onAppear {
            viewModel.configure()
        }
        .overlay {
            if let err = viewModel.alertError {
                Color.black.opacity(0.3)
                VStack(alignment: .center) {
                    Text(err.title)
                        .font(.title3)
                        .padding(.bottom, 10)
                        .padding(.top, 10)
                    Text(err.message)
                        .font(.body)
                        .padding(.bottom, 10)
                    Divider()
                    HStack {
                        Button {
                            err.primaryAction?()
                        } label: {
                            Text(err.primaryButtonTitle)
                                .font(.body)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        
                        if let secondaryButtonTitle = err.secondaryButtonTitle {
                            Button {
                                err.secondaryAction?()
                            } label: {
                                Text(secondaryButtonTitle)
                                    .font(.body)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                }
                .foregroundStyle(.black)
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(width: 280)
            }
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
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Spacer()
            
            rawOptionView
            
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
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(5)
                .frame(height: 24)
                .border(.white, width: 1)
            }
            
        }
        .frame(height: 64)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder private var rawOptionView: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.touchFeedback()
                if viewModel.rawOption.contains(.apple) {
                    viewModel.rawOption.remove(.apple)
                } else {
                    viewModel.rawOption.insert(.apple)
                }
            } label: {
                Text("APPLE")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .strikethrough(viewModel.rawOption.contains(.apple) == false, color: .yellow)
                    .padding(.vertical, 5)
                    .frame(height: 24)
            }
            if viewModel.rawOption.contains(.apple) == false {
                Button {
                    viewModel.touchFeedback()
                    viewModel.rawOption = viewModel.rawOption.next
                } label: {
                    Text(viewModel.rawOption.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.vertical, 5)
                        .frame(height: 24)
                }
                .animation(nil, value: viewModel.rawOption)
            }
        }
        .padding(.horizontal, 5)
        .border(.white, width: 1)
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
                        if isXcodeDebugging {
                            Color.black.opacity(0.8)
                        }
                        if viewModel.isCapturing {
                            Color.black.opacity(0.5)
                        }
                    }
            
                Group {
                    Group {
                        Color.white.frame(width: 1, height: 20)
                        Color.white.frame(width: 10, height: 1)
                    }
                    .opacity(!viewModel.showingEVIndicators ? 1 : 0)
                    
                    VStack {
                        switch viewModel.exposureMode {
                        case .auto:
                            valuesIndicator(currentValue: viewModel.exposureValue, values: ExposureValue.presets) { va in
                                return ExposureValue.integers.contains(va)
                            }
                            Text(String(format: "EV %.1f", viewModel.exposureValue.floatValue))
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        case .manual:
                            HStack {
                                VStack {
                                    valuesIndicator(currentValue: viewModel.ISO, values: ISOValue.presets) { va in
                                        return ISOValue.integers.contains(va)
                                    }
                                    Text(String(format: "ISO %.0f", viewModel.ISO.floatValue))
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                }
                                
                                VStack {
                                    valuesIndicator(currentValue: viewModel.shutterSpeed, values: ShutterSpeed.presets) { va in
                                        return ShutterSpeed.integers.contains(va)
                                    }
                                    Text(String(format: "SS %@", viewModel.shutterSpeed.description))
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .opacity(viewModel.showingEVIndicators ? 1 : 0)
                }
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                .animation(viewModel.showingEVIndicators ? .default : .default.delay(1), value: viewModel.showingEVIndicators)
                
                gestureContainer(size: geo.size)
                
                if let timer = viewModel.timerSeconds {
                    let seconds = Int(timer.value) + 1
                    Circle()
                        .foregroundStyle(.black.opacity(0.5))
                        .frame(width: 100, height: 100, alignment: .center)
                        .overlay(alignment: .center) {
                            Text("\(seconds)")
                                .foregroundStyle(.white)
                                .font(.system(size: 72))
                        }
                } 
                if viewModel.allCameras.count > 1 {
                    Color.clear.overlay(alignment: .bottom) {
                        HStack(spacing: 4) {
                            ForEach(viewModel.allCameras) { i in
                                Button {
                                    viewModel.touchFeedback()
                                    i.selectionHandler()
                                } label: {
                                    Capsule(style: .circular)
                                        .fill(.gray.opacity(i.isSelected ? 1 : 0))
                                        .frame(width: 36, height: 30, alignment: .center)
                                        .overlay {
                                            Text(i.title)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.white)
                                        }
                                }
                            }
                        }
                        .padding(4)
                        .background(Capsule(style: .circular).fill(.gray.opacity(0.5)))
                        .padding()
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
                .overlay(alignment: .center) {
                    if viewModel.isProcessing {
                        LoadingView()
                    }
                }
            } else {
                Rectangle().fill(.black)
                    .frame(width: 74, height: 74)
                    .overlay(alignment: .center) {
                        if viewModel.isProcessing {
                            LoadingView()
                        }
                    }
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
                    .stroke(viewModel.isCapturing ? .gray : .white, lineWidth: 1)
                    .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                    .overlay(alignment: .center) {
                        Circle()
                            .stroke(Color.gray, lineWidth: 1)
                            .frame(width: circleSiz, height: circleSiz, alignment: .center)
                    }
            }
        }
        .overlay(alignment: .trailing) {
            
            VStack(alignment: .trailing, spacing: 8) {
                switch viewModel.exposureMode {
                case .auto:
                    Text(String(format: "EV %.1f", viewModel.exposureValue.floatValue))
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                case .manual:
                    Text(String(format: "ISO %.0f", viewModel.ISO.floatValue))
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    Text("SS \(viewModel.shutterSpeed.description)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                if let camera = viewModel.currentCamera {
                    let cameraPosition: String = {
                        switch (camera.device.position) {
                        case .back:
                            return "BACK"
                        case .front:
                            return "FRONT"
                        default:
                            return "UNKNOWN"
                        }
                    }()
                    Text("\(cameraPosition)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
            }
            .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            .padding(10)
            .clipShape(Rectangle())
            .onTapGesture {
                viewModel.showSetting = true
            }
        }
    }
    
    @ViewBuilder func valuesIndicator<Element>(currentValue: Element, values: [Element], isInteger: @escaping (Element) -> Bool) -> some View where Element: Hashable {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(values, id: \.self) { ev in
                let isSelected = currentValue == ev
                Color.clear
                    .frame(width: isSelected ? 2 : 1, height: 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(isSelected ? Color.red : Color.white)
                            .frame(height: isInteger(ev) ? 12 : 8)
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
            }
        }
    }
    
    @ViewBuilder func gestureContainer(size: CGSize) -> some View {
        
        Group {
            switch viewModel.exposureMode {
            case .auto:
                StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.exposureValue, items: ExposureValue.presets) {
                    viewModel.touchFeedback()
                }
            case .manual:
                HStack {
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.ISO, items: ISOValue.presets) {
                        viewModel.touchFeedback()
                    }
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.shutterSpeed, items: ShutterSpeed.presets) {
                        viewModel.touchFeedback()
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            @MainActor func resetExposure() async {
                viewModel.exposureValue = .zero
                viewModel.shutterSpeed = .percent100
                viewModel.ISO = .iso100
                viewModel.showingEVIndicators = true
                try? await Task.sleep(nanoseconds: 0_010_000_000)
                viewModel.showingEVIndicators = false
            }
            Task {
                await resetExposure()
            }
        }
        .onTapGesture {
            viewModel.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
        }
        .frame(width: viewModel.videoOrientation.isLandscape ? size.height : size.width, height: viewModel.videoOrientation.isLandscape ? size.width : size.height)
        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
        .frame(width: size.width, height: size.height)
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

struct LoadingView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let ac = UIActivityIndicatorView(style: .medium)
        ac.isUserInteractionEnabled = false
        ac.hidesWhenStopped = false
        ac.startAnimating()
        return ac
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        
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
