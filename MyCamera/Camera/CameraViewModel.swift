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

class CameraViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
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
    
    @Published var showingEVIndicators = false
    @Published var isAppInBackground = false
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    var lastEVDragOffset: CGFloat = 0
    
    func touchFeedback() {
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()
    }
    
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
    
    override init() {
        super.init()
        
        Task {
            await setupGPS()
        }
        
        setupMotion()
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.isAppInBackground = false
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.isAppInBackground = true
        }.store(in: &subscriptions)
        
        $isAppInBackground.receive(on: DispatchQueue.main).sink { [weak self] isBack in
            if isBack {
                self?.stopAcc()
            } else {
                self?.startAcc()
            }
        }.store(in: &subscriptions)
        
        service.$photo.receive(on: DispatchQueue.main).sink { [weak self] (photo) in
            guard let pic = photo else { return }
            self?.photo = pic
        }
        .store(in: &self.subscriptions)
        
        service.$shouldShowAlertView.receive(on: DispatchQueue.main).sink { [weak self] (val) in
            self?.showAlertError = val
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
    
    // MARK: Camera Service
    
    func configure() {
        DispatchQueue.global().async { [self] in
            service.checkForPermissions()
            service.configureSession()
        }
    }
    
    func capturePhoto() {
        DispatchQueue.global().async { [self] in
            service.capturePhoto(rawOption: rawOption, location: lastLocation, flashMode: isFlashOn ? .on : .off)
        }
        self.isCapturing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isCapturing = false
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
        isFlashOn.toggle()
    }
    
    func focus(pointOfInterest: CGPoint) {
        DispatchQueue.global().async { [self] in
            service.focus(pointOfInterest: pointOfInterest)
        }
    }
    
    // MARK: Device Orientation
    
#if targetEnvironment(simulator)
    var timer: Timer?
#endif
    
    private let motionManager = CMMotionManager()
    
    func setupMotion() {
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
#endif
        
        startAcc()
    }
    
    func stopAcc() {
        motionManager.stopAccelerometerUpdates()
    }
    
    func startAcc() {
        motionManager.stopAccelerometerUpdates()
        motionManager.accelerometerUpdateInterval = 1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] dat, err in
            if let err = err {
                print("startAccelerometerUpdates Err", err)
            }
            guard let acc = dat else {
                return
            }
            let x = acc.acceleration.x
            let y = acc.acceleration.y
            print("acceleration", x, y)
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
    
    // MARK: Core Location
    
    var lastLocation: CLLocation?
    let locationManager = CLLocationManager()
    func setupGPS() async {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        try? await locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "AbcdefgKey")
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("didUpdateLocations", locations)
        if let fi = locations.first {
            lastLocation = fi
        }
    }
}
