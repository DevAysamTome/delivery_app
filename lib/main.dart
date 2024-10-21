import 'dart:io';

import 'package:delivery_app/res/components/notification_handler.dart';
import 'package:delivery_app/views/home/home_screen.dart';
import 'package:delivery_app/views/login_views/login_view.dart';
import 'package:delivery_app/views/profile/profile_screen.dart';
import 'package:delivery_app/views/weclome_screen/welcome_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// Future<void> _requestNotificationPermissions() async {
//   FirebaseMessaging messaging = FirebaseMessaging.instance;

//   // Request permission for notifications
//   NotificationSettings settings = await messaging.requestPermission(
//     alert: true,
//     badge: true,
//     sound: true,
//   );

//   if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//     print('User granted permission');
//   } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
//     print('User granted provisional permission');
//   } else {
//     print('User declined or has not accepted permission');
//   }
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  if (Platform.isIOS) {
    String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

    if (apnsToken != null) {
      // تم الحصول على رمز APNs في المحاولة الأولى
      print("APNs Token: $apnsToken");
    } else {
      // إذا لم يتم الحصول على الرمز، انتظر لمدة 3 ثوانٍ ثم حاول مرة أخرى
      await Future<void>.delayed(const Duration(seconds: 5));

      apnsToken = await FirebaseMessaging.instance.getAPNSToken();

      if (apnsToken != null) {
        // تم الحصول على الرمز بعد المحاولة الثانية
        print("APNs Token after retry: $apnsToken");
      } else {
        // إذا لم يتم الحصول على الرمز بعد المحاولة الثانية
        print("Failed to retrieve APNs token after second attempt.");
      }
    }
  } else {
    print("This platform does not support APNs.");
  }
  // Get FCM and APNs token (if applicable)
  // Run the app
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final NotificationHandler _notificationHandler = NotificationHandler();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery App',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Elmassry'),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => SettingsScreen(),
      },
    );
  }
}
