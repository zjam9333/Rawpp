//
//  Ori.swift
//  MyCamera
//
//  Created by zjj on 2023/9/15.
//

import Foundation
import AVFoundation
import CoreMotion
import UIKit

class OrientationListener: ObservableObject {
    
    static let shared = OrientationListener()
    
    private let motionManager = CMMotionManager()
    
    
#if targetEnvironment(simulator)
    var timer: Timer?
#endif
    
    func startListen() {
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
    }
    
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            if oldValue != videoOrientation {
                print("videoOrientation", videoOrientation)
            }
        }
    }
}
