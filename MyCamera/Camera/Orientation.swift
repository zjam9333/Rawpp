//
//  Ori.swift
//  MyCamera
//
//  Created by zjj on 2023/9/15.
//

import Foundation
import AVFoundation
import CoreMotion

class OrientationListener: ObservableObject {
    
    static let shared = OrientationListener()
    
    let motionManager = CMMotionManager()
    
    func startListen() {
        
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] acc, err in
                guard let acc = acc else {
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
    }
    
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
}
