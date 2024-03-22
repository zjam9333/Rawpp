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
    
    @Published private(set) var photos: [Photo] = []
    @Published private(set) var alertError: AlertError?
    @Published private(set) var isFlashOn = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isProcessing = false
    @Published var rawOption = MappedCustomizeValue<RAWSaveOption, RAWSaveOption.RawValue>(name: "CameraViewModelCachedRawOption", default: .heif) { op in
        return op.rawValue
    } get: { va in
        guard va > 0 else {
            return .heif
        }
        return .init(rawValue: va)
    }
    @Published var showPhoto: Bool = false
    @Published var showSetting: Bool = false
    
    @Published private(set) var shutterTimer: Int = 0
    @Published private(set) var timerSeconds: TimerObject? = nil
    @Published private(set) var burstCount: Int = 1
    @Published private(set) var burstObject: BurstObject? = nil
    
    @Published var exposureMode = ExposureMode.program
    @Published var exposureValue = ExposureValue.zero
    @Published var programExposureShift: Int = 0
    
    @Published private(set) var currentExposureInfo: DeviceExposureInfo = .unknown
    @Published var manualExposure: ExposureAdvice = .default
    
    private var pauseAutoExposure = false
    @Published private(set) var programExposureAdvices: [ExposureAdvice] = []
    
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
    
    @Published var currentCamera: CameraDevice?
    
    @Published var allLenses: [SelectItem] = []
    
    @Published var showingEVIndicators = false
    @Published var isAppInBackground = false
    
    @Published var cropFactor: CustomizeValue<CGFloat> = .init(name: "CustomizeValue_cropFactor", default: 1, minValue: 1, maxValue: 2)
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    func touchFeedback() {
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()
    }
    
    var session: AVCaptureSession {
        return service.session
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    private var exposureMeterTimer: Timer?
    
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
                // 进入后台恢复某些设置
                self?.resetToDefault()
            } else {
                self?.startAcc()
            }
        }.store(in: &subscriptions)
        
        service.$allCameras.combineLatest(service.$currentCamera).combineLatest($cropFactor).receive(on: DispatchQueue.main).sink { [weak self] obj in
            let currentDevice = obj.0.1
            self?.currentCamera = obj.0.1
            let allLenses: [SelectItem] = obj.0.0[currentDevice?.device.position ?? .back]?.map { d in
                let deviceSelected = currentDevice == d
                var thisLenesSelections: [SelectItem] = []
                do {
                    // 实际的摄像头
                    let title = String(format: "%.0f", ceil(d.focalLength))
                    let selected = deviceSelected && self?.cropFactor.value == 1
                    let this = SelectItem(id: "\(d)-", isSelected: selected, isMain: true, title: title) {
                        guard let self = self else {
                            return
                        }
                        self.cropFactor.value = 1
                        guard !deviceSelected else {
                            return
                        }
                        Task {
                            await self.service.selectedCamera(d)
                            await self.setExposure()
                        }
                    }
                    thisLenesSelections.append(this)
                }
                if deviceSelected && d.focalLength > 20 {
                    // 拓展几个缩放倍数，没有实际切换摄像头
                    let factors: [CGFloat] = [1.1, 1.2, 1.4]
                    for factor in factors {
                        let title = String(format: "%.0f", ceil(CGFloat(d.focalLength) * factor))
                        let selected = self?.cropFactor.value == factor
                        let croppedOption = SelectItem(id: "\(d)-\(factor)", isSelected: selected, isMain: false, title: title) {
                            guard let self = self else {
                                return
                            }
                            self.cropFactor.value = factor
                        }
                        thisLenesSelections.append(croppedOption)
                    }
                }
                return thisLenesSelections
            }.flatMap { i in
                i
            } ?? []
            self?.allLenses = allLenses
        }
        .store(in: &self.subscriptions)
        
        $manualExposure.receive(on: DispatchQueue.main).sink { [weak self] _ in
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
        
        exposureMeterTimer = Timer.init(timeInterval: 0.5, repeats: true) { [weak self] t in
            self?.checkEV()
        }
        RunLoop.main.add(exposureMeterTimer!, forMode: .common)
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
                        [weak self] in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                        self?.alertError = nil
                    }, secondaryAction: nil)
                }
            }
        }
    }
    
    func capturePhoto() {
        Task {
            await capturePhotoAsync()
        }
    }
    
    @MainActor private func capturePhotoAsync() async {
        @Sendable @MainActor func toggleIsCapturing() async {
            self.isCapturing = true
            try? await Task.sleep(nanoseconds: 0_200_000_000)
            self.isCapturing = false
        }
        Task {
            await toggleIsCapturing()
        }
        
        if shutterTimer == 0 {
            await startCapture()
            return
        }
        
        let countingTime = TimeInterval(shutterTimer)
        timerSeconds = .init(startTime: Date(), value: countingTime - 0.1)
        
        while timerSeconds != nil {
            try? await Task.sleep(nanoseconds: 0_100_000_000)
            guard let startTime = timerSeconds?.startTime else {
                break
            }
            let now = Date()
            let leftTime = countingTime - now.timeIntervalSince(startTime)
            timerSeconds?.value = leftTime
            if leftTime < 0 {
                timerSeconds = nil
            }
        }
        await startCapture()
    }
    
    @MainActor private func startCapture() async {
        isProcessing = true
        let burstTime = max(1, burstCount)
        if burstTime > 1 {
            burstObject = .init(total: burstTime, current: 0)
        }
        let newPhotoObj = Photo(data: nil)
        photos.insert(newPhotoObj, at: 0)
        for _ in 0..<burstTime {
            burstObject?.current += 1
            
            let result = await service.capturePhoto(rawOption: rawOption.value, location: lastLocation, flashMode: isFlashOn ? .on : .off, cropFactor: max(CGFloat(cropFactor.value), 1))
            switch result {
            case .failure(let alert):
                var alert = alert
                alert.primaryAction = { [weak self] in
                    self?.alertError = nil
                }
                alertError = alert
            case .success(let pic):
                if let data = pic, let thatIndex = photos.firstIndex(of: newPhotoObj) {
                    // 这里不可以再拿0，因为可能快速连续点击拍摄，导致数组已变化
                    var p0 = photos[thatIndex]
                    p0.data = data
                    p0.count += 1
                    photos[thatIndex] = p0
                }
            }
            
        }
        burstObject = nil
        isProcessing = false
        
        let maxCnt = 5
        // 节省空间
        if photos.count > maxCnt {
            photos = Array(photos.prefix(maxCnt))
        }
    }
    
    private func resetToDefault() {
        burstCount = 1
        shutterTimer = 0
        manualExposure = .default
        exposureValue = .zero
        programExposureShift = 0
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
        case .program, .manual:
            let e = manualExposure
            await service.setCustomExposure(ev: exposureValue.floatValue, shutterSpeed: e.ss.cmTime, iso: e.iso.floatValue)
        }
    }
    
    func resetExposure() {
        switch exposureMode {
        case .auto:
            exposureValue = .zero
        case .manual:
            manualExposure = .default
        case .program:
            exposureValue = .zero
            programExposureShift = 0
        }
    }
    
    func toggleTimer() {
        let d = [
            0: 2,
            2: 5,
            5: 10,
        ]
        shutterTimer = d[shutterTimer] ?? 0
    }
    
    func toggleBurst() {
        let d = [
            1: 5,
            5: 10,
            10: 20,
            20: 40,
            40: 60,
            60: 100,
        ]
        burstCount = d[burstCount] ?? 1
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
    
    // MARK: Program Exposure
    
    private func checkEV() {
        guard let device = currentCamera?.device else {
            return
        }
        let info = DeviceExposureInfo(duration: device.exposureDuration, iso: device.iso, evOffset: device.exposureTargetOffset)
        print("current DeviceExposureInfo", info)
        currentExposureInfo = info
        programExposure()
    }
    
    func toggleProgramExposureMaunalShift() {
        guard exposureMode == .program else {
            return
        }
        let advice = programExposurePerfer(advices: programExposureAdvices, shift: programExposureShift)
        manualExposure = advice
        Task {
            await MainActor.run {
                pauseAutoExposure = true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                pauseAutoExposure = false
            }
        }
    }
    
    private func programExposurePerfer(advices: [ExposureAdvice], shift: Int) -> ExposureAdvice {
        let index = pickValueBetween(minVal: 0, maxVal: advices.count, input: advices.count / 2 + shift) { i, j in
            return i < j
        }
        return advices[index]
    }
    
    private func programExposure() {
        
        guard !pauseAutoExposure else {
            return
        }
        guard exposureMode == .program else {
            return
        }
        
        // 检查差了多少档曝光
        let currentEVOffset = currentExposureInfo.offset
//        guard currentEVOffset != .zero else {
//            print("program Exposure", "OK")
//            return
//        }
        
        let isOverExposure = currentEVOffset.floatValue > 0
        
        guard let currentIndex = ExposureValue.presets.firstIndex(of: currentEVOffset), let zeroIndex = ExposureValue.presets.firstIndex(of: .zero) else {
            return
        }
        
        var step: Int = abs(currentIndex - zeroIndex)
//        guard step > 1 else {
//            print("program Exposure", "OK")
//            return
//        }
        // TODO: ShutterSpeed ISOValue 不是严格的1/3档分布，慢快门时会导致反复横跳
        
        // 找出组合
        let allShutters = ShutterSpeed.presets.filter { ss in
            return ss.floatValue <= 0.11
        } // 太慢的不用
        let allISOs = ISOValue.presets.filter { ss in
            return ss.floatValue <= 1000
        } // 太快的不用
        
        var indexShutter = allShutters.firstIndex(of: manualExposure.ss) ?? 0
        var indexISO = allISOs.firstIndex(of: manualExposure.iso) ?? 0
        
        while step > 0 {
            step -= 1
            if isOverExposure {
                if indexShutter < allShutters.count - 1 {
                    indexShutter += 1
                } else if indexISO > 0 {
                    indexISO -= 1
                } else {
                    break
                }
            } else {
                if indexShutter > 0 {
                    indexShutter -= 1
                } else if indexISO < allISOs.count - 1 {
                    indexISO += 1
                } else {
                    break
                }
            }
        }
        
        // 找到s和i的重合位置
        // 两个向左移到最小的位置
        let minIndex = min(indexISO, indexShutter)
        indexISO -= minIndex
        indexShutter -= minIndex
        let maxLength = min(allISOs.count - indexISO, allShutters.count - indexShutter)
        programExposureAdvices = (0..<maxLength).map { ind in
            return ExposureAdvice(ss: allShutters[indexShutter + ind], iso: allISOs[indexISO + ind])
        }
        print("program Exposure", "advices", programExposureAdvices)
        
        let advice = programExposurePerfer(advices: programExposureAdvices, shift: programExposureShift)
        print("program Exposure", "Selected", advice)
        manualExposure = advice
    }
}
