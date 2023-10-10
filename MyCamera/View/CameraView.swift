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
    @StateObject var viewModel = CameraViewModel()
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    HStack(spacing: 20) {
                        Button {
                            viewModel.switchFlash()
                        } label: {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20, weight: .medium, design: .default))
                        }
                        .accentColor(viewModel.isFlashOn ? .yellow : .white)
                        .rotateWithVideoOrientation(videoOrientation: viewModel.orientationListener.videoOrientation)
                        Spacer()
                        
                        Button {
                            switch viewModel.rawOption {
                            case .jpegOnly:
                                viewModel.rawOption = .rawOnly
                            case .rawOnly:
                                viewModel.rawOption = .rawAndJpeg
                            case .rawAndJpeg:
                                viewModel.rawOption = .jpegOnly
                            }
                        } label: {
                            switch viewModel.rawOption {
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
                        .rotateWithVideoOrientation(videoOrientation: viewModel.orientationListener.videoOrientation)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
//                    Spacer()
                    
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
                    }
                    .onTapGesture {
                        viewModel.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
                    }
                    .aspectRatio(3 / 4, contentMode: .fit)
                    
//                    Spacer()
                    
                    ZStack {
                        PhotosPicker(selection: .constant([]), maxSelectionCount: 0, selectionBehavior: .default, matching: nil, preferredItemEncoding: .automatic) {
                            if let img = viewModel.photo?.image {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .rotateWithVideoOrientation(videoOrientation: viewModel.orientationListener.videoOrientation)
                            } else {
                                Rectangle()
                                    .fill(.gray)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .frame(width: 74, height: 74)
                            }
                        }
                        .offset(x: -120)
                        
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
                        
                        ZStack {
                            EVSliderView(value: $viewModel.exposureBias)
                        }
                        .frame(width: 100, height: 100)
                        .rotateWithVideoOrientation(videoOrientation: viewModel.orientationListener.videoOrientation)
                        .offset(x: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.orientationListener.startListen()
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
