//
//  Camera.swift
//  MyCamera
//
//  Created by zjj on 2021/9/15.
//

import Foundation
import AVFoundation
import UIKit
import CoreLocation
import ImageIO

class CameraService {
    enum SessionSetupResult {
        case success
        case configurationFailed
        case notAuthorized
    }
    
    enum Position {
        case front
        case back
        mutating func toggle() {
            switch self {
            case .back:
                self = .front
            case .front:
                self = .back
            }
        }
        
        var avPosition: AVCaptureDevice.Position {
            switch self {
            case .back:
                return .back
            case .front:
                return .front
            }
        }
    }
    
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var shouldShowAlertView = false
    @Published var willCapturePhoto = false
    @Published var photo: Photo?
    @Published var cameraPosition = Position.back
    
    var alertError: AlertError = AlertError()
    
    let session = AVCaptureSession()
    
    private var setupResult: SessionSetupResult = .success
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: AVCapturePhotoCaptureDelegate]()
    
    func checkForPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
            }
        default:
            setupResult = .notAuthorized
        }
    }
    
    private func addCameraDeviceInput(position: Position = .back) {
        if let old = self.videoDeviceInput {
            self.session.removeInput(old)
        }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition) {
            if let videoDeviceInput = try? AVCaptureDeviceInput(device: device) {
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                }
            }
        }
        // 防抖
        if let photoOutputConnection = self.photoOutput.connection(with: .video), photoOutputConnection.isVideoStabilizationSupported {
            photoOutputConnection.preferredVideoStabilizationMode = .standard
        }
    }
    
    func changeCamera() {
        self.cameraPosition.toggle()
        self.session.beginConfiguration()
        self.addCameraDeviceInput(position: self.cameraPosition)
        self.session.commitConfiguration()
    }
    
    func configureSession() {
        if setupResult != .success {
            return
        }
        self.session.beginConfiguration()
        self.session.sessionPreset = .photo
        
        self.addCameraDeviceInput(position: self.cameraPosition)
        
        if self.session.canAddOutput(photoOutput) {
            self.session.addOutput(photoOutput)
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            self.session.commitConfiguration()
            return
        }
        
        self.session.commitConfiguration()
        
        self.start()
    }
    
    private func start() {
        switch self.setupResult {
        case .success:
            if !self.session.isRunning {
                self.session.startRunning()
            }
        case .configurationFailed, .notAuthorized:
            print("Application not authorized to use camera")
            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Error", message: "App doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Go Settings", secondaryButtonTitle: "Cancel", primaryAction: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                }, secondaryAction: nil)
                self.shouldShowAlertView = true
            }
        }
    }
    
    func capturePhoto(rawOption: RAWSaveOption) {
        guard self.setupResult != .configurationFailed else {
            return
        }
        
        if let photoOutputConnection = self.photoOutput.connection(with: .video), photoOutputConnection.isVideoOrientationSupported {
            photoOutputConnection.videoOrientation = OrientationListener.shared.videoOrientation
        }
        
        let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first { code in
            if photoOutput.isAppleProRAWEnabled {
                return AVCapturePhotoOutput.isAppleProRAWPixelFormat(code)
            }
            return AVCapturePhotoOutput.isBayerRAWPixelFormat(code)
        }
        
        let photoSettings: AVCapturePhotoSettings
        let processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]
        
        var rawOption = rawOption
        if let rawFormat = rawFormat {
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat, processedFormat: processedFormat)
        } else {
            photoSettings = AVCapturePhotoSettings(format: processedFormat)
            rawOption = .jpegOnly
        }
        
//        if let location = LocationManager.shared.location {
//            photoSettings.metadata[kCGImagePropertyGPSDictionary as String] = [
//                kCGImagePropertyGPSLatitude as String: location.coordinate.latitude,
//                kCGImagePropertyGPSLongitude as String: location.coordinate.longitude,
//            ]
        // 这部分很难弄，很多信息要填
//        }
        if self.videoDeviceInput?.device.isFlashAvailable == true {
            photoSettings.flashMode = self.flashMode
        }
        
        // Create a delegate to monitor the capture process.
        let delegate = RAWCaptureDelegate(option: rawOption)
        self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = delegate
        
        self.willCapturePhoto = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.willCapturePhoto = false
        }
        // Remove the delegate reference when it finishes its processing.
        delegate.didFinish = { phot in
            self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = nil
            self.photo = phot
        }
        
        // Tell the output to capture the photo.
        photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
    }
}
