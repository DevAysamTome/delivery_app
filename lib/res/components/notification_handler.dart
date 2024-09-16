import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHandler {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationHandler() {
    // إعدادات iOS الحديثة
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    // إعدادات Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // جمع إعدادات المنصتين
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // تهيئة إعدادات الإشعارات
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // طلب إذن للإشعارات من Firebase
    _firebaseMessaging.requestPermission();

    // الاستماع إلى رسائل Firebase
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(message.notification!.title, message.notification!.body);
    });
  }

  // دالة لإظهار الإشعارات
  void showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sarie_channel_id',
      'Sarie Order Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }
}
