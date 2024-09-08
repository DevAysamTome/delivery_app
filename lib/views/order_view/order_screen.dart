import 'package:delivery_app/views/order_view/orderComplete.dart';
import 'package:delivery_app/views/order_view/orderDone.dart';
import 'package:delivery_app/views/order_view/orderOngoing.dart';
import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            // إضافة TabBar في الجزء العلوي من الجسم
            const TabBar(
              tabs: [
                Tab(text: 'الطلبات قيد التنفيذ'),
                Tab(text: 'الطلبات الجارية'),
                Tab(text: 'الطلبات المكتملة'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  PendingOrdersTab(),
                  OngoingOrdersTab(),
                  CompleteOrder()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
