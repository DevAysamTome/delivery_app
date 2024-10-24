import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مركز الدعم والمساعدة'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'مرحبًا بك في مركز الدعم والمساعدة!',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'هنا يمكنك العثور على إجابات للأسئلة الشائعة أو التواصل مع فريق الدعم الفني.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Text('اتصل بالدعم'),
              SizedBox(height: 10),
              Text('+972597516129 | +970598864153')
            ],
          ),
        ),
      ),
    );
  }
}
