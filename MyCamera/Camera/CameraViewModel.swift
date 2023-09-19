//
//  CameraViewModel.swift
//  MyCamera
//
//  Created by zjj on 2021/9/15.
//

import Foundation
import Combine
import AVFoundation

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
    
    private static var cachedRawOption: RAWSaveOption {
        get {
            guard let value = UserDefaults.standard.value(forKey: "CameraViewModelCachedRawOption") as? Int else {
                return .jpegOnly
            }
            return RAWSaveOption(rawValue: value) ?? .jpegOnly
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
    
    init() {
        
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
    
    func flipCamera() {
        DispatchQueue.global().async { [self] in
            service.changeCamera()
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
