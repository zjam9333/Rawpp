//
//  LocationManager.swift
//  LocationManager
//
//  Created by zjj on 2021/9/16.
//

import UIKit
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    static let shared = LocationManager()
    
    var location: CLLocation?
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        startLoading()
    }
    
    private func startLoading() {
//        manager.requestAlwaysAuthorization()
//        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.location = locations.first
        print("didUpdateLocations", locations)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
}
