import 'package:delivery_app/views/login_views/login_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileSection(),
          _buildGeneralSettingsSection(),
          _buildHelpSection(),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.redAccent),
        title: const Text('حساب المستخدم'),
        subtitle: const Text('تعديل معلومات الحساب'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Navigate to user profile screen
        },
      ),
    );
  }

  Widget _buildGeneralSettingsSection() {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.language, color: Colors.redAccent),
            title: const Text('اللغة'),
            subtitle: const Text('تغيير لغة التطبيق'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to language settings screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications, color: Colors.redAccent),
            title: const Text('الإشعارات'),
            subtitle: const Text('إعدادات الإشعارات'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to notifications settings screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.redAccent),
            title: const Text('الأمان'),
            subtitle: const Text('تغيير كلمة المرور'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to security settings screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: const Icon(Icons.help, color: Colors.redAccent),
        title: const Text('مساعدة'),
        subtitle: const Text('مركز الدعم والمساعدة'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Navigate to help screen
        },
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    Future<void> logout() async {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } catch (e) {
        print('Logout Error: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: ElevatedButton(
        onPressed: () async {
          // Handle logout logic here
          await logout();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل الخروج بنجاح')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 14.0),
        ),
        child: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}
