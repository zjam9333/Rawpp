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
                    
//                    Text("\(orientation.videoOrientation)" + "")
                    HStack(spacing: 20) {
                        Button {
                            model.switchFlash()
                        } label: {
                            Image(systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20, weight: .medium, design: .default))
                        }
                        .accentColor(model.isFlashOn ? .yellow : .white)
                        .rotateWithVideoOrientation(videoOrientation: orientationListener.videoOrientation)
                        Spacer()
                        
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
                    .padding(.vertical, 10)
                    
//                    Spacer()
                    
                    ZStack {
                        CameraVideoLayerPreview(session: model.session)
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
                    }
                    .onTapGesture {
                        model.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
                    }
                    .aspectRatio(3 / 4, contentMode: .fit)
                    
//                    Spacer()
                    
                    ZStack {
                        Group {
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
                                Rectangle()
                                    .fill(.gray)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .frame(width: 45, height: 45)
                            }
                        }.offset(x: -120)
                        
                        Button {
                            model.capturePhoto()
                        } label: {
                            let buttonSiz: CGFloat = 74
                            let circleSiz = buttonSiz - 36
                            Circle()
                                .foregroundColor(model.isCapturing ? .gray : .white)
                                .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1)
                                        .frame(width: circleSiz, height: circleSiz, alignment: .center)
                                )
                        }
                        
                        ZStack {
                            EVSliderView(value: .init(get: {
                                return model.exposureBias
                            }, set: { v in
                                model.exposureBias = v
                            }))
                        }
                        .frame(width: 100, height: 100)
                        .rotateWithVideoOrientation(videoOrientation: orientationListener.videoOrientation)
                        .offset(x: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            orientationListener.startListen()
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
            .environmentObject(OrientationListener.shared)
            .environmentObject(LocationManager.shared)
    }
}
