import UIKit
import Flutter
import GoogleMaps
import Firebase
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {

  var locationManager: CLLocationManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Initialize Firebase
    FirebaseApp.configure()

    // Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyBzdajHgG7xEXtoglNS42Jbh8NdMUj2DXk")
    
    // Register the generated Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Location Manager setup
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.requestWhenInUseAuthorization()
    locationManager?.startUpdatingLocation()

    // Set up notification center delegate for iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
          print("Error requesting notification authorization: \(error)")
        }
      }
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle APNs token registration
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("APNs token retrieved: \(deviceToken)")
    Messaging.messaging().apnsToken = deviceToken
  }

  // Handle errors in registering for notifications
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }

  // CLLocationManagerDelegate method for handling location permissions
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      locationManager?.startUpdatingLocation()
    case .denied, .restricted:
      // Handle denied or restricted location access
      break
    default:
      break
    }
  }

  // UNUserNotificationCenterDelegate method for foreground notifications
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .badge, .sound])
  }

  // UNUserNotificationCenterDelegate method for handling user interaction with notifications
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    // Handle the notification interaction here
    completionHandler()
  }
}
