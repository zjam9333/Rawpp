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
    @Published var alertError: AlertError?
    @Published var isFlashOn = false
    @Published var isCapturing = false
    @Published var isProcessing = false
    @Published var rawOption: RAWSaveOption = .cachedRawOption {
        didSet {
            RAWSaveOption.cachedRawOption = rawOption
        }
    }
    @Published var showPhoto: Bool = false
    @Published var showSetting: Bool = false
    
    @Published var shutterTimer = ShutterTimer.zero
    @Published var timerSeconds: TimerObject? = nil
    
    @Published var exposureMode = ExposureMode.auto
    @Published var exposureValue: ExposureValue = .zero
    @Published var shutterSpeed: ShutterSpeed = .percent100
    @Published var ISO: ISOValue = .iso100
    
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    @Published var currentCamera: CameraDevice?
    
    @Published var allCameras: [SelectItem] = []
    
    @Published var showingEVIndicators = false
    @Published var isAppInBackground = false
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    private var autoTimer: Timer?
    
    func touchFeedback() {
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()
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
        
        service.$allCameras.combineLatest(service.$currentCamera).receive(on: DispatchQueue.main).sink { [weak self] ca, ca2 in
            let currentDevice = ca2
            self?.currentCamera = ca2
            self?.allCameras = ca[currentDevice?.device.position ?? .back]?.map { d in
                let title = String(format: d.magnification >= 1 ? "x%.0f" : "x%.01f", d.magnification)
                let selected = currentDevice?.device == d.device
                let r = SelectItem(isSelected: selected, title: title) {
                    guard let self = self else {
                        return
                    }
                    Task {
                        await self.service.selectedCamera(d)
                        await self.setExposure()
                    }
                }
                return r
            } ?? []
        }
        .store(in: &self.subscriptions)
        
        $exposureValue.combineLatest($exposureMode).combineLatest($ISO).combineLatest($shutterSpeed).receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self = self else {
                return
            }
            Task {
                await self.setExposure()
            }
        }.store(in: &self.subscriptions)
        
        $videoOrientation.receive(on: DispatchQueue.main).sink { [weak self] ori in
            guard let self = self else {
                return
            }
            Task {
                await self.service.orientationChanged(orientation: ori)
            }
        }.store(in: &self.subscriptions)
    }
    
    // MARK: Camera Service
    
    func configure() {
        Task {
            let succ = await service.checkForPermissions()
            if succ == .success {
                await service.configureSession()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await setExposure()
            } else {
                await MainActor.run {
                    self.alertError = AlertError(title: "Camera Error", message: "App doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Go Settings", secondaryButtonTitle: "Cancel", primaryAction: {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }, secondaryAction: nil)
                }
            }
        }
    }
    
    func capturePhoto() {
        @Sendable @MainActor func toggleIsCapturing() async {
            self.isCapturing = true
            try? await Task.sleep(nanoseconds: 0_100_000_000)
            self.isCapturing = false
        }
        Task {
            await toggleIsCapturing()
        }
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
        Task {
            await MainActor.run {
                isProcessing = true
            }
            let result = await service.capturePhoto(rawOption: rawOption, location: lastLocation, flashMode: isFlashOn ? .on : .off)
            await MainActor.run {
                isProcessing = false
            }
            switch result {
            case .failure(let alert):
                await MainActor.run {
                    var alert = alert
                    alert.primaryAction = { [weak self] in
                        self?.alertError = nil
                    }
                    self.alertError = alert
                }
            case .success(let pic):
                if let pic = pic {
                    await MainActor.run {
                        self.photos.insert(pic, at: 0)
                        let maxCnt = 5
                        // 节省空间
                        if self.photos.count > maxCnt {
                            self.photos = Array(self.photos.prefix(maxCnt))
                        }
                    }
                }
            }
            
        }
    }
    
    func toggleFrontCamera() {
        Task {
            await service.toggleFrontCamera()
            await setExposure()
        }
    }
    
    func switchFlash() {
        isFlashOn.toggle()
    }
    
    func focus(pointOfInterest: CGPoint) {
        Task {
            await service.focus(pointOfInterest: pointOfInterest)
        }
    }
    
    private func setExposure() async {
        switch exposureMode {
        case .auto:
            await service.setExposureValue(exposureValue.floatValue)
        case .manual:
            await service.setCustomExposure(shutterSpeed: shutterSpeed.cmTime, iso: ISO.floatValue)
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
