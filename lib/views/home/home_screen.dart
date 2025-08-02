import 'package:delivery_app/controller/order_controller.dart';
import 'package:delivery_app/views/home/home_content.dart';
import 'package:delivery_app/views/order_view/order_screen.dart';
import 'package:delivery_app/views/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app/res/constants/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OrderController _orderController = OrderController();
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(), // قم بإنشاء HomeContent للشاشة الرئيسية
    const OrdersScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.orders, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_shipping),
            label: AppStrings.orders,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: AppStrings.settings,
          ),
        ],
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
