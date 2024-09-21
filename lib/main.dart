import 'package:delivery_app/res/components/notification_handler.dart';
import 'package:delivery_app/views/home/home_screen.dart';
import 'package:delivery_app/views/login_views/login_view.dart';
import 'package:delivery_app/views/profile/profile_screen.dart';
import 'package:delivery_app/views/weclome_screen/welcome_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void getToken() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("Device Token: $token");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  getToken();

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
