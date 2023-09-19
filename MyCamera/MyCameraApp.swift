//
//  MyCameraApp.swift
//  MyCamera
//
//  Created by zjj on 2021/9/15.
//

import SwiftUI

@main
struct MyCameraApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
                .environmentObject(OrientationListener.shared)
                .environmentObject(LocationManager.shared)
        }
    }
}
