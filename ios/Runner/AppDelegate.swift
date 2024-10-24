import UIKit
import Flutter
import GoogleMaps
import Firebase
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, CLLocationManagerDelegate {

  var locationManager: CLLocationManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Firebase configuration
    FirebaseApp.configure()

    // Set UNUserNotificationCenter delegate (without re-declaring it in class conformance)
    if #available(iOS 10.0, *) {
      
  UNUserNotificationCenter.current().delegate = self

  let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
  UNUserNotificationCenter.current().requestAuthorization(
  options: authOptions,
  completionHandler: { _, _ in }
  )

  application.registerForRemoteNotifications()
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }

    // Set Firebase Messaging delegate
    Messaging.messaging().delegate = self

    // Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyBzdajHgG7xEXtoglNS42Jbh8NdMUj2DXk")
    GeneratedPluginRegistrant.register(with: self)

    // Location Manager setup
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.requestWhenInUseAuthorization()
    locationManager?.startUpdatingLocation()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Override these methods to handle APNs registration
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }

  // Add 'override' here for didFailToRegisterForRemoteNotificationsWithError
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  // Firebase Messaging delegate method to receive FCM token
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase FCM token: \(String(describing: fcmToken))")
    // You can send the FCM token to your server here if needed
  }

  // UNUserNotificationCenter delegate method to handle notifications in foreground
  @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Show notification while the app is in the foreground
    completionHandler([.alert, .badge, .sound])
  }

  // UNUserNotificationCenter delegate method to handle notification response when tapped
  @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  // CLLocationManager delegate method
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