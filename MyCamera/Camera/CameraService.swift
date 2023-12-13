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
    
    init() {
        let usingDeviceTypes: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera]
        
        let deviceDiscoveries: [AVCaptureDevice.Position: AVCaptureDevice.DiscoverySession] = [
            .back: AVCaptureDevice.DiscoverySession(deviceTypes: usingDeviceTypes, mediaType: .video, position: .back),
            .front: AVCaptureDevice.DiscoverySession(deviceTypes: usingDeviceTypes, mediaType: .video, position: .front)
        ]
        allCameras = deviceDiscoveries.compactMapValues { session in
            let des = session.devices
            var devices = des.map { d in
                let format = d.activeFormat
                print("Device Found", d, format)
                return CameraDevice(device: d, fov: format.videoFieldOfView)
            }
            let oneAng = devices.first { d in
                return d.device.deviceType == .builtInWideAngleCamera
            }?.fov ?? 60
            devices = devices.map { d in
                var d = d
                if d.fov <= 0 {
                    return d
                }
                d.magnification = oneAng / d.fov
                return d
            }
            return devices
        }
        currentCamera = allCameras[.back]?.first { d in
            return d.device.deviceType == .builtInWideAngleCamera
        }
    }
    
    @Published var allCameras: [AVCaptureDevice.Position: [CameraDevice]] = [:]
    
    @Published var shouldShowAlertView = false
    @Published var photo: Photo?
    @Published var currentCamera: CameraDevice?
    
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
    
    func selectedCamera(_ camera: CameraDevice) {
        session.beginConfiguration()
        currentCamera = camera
        addCameraDeviceInput(device: camera.device)
        session.commitConfiguration()
    }
    
    func toggleFrontCamera() {
        session.beginConfiguration()
        let cameraPosition: AVCaptureDevice.Position
        if currentCamera?.device.position == .front {
            cameraPosition = .back
        } else {
            cameraPosition = .front
        }
        currentCamera = allCameras[cameraPosition]?.first { dev in
            return dev.device.deviceType == .builtInWideAngleCamera
        }
        addCameraDeviceInput(device: currentCamera?.device)
        session.commitConfiguration()
    }
    
    func configureSession() {
        if setupResult != .success {
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        currentCamera = allCameras[.back]?.first { dev in
            return dev.device.deviceType == .builtInWideAngleCamera
        }
        addCameraDeviceInput(device: currentCamera?.device)
        
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
    
    func setExposureValue(_ bias: Float) {
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
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
                await device.setExposureTargetBias(bias)
                device.unlockForConfiguration()
            } catch {
                
            }
        }
    }
    
    func setCustomExposure(shutterSpeed: CMTime, iso: Float) {
        guard let device = videoDeviceInput?.device else {
            return
        }
        guard device.isExposureModeSupported(.custom) else {
            return
        }
        let isoRange = device.activeFormat.minISO...device.activeFormat.maxISO
        guard isoRange.contains(iso) else {
            return
        }
        let shutterRange = device.activeFormat.minExposureDuration.seconds...device.activeFormat.maxExposureDuration.seconds
        guard shutterRange.contains(shutterSpeed.seconds) else {
            return
        }
        Task {
            do {
                try device.lockForConfiguration()
                device.exposureMode = .custom
                let usingTime = await device.setExposureModeCustom(duration: shutterSpeed, iso: iso)
                print("pass", shutterSpeed, "using", usingTime)
                device.unlockForConfiguration()
            } catch {
                
            }
        }
    }
    
    func capturePhoto(rawOption: RAWSaveOption, location: CLLocation?, flashMode: AVCaptureDevice.FlashMode) {
        guard setupResult != .configurationFailed else {
            return
        }
        
        guard let photoOutputConnection = photoOutput.connection(with: .video), photoOutputConnection.isActive, photoOutputConnection.isEnabled else {
            alertError = AlertError(title: "Camera Error", message: "Simulator Camera Not Working", primaryButtonTitle: "OK", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
            shouldShowAlertView = true
            return
        }
        
        let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first { code in
            return AVCapturePhotoOutput.isBayerRAWPixelFormat(code)
        }
        
        let photoSettings: AVCapturePhotoSettings
        
        if let rawFormat = rawFormat {
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        } else {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        
        if let location = location {
            photoSettings.metadata[kCGImagePropertyGPSDictionary as String] = [
                kCGImagePropertyGPSLatitude as String: location.coordinate.latitude,
                kCGImagePropertyGPSLongitude as String: location.coordinate.longitude,
            ]
//         这部分很难弄，很多信息要填
        }
        if videoDeviceInput?.device.isFlashAvailable == true {
            photoSettings.flashMode = flashMode
        }
        
        Task {
            let photo = await self.capturePhoto(photoSettings: photoSettings, rawOption: rawOption)
            await MainActor.run {
                self.photo = photo
            }
        }
    }
    
    private func capturePhoto(photoSettings: AVCapturePhotoSettings, rawOption: RAWSaveOption) async -> Photo? {
        let photo = await withCheckedContinuation { con in
            // Create a delegate to monitor the capture process.
            let delegate = RAWCaptureDelegate(option: rawOption) { phot in
                con.resume(returning: phot)
            }
            inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = delegate
            
            // Tell the output to capture the photo.
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
        self.inProgressPhotoCaptureDelegates[photoSettings.uniqueID] = nil
        return photo
    }
}
