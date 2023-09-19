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
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
}

@MainActor struct CameraView: View {
    @StateObject var model = CameraViewModel()
    @EnvironmentObject var orientation: OrientationListener
    @EnvironmentObject var locationManager: LocationManager
    
    var bottomButtonSize: CGFloat {
        return 45
    }
    
    var captureButton: some View {
        Button(action: {
            model.capturePhoto()
        }, label: {
            Circle()
                .foregroundColor(model.isCapturing ? .gray : .white)
                .frame(width: bottomButtonSize + 20, height: bottomButtonSize + 20, alignment: .center)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: bottomButtonSize, height: bottomButtonSize, alignment: .center)
                )
        })
    }
    
    var capturedPhotoThumbnail: some View {
        Image(uiImage: model.photo?.image ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: bottomButtonSize, height: bottomButtonSize)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .rotateWithVideoOrientation(videoOrientation: orientation.videoOrientation)
    }
    
    var flipCameraButton: some View {
        Button(action: {
            model.flipCamera()
        }, label: {
            Circle()
                .foregroundColor(Color.gray.opacity(0.2))
                .frame(width: bottomButtonSize, height: bottomButtonSize, alignment: .center)
                .overlay(
                    Image(systemName: "camera.rotate.fill")
                        .foregroundColor(.white))
        })
    }
    
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
                        .rotateWithVideoOrientation(videoOrientation: orientation.videoOrientation)
                        
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
                                Text("RAW & JPEG")
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(5)
                        .border(.white, width: 1)
                        .rotateWithVideoOrientation(videoOrientation: orientation.videoOrientation)
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
                    }
                    
                    HStack {
                        capturedPhotoThumbnail
                        Spacer()
                        captureButton
                        Spacer()
                        flipCameraButton
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            orientation.startListen()
        }
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
