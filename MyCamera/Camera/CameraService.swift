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
            let devices = des.map { d in
                let format = d.activeFormat
                print("Device Found", d, format)
                return CameraDevice(device: d, fov: format.videoFieldOfView)
            }
            return devices
        }
        currentCamera = allCameras[.back]?.first { d in
            return d.device.deviceType == .builtInWideAngleCamera
        }
    }
    
    @Published var allCameras: [AVCaptureDevice.Position: [CameraDevice]] = [:]
    
    @Published var currentCamera: CameraDevice?
    
    let session = AVCaptureSession()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: AVCapturePhotoCaptureDelegate]()
    
    func checkForPermissions() async -> SessionSetupResult {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .success
        case .notDetermined:
            let grand = await AVCaptureDevice.requestAccess(for: .video)
            if grand {
                return .success
            }
            return .notAuthorized
        default:
            return .notAuthorized
        }
    }
    
    private func addCameraDeviceInput(device: AVCaptureDevice?) async {
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
    
    func selectedCamera(_ camera: CameraDevice) async {
        session.beginConfiguration()
        currentCamera = camera
        await addCameraDeviceInput(device: camera.device)
        session.commitConfiguration()
    }
    
    func toggleFrontCamera() async {
        let cameraPosition: AVCaptureDevice.Position
        if currentCamera?.device.position == .front {
            cameraPosition = .back
        } else {
            cameraPosition = .front
        }
        let c = allCameras[cameraPosition]?.first { dev in
            return dev.device.deviceType == .builtInWideAngleCamera
        }
        if let c = c {
            await selectedCamera(c)
        }
    }
    
    func configureSession() async {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        currentCamera = allCameras[.back]?.first { dev in
            return dev.device.deviceType == .builtInWideAngleCamera
        }
        await addCameraDeviceInput(device: currentCamera?.device)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            print("Could not add photo output to the session")
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func orientationChanged(orientation: AVCaptureVideoOrientation) async {
        if let photoOutputConnection = photoOutput.connection(with: .video), photoOutputConnection.isVideoOrientationSupported {
            photoOutputConnection.videoOrientation = orientation
        }
    }
    
    func focus(pointOfInterest: CGPoint) async {
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
    
    func setExposureValue(_ bias: Float) async {
        guard let device = videoDeviceInput?.device else {
            return
        }
        let min = device.minExposureTargetBias
        let max = device.maxExposureTargetBias
//        print("exposureTargetBias:" , min, max)
        guard min < bias, bias < max else {
            return
        }
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
    
    func setCustomExposure(shutterSpeed: CMTime, iso: Float) async {
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
        do {
            try device.lockForConfiguration()
            device.exposureMode = .custom
            let usingTime = await device.setExposureModeCustom(duration: shutterSpeed, iso: iso)
            print("pass", shutterSpeed, "using", usingTime)
            device.unlockForConfiguration()
        } catch {
            
        }
    }
    
    func capturePhoto(rawOption: RAWSaveOption, location: CLLocation?, flashMode: AVCaptureDevice.FlashMode, cropFactor: CGFloat) async -> Result<Photo?, AlertError> {
        guard let photoOutputConnection = photoOutput.connection(with: .video), photoOutputConnection.isActive, photoOutputConnection.isEnabled else {
            let err = AlertError(title: "Camera Error", message: "Camera Device is not Enabled", primaryButtonTitle: "OK", secondaryButtonTitle: "Cancel", primaryAction: nil, secondaryAction: nil)
            return .failure(err)
        }
        var photoSettings: AVCapturePhotoSettings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
//            AVVideoCompressionPropertiesKey: [
//                AVVideoQualityKey: RawFilterProperties.shared.output.heifLossyCompressionQuality.value,
//            ]
        ])
        photoSettings.photoQualityPrioritization = .speed
        photoSettings.isAutoVirtualDeviceFusionEnabled = false
        
        if rawOption.contains(.apple) == false {
            let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first { code in
                return AVCapturePhotoOutput.isBayerRAWPixelFormat(code)
            }
            if let rawFormat = rawFormat {
                photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
            }
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
        
        let photo = await self.capturePhoto(photoSettings: photoSettings, rawOption: rawOption, cropFactor: cropFactor)
        return .success(photo)
    }
    
    private func capturePhoto(photoSettings: AVCapturePhotoSettings, rawOption: RAWSaveOption, cropFactor: CGFloat) async -> Photo? {
        let photo = await withCheckedContinuation { con in
            // Create a delegate to monitor the capture process.
            let delegate = RAWCaptureDelegate(option: rawOption, cropFactor: cropFactor) { phot in
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
