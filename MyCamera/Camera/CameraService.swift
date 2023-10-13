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
    
    let usingDeviceTypes: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera]
    
    lazy var deviceDiscoveries: [AVCaptureDevice.Position: AVCaptureDevice.DiscoverySession] = [
        .back: AVCaptureDevice.DiscoverySession(deviceTypes: usingDeviceTypes, mediaType: .video, position: .back),
        .front: AVCaptureDevice.DiscoverySession(deviceTypes: usingDeviceTypes, mediaType: .video, position: .front)
    ]
    
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var shouldShowAlertView = false
    @Published var willCapturePhoto = false
    @Published var photo: Photo?
    @Published var cameraPosition = AVCaptureDevice.Position.back
    @Published var cameraLens = AVCaptureDevice.DeviceType.builtInWideAngleCamera
    
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
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if !granted {
                    self?.setupResult = .notAuthorized
                }
            }
        default:
            setupResult = .notAuthorized
        }
    }
    
    private func addCameraDeviceInput(device: AVCaptureDevice?) {
        if let old = videoDeviceInput {
            session.removeInput(old)
        }
        if let device = device, let videoDeviceInput = try? AVCaptureDeviceInput(device: device), session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        }
        // 防抖
        if let photoOutputConnection = photoOutput.connection(with: .video), photoOutputConnection.isVideoStabilizationSupported {
            photoOutputConnection.preferredVideoStabilizationMode = .standard
        }
    }
    
    private func firstDevice(position: AVCaptureDevice.Position, deviceType:  AVCaptureDevice.DeviceType) -> AVCaptureDevice? {
        let device = deviceDiscoveries[position]?.devices.first { dev in
            return dev.deviceType == deviceType
        }
        return device
    }
    
    func changeCamera(step: Int = 1) {
        session.beginConfiguration()
        
        func nextLen(current: AVCaptureDevice.DeviceType, step: Int) -> AVCaptureDevice.DeviceType {
            let firIndex = usingDeviceTypes.firstIndex(of: current)
            guard let firIndex = firIndex else {
                return current
            }
            let nex = firIndex + (step > 0 ? 1 : -1)
            if nex >= usingDeviceTypes.count {
                return current
            } else if nex < 0 {
                return current
            }
            return usingDeviceTypes[nex]
        }
        let old = cameraLens
        var nex = old
        while true {
            nex = nextLen(current: nex, step: step)
            if nex == old {
                break
            }
            if let device = firstDevice(position: cameraPosition, deviceType: nex) {
                cameraLens = nex
                addCameraDeviceInput(device: device)
                break
            }
        }
        
        session.commitConfiguration()
    }
    
    func toggleFrontCamera() {
        session.beginConfiguration()
        if cameraPosition == .front {
            cameraPosition = .back
        } else {
            cameraPosition = .front
        }
        cameraLens = .builtInWideAngleCamera
        let device = firstDevice(position: cameraPosition, deviceType: cameraLens)
        addCameraDeviceInput(device: device)
        session.commitConfiguration()
    }
    
    func configureSession() {
        if setupResult != .success {
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        let device = firstDevice(position: cameraPosition, deviceType: cameraLens)
        addCameraDeviceInput(device: device)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        
        start()
    }
    
    private func start() {
        switch setupResult {
        case .success:
            if !session.isRunning {
                session.startRunning()
            }
        default:
            print("Application not authorized to use camera")
            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Error", message: "App doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Go Settings", secondaryButtonTitle: "Cancel", primaryAction: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                }, secondaryAction: nil)
                self.shouldShowAlertView = true
            }
        }
    }
    
    func orientationChanged(orientation: AVCaptureVideoOrientation) {
        if let photoOutputConnection = photoOutput.connection(with: .video), photoOutputConnection.isVideoOrientationSupported {
            photoOutputConnection.videoOrientation = orientation
        }
    }
    
    func focus(pointOfInterest: CGPoint) {
        guard let device = videoDeviceInput?.device, device.isFocusPointOfInterestSupported else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = pointOfInterest
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            device.unlockForConfiguration()
        } catch {
            
        }
    }
    
    func setExposureBias(_ bias: Float) {
        guard let device = videoDeviceInput?.device else {
            return
        }
        let min = device.minExposureTargetBias
        let max = device.maxExposureTargetBias
//        print("exposureTargetBias:" , min, max)
        guard min < bias, bias < max else {
            return
        }
        Task {
            do {
                try device.lockForConfiguration()
                await device.setExposureTargetBias(bias)
                device.unlockForConfiguration()
            } catch {
                
            }
        }
    }
    
    func capturePhoto(rawOption: RAWSaveOption) {
        guard setupResult != .configurationFailed else {
            return
        }
        
        guard let photoOutputConnection = photoOutput.connection(with: .video), photoOutputConnection.isActive, photoOutputConnection.isEnabled else {
            alertError = AlertError(title: "Camera Error", message: "Simulator Camera Not Working", primaryButtonTitle: "OK", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
            shouldShowAlertView = true
            return
        }
        
        let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first { code in
//            if photoOutput.isAppleProRAWEnabled {
//                return AVCapturePhotoOutput.isAppleProRAWPixelFormat(code)
//            }
            return AVCapturePhotoOutput.isBayerRAWPixelFormat(code)
        }
        
        let photoSettings: AVCapturePhotoSettings
        let processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]
        
        if let rawFormat = rawFormat {
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        } else {
            photoSettings = AVCapturePhotoSettings(format: processedFormat)
        }
        
//        if let location = LocationManager.shared.location {
//            photoSettings.metadata[kCGImagePropertyGPSDictionary as String] = [
//                kCGImagePropertyGPSLatitude as String: location.coordinate.latitude,
//                kCGImagePropertyGPSLongitude as String: location.coordinate.longitude,
//            ]
        // 这部分很难弄，很多信息要填
//        }
        if videoDeviceInput?.device.isFlashAvailable == true {
            photoSettings.flashMode = flashMode
        }
        
        // Create a delegate to monitor the capture process.
        let delegate = RAWCaptureDelegate(option: rawOption)
        inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = delegate
        
        willCapturePhoto = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.willCapturePhoto = false
        }
        // Remove the delegate reference when it finishes its processing.
        delegate.didFinish = { [weak self] phot in
            self?.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = nil
            self?.photo = phot
        }
        
        // Tell the output to capture the photo.
        photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
    }
}
