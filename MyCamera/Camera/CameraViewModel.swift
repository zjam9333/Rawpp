//
//  CameraViewModel.swift
//  MyCamera
//
//  Created by zjj on 2021/9/15.
//

import Foundation
import Combine
import AVFoundation
import UIKit
import CoreMotion
import CoreLocation

@MainActor class CameraViewModel: ObservableObject {
    private let service = CameraService()
    
    @Published var photo: Photo?
    @Published var showAlertError = false
    @Published var isFlashOn = false
    @Published var isCapturing = false
    @Published var rawOption: RAWSaveOption = CameraViewModel.cachedRawOption {
        didSet {
            CameraViewModel.cachedRawOption = rawOption
        }
    }
    @Published var showPhoto: Bool = false
    
    @Published var exposureBias: EVValue = .zero
    
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    @Published var cameraPosition = AVCaptureDevice.Position.back
    @Published var cameraLens = AVCaptureDevice.DeviceType.builtInWideAngleCamera
    
    private static var cachedRawOption: RAWSaveOption {
        get {
            guard let value = UserDefaults.standard.value(forKey: "CameraViewModelCachedRawOption") as? Int else {
                return .heif
            }
            return RAWSaveOption(rawValue: value) ?? .heif
        }
        set {
            let value = newValue.rawValue
            UserDefaults.standard.setValue(value, forKey: "CameraViewModelCachedRawOption")
        }
    }
    
    var alertError: AlertError {
        self.service.alertError
    }
    
    var session: AVCaptureSession {
        return service.session
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
#if targetEnvironment(simulator)
    var timer: Timer?
#else
    private let motionManager = CMMotionManager()
#endif
    
    init() {
//        manager.delegate = self
//        manager.requestAlwaysAuthorization()
//        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "AbcdefgKey")
//        manager.startUpdatingLocation()
        
#if targetEnvironment(simulator)
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] t in
            let uiori = UIDevice.current.orientation
            switch uiori {
            case .portrait:
                self?.videoOrientation = .portrait
            case .portraitUpsideDown:
                self?.videoOrientation = .portraitUpsideDown
                // 左右反的？
            case .landscapeLeft:
                self?.videoOrientation = .landscapeRight
            case .landscapeRight:
                self?.videoOrientation = .landscapeLeft
            default:
                break
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
#else
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] acc, err in
                guard let acc = acc else {
                    return
                }
                let x = acc.acceleration.x
                let y = acc.acceleration.y
                //                print("acceleration", x, y)
                if abs(x) > abs(y) {
                    if abs(x) > 0.6 {
                        self?.videoOrientation = x > 0 ? .landscapeLeft : .landscapeRight
                    }
                } else {
                    if abs(y) > 0.6 {
                        self?.videoOrientation = y > 0 ? .portraitUpsideDown : .portrait
                    }
                }
            }
        }
        #endif
        
        service.$photo.receive(on: DispatchQueue.main).sink { [weak self] (photo) in
            guard let pic = photo else { return }
            self?.photo = pic
        }
        .store(in: &self.subscriptions)
        
        service.$shouldShowAlertView.receive(on: DispatchQueue.main).sink { [weak self] (val) in
            self?.showAlertError = val
        }
        .store(in: &self.subscriptions)
        
        service.$flashMode.receive(on: DispatchQueue.main).sink { [weak self] (mode) in
            self?.isFlashOn = mode == .on
        }
        .store(in: &self.subscriptions)
        
        service.$willCapturePhoto.receive(on: DispatchQueue.main).sink { [weak self] ca in
            self?.isCapturing = ca
        }
        .store(in: &self.subscriptions)
        
        service.$cameraLens.receive(on: DispatchQueue.main).sink { [weak self] ca in
            self?.cameraLens = ca
        }
        .store(in: &self.subscriptions)
        
        service.$cameraPosition.receive(on: DispatchQueue.main).sink { [weak self] ca in
            self?.cameraPosition = ca
        }
        .store(in: &self.subscriptions)
        
        $exposureBias.receive(on: DispatchQueue.global()).sink { [weak self] bias in
            self?.service.setExposureBias(bias.rawValue)
        }.store(in: &self.subscriptions)
        
        $videoOrientation.receive(on: DispatchQueue.global()).sink { [weak self] ori in
            self?.service.orientationChanged(orientation: ori)
        }.store(in: &self.subscriptions)
    }
    
    
    func configure() {
        DispatchQueue.global().async { [self] in
            service.checkForPermissions()
            service.configureSession()
        }
    }
    
    func capturePhoto() {
        let r = rawOption
        DispatchQueue.global().async { [self] in
            service.capturePhoto(rawOption: r)
        }
    }
    
    func changeCamera(step: Int) {
        let bia = exposureBias.rawValue
        DispatchQueue.global().async { [self] in
            service.changeCamera(step: step)
            service.setExposureBias(bia)
        }
    }
    
    func toggleFrontCamera() {
        let bia = exposureBias.rawValue
        DispatchQueue.global().async { [self] in
            service.toggleFrontCamera()
            service.setExposureBias(bia)
        }
    }
    
    func switchFlash() {
        DispatchQueue.global().async { [self] in
            service.flashMode = service.flashMode == .on ? .off : .on
        }
    }
    
    func focus(pointOfInterest: CGPoint) {
        DispatchQueue.global().async { [self] in
            service.focus(pointOfInterest: pointOfInterest)
        }
    }
}
