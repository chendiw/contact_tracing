//
//  File.swift
//  contact_tracing
//
//  Created by Jiani Wang on 2022/5/25.
//

import Foundation
import CoreLocation


class LocationManager: NSObject, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager!
    private var long: CLLocationDegrees;
    private var lat: CLLocationDegrees;
    
    override init(){
//        super.init()
        self.long = CLLocationDegrees();
        self.lat = CLLocationDegrees();
        super.init();
        if (CLLocationManager.locationServicesEnabled())
        {
            self.locationManager = CLLocationManager()
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.requestAlwaysAuthorization()
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            // Handle location update
            print("[Get location]Latitude: \(latitude), Longitude: \(longitude)")
            self.lat = latitude;
            self.long = longitude;
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle failure to get a user’s location
        print("[Location Error] Get location error")
    }
    
    func getLatitude() -> CLLocationDegrees {
        return self.lat;
    }
    
    func getLongitude() -> CLLocationDegrees {
        return self.long;
    }
}

