import UIKit
import Flutter
import GoogleMaps
import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  var locationManager: CLLocationManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()  
    GMSServices.provideAPIKey("AIzaSyBzdajHgG7xEXtoglNS42Jbh8NdMUj2DXk")
    GeneratedPluginRegistrant.register(with: self)
    
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.requestWhenInUseAuthorization()
    locationManager?.startUpdatingLocation()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      locationManager?.startUpdatingLocation()
    case .denied, .restricted:
      
      break
    default:
      break
    }
  }
  
}