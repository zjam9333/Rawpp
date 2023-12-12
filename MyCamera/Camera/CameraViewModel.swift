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
    
    @Published var photos: [Photo] = []
    @Published var showAlertError = false
    @Published var isFlashOn = false
    @Published var isCapturing = false
    @Published var rawOption: RAWSaveOption = .cachedRawOption {
        didSet {
            RAWSaveOption.cachedRawOption = rawOption
        }
    }
    @Published var showPhoto: Bool = false
    @Published var showSetting: Bool = false
    
    @Published var exposureMode = ExposureMode.auto
    @Published var shutterTimer = ShutterTimer.zero
    @Published var timerSeconds: TimerObject? = nil
    
    @Published var exposureValue: ExposureValue = .cachedExposureValue {
        didSet {
            let range: ClosedRange<Float> = -1...1
            if range.contains(exposureValue.floatValue) {
                ExposureValue.cachedExposureValue = exposureValue
            }
        }
    }
    
    @Published var shutterSpeed: ShutterSpeed = .percent100
    @Published var ISO: ISOValue = .iso100
    
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    @Published var cameraPosition = AVCaptureDevice.Position.back
    @Published var cameraLens = AVCaptureDevice.DeviceType.builtInWideAngleCamera
    
    @Published var showingEVIndicators = false
    @Published var isAppInBackground = false
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    var lastEVDragOffset: CGFloat = 0
    
    private var autoTimer: Timer?
    
    func touchFeedback() {
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()
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
            self?.photos.insert(pic, at: 0)
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
        
        $exposureValue.receive(on: DispatchQueue.global()).sink { [weak self] _ in
            self?.setExposure()
        }.store(in: &self.subscriptions)
        
        $ISO.receive(on: DispatchQueue.global()).sink { [weak self] _ in
            self?.setExposure()
        }.store(in: &self.subscriptions)
        
        $shutterSpeed.receive(on: DispatchQueue.global()).sink { [weak self] _ in
            self?.setExposure()
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
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [self] in
                setExposure()
            }
        }
    }
    
    func capturePhoto() {
        timerSeconds = nil
        if shutterTimer.rawValue == 0 {
            reallyCapture()
            return
        }
        autoTimer?.invalidate()
        let countingTime = shutterTimer.rawValue
        timerSeconds = .init(startTime: Date(), value: countingTime - 0.1)
        autoTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] t in
            guard let timerSeconds = self?.timerSeconds else {
                t.invalidate()
                return
            }
            let now = Date()
            let leftTime = countingTime - now.timeIntervalSince(timerSeconds.startTime)
            self?.timerSeconds?.value = leftTime
            if leftTime < 0 {
                t.invalidate()
                self?.timerSeconds = nil
                self?.reallyCapture()
            }
        }
        RunLoop.main.add(autoTimer!, forMode: .common)
    }
    
    private func reallyCapture() {
        DispatchQueue.global().async { [self] in
            service.capturePhoto(rawOption: rawOption, location: lastLocation, flashMode: isFlashOn ? .on : .off)
        }
        self.isCapturing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isCapturing = false
        }
    }
    
    func changeCamera(step: Int) {
        DispatchQueue.global().async { [self] in
            service.changeCamera(step: step)
            setExposure()
        }
    }
    
    func toggleFrontCamera() {
        DispatchQueue.global().async { [self] in
            service.toggleFrontCamera()
            setExposure()
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
    
    private func setExposure() {
        DispatchQueue.global().async { [self] in
            switch exposureMode {
            case .auto:
                service.setExposureValue(exposureValue.floatValue)
            case .manual:
                service.setCustomExposure(shutterSpeed: shutterSpeed.cmTime, iso: ISO.floatValue)
            }
        }
    }
    
    func increaseEV(step: Int) {
        let values = ExposureValue.presetExposureValues
        guard let index = values.firstIndex(of: exposureValue) else {
            exposureValue = .zero
            return
        }
        let next = index + step
        if values.indices.contains(next) {
            exposureValue = values[next]
        }
    }
    
    func increaseISO(step: Int) {
        let values = ISOValue.presetISOs
        guard let index = values.firstIndex(of: ISO) else {
            ISO = .iso100
            return
        }
        let next = index + step
        if values.indices.contains(next) {
            ISO = values[next]
        }
    }
    
    func increaseShutterSpeed(step: Int) {
        let values = ShutterSpeed.presetShutterSpeeds
        guard let index = values.firstIndex(of: shutterSpeed) else {
            shutterSpeed = .percent100
            return
        }
        let next = index + step
        if values.indices.contains(next) {
            shutterSpeed = values[next]
        }
    }
    
    // MARK: Device Orientation
    
#if targetEnvironment(simulator)
    private var timer: Timer?
#endif
    
    private let motionManager = CMMotionManager()
    
    private func setupMotion() {
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
    
    private func stopAcc() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func startAcc() {
        motionManager.stopAccelerometerUpdates()
        motionManager.accelerometerUpdateInterval = 2
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
    
    private var lastLocation: CLLocation?
    private let locationManager = CLLocationManager()
    private func setupGPS() async {
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
