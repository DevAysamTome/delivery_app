import 'package:delivery_app/views/order_view/orderComplete.dart';
import 'package:delivery_app/views/order_view/orderDone.dart';
import 'package:delivery_app/views/order_view/orderOngoing.dart';
import 'package:flutter/material.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'الطلبات قيد التنفيذ',
            ),
            Tab(
              icon: Icon(Icons.local_shipping),
              text: 'الطلبات الجارية',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'الطلبات المكتملة',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PendingOrdersTab(),
          OngoingOrdersTab(),
          CompleteOrder(),
        ],
      ),
    );
  }
}
