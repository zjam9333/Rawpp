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
        let evs = EVValue.presetEVs
    }
    let evOffsetCache = EVOffsetCache()
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    ZStack {
                        HStack(spacing: 20) {
                            Button {
                                viewModel.switchFlash()
                            } label: {
                                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 20, weight: .medium, design: .default))
                            }
                            .accentColor(viewModel.isFlashOn ? .yellow : .white)
                            .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                            Spacer()
                            
                            Button {
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        
                        EVSliderView(value: $viewModel.exposureBias, evs: EVValue.presetEVs)
                            .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
                    }
                    
                    ZStack {
                        CameraVideoLayerPreview(session: viewModel.session)
                            .onAppear {
                                viewModel.configure()
                            }
                            .alert(isPresented: $viewModel.showAlertError) {
                                Alert(title: Text(viewModel.alertError.title), message: Text(viewModel.alertError.message), primaryButton: .default(Text(viewModel.alertError.primaryButtonTitle), action: {
                                    viewModel.alertError.primaryAction?()
                                }), secondaryButton: .cancel())
                            }
//                            .scaleEffect(x: 0.2, y: 0.2)
                        if viewModel.isCapturing {
                            Color(.black).opacity(0.5)
                        }
                        
                        Group {
                            Color.white.frame(width: 1, height: 20)
                            Color.white.frame(width: 20, height: 1)
                        }
                        
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
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay(alignment: .bottomTrailing) {
                        Text("cameraLens: \(viewModel.cameraLens.rawValue) \(viewModel.cameraPosition.rawValue)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                    }
                    
                    ZStack {
                        HStack {
                            if let data = viewModel.photo?.data, let img = UIImage(data: data) {
                                Button {
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
                            
                            Button {
                                viewModel.toggleFrontCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .resizable()
                                    .foregroundColor(.white)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40, alignment: .center)
                            }
                        }
                        
                        Button {
                            viewModel.capturePhoto()
                        } label: {
                            let buttonSiz: CGFloat = 74
                            let circleSiz = buttonSiz - 36
                            Circle()
                                .foregroundColor(viewModel.isCapturing ? .gray : .white)
                                .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1)
                                        .frame(width: circleSiz, height: circleSiz, alignment: .center)
                                )
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
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
    }
    
    private func increaseEV(step: Int) {
        let evs = evOffsetCache.evs
        guard let index = evs.firstIndex(of: viewModel.exposureBias) else {
            viewModel.exposureBias = .zero
            return
        }
        let next = index + step
        print("ev index found", index, "next", next, "total", evs.count)
        if evs.indices.contains(next) {
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
