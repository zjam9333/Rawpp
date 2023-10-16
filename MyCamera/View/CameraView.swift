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

@MainActor struct CameraView: View {
    @StateObject var viewModel = CameraViewModel()
    
    class EVOffsetCache {
        var lastInitOffset: CGFloat = 0
    }
    private let evOffsetCache = EVOffsetCache()
    
    var body: some View {
        VStack {
            HStack(spacing: 20) {
                Button {
                    viewModel.touchFeedback()
                    viewModel.switchFlash()
                } label: {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 20, weight: .medium, design: .default))
                }
                .accentColor(viewModel.isFlashOn ? .yellow : .white)
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                
                Button {
                    viewModel.touchFeedback()
                    viewModel.toggleFrontCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .medium, design: .default))
                        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                }
                .accentColor(.white)
                
                Spacer()
                
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
                .border(.white, width: 1)
                .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            .frame(height: 64)
            .padding(.horizontal, 20)
            
            ZStack {
                CameraVideoLayerPreview(session: viewModel.session)
                    .clipped()
//                            .scaleEffect(x: 0.2, y: 0.2)
                
                if viewModel.isCapturing {
                    Color(.black).opacity(0.5)
                }
                
                Group {
                    Group {
                        Color.white.frame(width: 1, height: 20)
                        Color.white.frame(width: 20, height: 1)
                    }
                    .opacity(!viewModel.showingEVIndicators ? 1 : 0)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(EVValue.presetEVs, id: \.self) { ev in
                            let isSelected = viewModel.exposureBias == ev
                            let isInteger = EVValue.integerValues.contains(ev)
                            Rectangle()
                                .fill(isSelected ? Color.yellow : Color.white.opacity(0.8))
                                .frame(width: isSelected ? 2 : 1, height: isInteger ? 12 : 8)
                                .animation(.default, value: viewModel.exposureBias)
                        }
                    }
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                    .rotationEffect(.degrees(-90))
                    .opacity(viewModel.showingEVIndicators ? 1 : 0)
                }
                .animation(.default, value: viewModel.showingEVIndicators)
                
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        viewModel.exposureBias = .zero
                    }
                    .onTapGesture {
                        viewModel.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                viewModel.showingEVIndicators = true
                                let currentOffSet = -(value.location.y - value.startLocation.y)
                                let thres: CGFloat = 16
                                if (currentOffSet - evOffsetCache.lastInitOffset > thres) {
                                    evOffsetCache.lastInitOffset += thres
                                    increaseEV(step: 1)
                                } else if (currentOffSet - evOffsetCache.lastInitOffset <= -thres) {
                                    evOffsetCache.lastInitOffset -= thres
                                    increaseEV(step: -1)
                                }
                            }
                            .onEnded{ v in
                                evOffsetCache.lastInitOffset = 0
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
                
            }
            
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
                    Text(String(format: "EV %.1f", viewModel.exposureBias.rawValue)).font(.system(size: 12))
                        .foregroundColor(.white)
                        .fixedSize()
                        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                    Text("\(cameraPosition) \(cameraLens)")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .offset(x: -1, y: -1)
                        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                }
                .padding(10)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showPhoto) {
            if let data = viewModel.photo?.data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
    
    private func increaseEV(step: Int) {
        let evs = EVValue.presetEVs
        guard let index = evs.firstIndex(of: viewModel.exposureBias) else {
            viewModel.exposureBias = .zero
            return
        }
        let next = index + step
        print("ev index found", index, "next", next, "total", evs.count)
        if evs.indices.contains(next) {
            viewModel.touchFeedback()
            viewModel.exposureBias = evs[next]
        }
        print("value", viewModel.exposureBias)
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
