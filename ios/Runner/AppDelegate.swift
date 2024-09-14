import Flutter
import UIKit
import Firebase  // استيراد Firebase
import AppTrackingTransparency
import AdSupport

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // تهيئة Firebase
    FirebaseApp.configure()
    
    // استدعاء دالة طلب إذن التتبع
    requestTrackingPermission()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // دالة لطلب إذن التتبع من المستخدم
  func requestTrackingPermission() {
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
          // المستخدم وافق على التتبع
          self.trackingAuthorized()
        case .denied:
          // المستخدم رفض التتبع
          self.trackingDenied()
        case .restricted:
          // النظام قيد التتبع
          self.trackingRestricted()
        case .notDetermined:
          // المستخدم لم يتخذ قرارًا بعد
          print("Tracking not determined yet")
        @unknown default:
          // حالة افتراضية للتعامل مع الحالات غير المتوقعة
          print("Unknown tracking authorization status")
        }
      }
    } else {
      // التعامل مع الأنظمة الأقدم من iOS 14
      print("Tracking not available on this iOS version")
    }
  }

  // دالة يتم استدعاؤها عند السماح بالتتبع
  func trackingAuthorized() {
    let idfa = ASIdentifierManager.shared().advertisingIdentifier
    print("Tracking authorized. IDFA: \(idfa)")
    // يمكنك إضافة كود بدء التتبع هنا
  }

  // دالة يتم استدعاؤها عند رفض التتبع
  func trackingDenied() {
    print("Tracking denied by the user")
    // يمكنك إضافة كود التعامل مع رفض التتبع هنا
  }

  // دالة يتم استدعاؤها عندما يكون التتبع مقيدًا
  func trackingRestricted() {
    print("Tracking restricted due to system policies")
    // يمكنك إضافة كود التعامل مع قيود التتبع هنا
  }
}
