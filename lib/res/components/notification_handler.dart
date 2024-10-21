import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHandler {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationHandler() {
    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Combine platform settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Initialize notification settings
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request notification permissions from Firebase
    _firebaseMessaging
        .requestPermission()
        .then((NotificationSettings settings) {
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission for notifications');
      } else {
        print('User declined or has not accepted notification permission');
      }
    });

    // Get the APNs token for iOS
    _firebaseMessaging.getAPNSToken().then((String? apnsToken) {
      if (apnsToken != null) {
        print('APNs Token: $apnsToken');
        // You can now use this token to send it to your backend or Firebase server
      } else {
        print('Failed to retrieve APNs token');
      }
    });

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(message.notification!.title, message.notification!.body);
    });
  }

  // Function to show local notifications
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
      title ?? 'No Title',
      body ?? 'No Body',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }
}
