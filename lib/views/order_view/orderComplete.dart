import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delivery_app/services/api_service.dart';
import 'package:delivery_app/models/order.dart';

class PendingOrdersTab extends StatefulWidget {
  const PendingOrdersTab({super.key});

  @override
  _PendingOrdersTabState createState() => _PendingOrdersTabState();
}

class _PendingOrdersTabState extends State<PendingOrdersTab> {
  String? deliveryWorkerId;

  @override
  void initState() {
    super.initState();
    _loadDeliveryWorkerId();
  }

  Future<void> _loadDeliveryWorkerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      deliveryWorkerId = prefs.getString('deliveryWorkerId');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (deliveryWorkerId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Order>>(
      stream: Stream.periodic(const Duration(seconds: 10), (_) async {
        try {
          return await ApiService.getOrdersByStatusAndWorker(
            ['تم اخذ الطلب'],
            deliveryWorkerId!,
          );
        } catch (e) {
          print('Error fetching pending orders: $e');
          return <Order>[];
        }
      }).asyncMap((future) => future),
      builder: (context, AsyncSnapshot<List<Order>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في تحميل البيانات',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        var orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات معلقة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                title: Text(
                  'رقم الطلب: ${order.orderId}',
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الحالة: ${order.orderStatus}'),
                    FutureBuilder<String>(
                      future: ApiService.getCustomerName(order.userId),
                      builder: (context, snapshot) {
                        return Text(
                          'العميل: ${snapshot.data ?? 'جاري التحميل...'}',
                          style: const TextStyle(fontSize: 12.0),
                        );
                      },
                    ),
                  ],
                ),
                trailing: Text(
                  'الإجمالي: ${order.totalPrice.toStringAsFixed(2)} شيكل',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(
                          orderId: order.orderId.toString() ,
                        userId: order.userId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
