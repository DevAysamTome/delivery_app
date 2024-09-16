import Flutter
import UIKit
import Firebase  // استيراد Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    
    // تهيئة Firebase
    // لقد تمت إزالة دالة طلب إذن التتبع
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
