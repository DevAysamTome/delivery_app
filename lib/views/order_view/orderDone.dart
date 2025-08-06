import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:delivery_app/controller/order_controller.dart';
import 'package:delivery_app/models/order.dart';
import 'package:delivery_app/services/api_service.dart';

class CompleteOrder extends StatefulWidget {
  const CompleteOrder({super.key});

  @override
  _CompleteOrderState createState() => _CompleteOrderState();
}

class _CompleteOrderState extends State<CompleteOrder> {
  String? deliveryWorkerId;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final OrderController _orderController = OrderController();

  @override
  void initState() {
    super.initState();
    _loadDeliveryWorkerId();
  }

  Future<void> _loadDeliveryWorkerId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        deliveryWorkerId = prefs.getString('deliveryWorkerId');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تحميل البيانات')),
        );
      }
    }
  }

  Future<void> _refreshOrders() async {
    setState(() {});
    return Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    if (deliveryWorkerId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات المكتملة'),
        actions: [
          // Debug button
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              try {
                await ApiService.debugNearbyOrders(
                  latitude: 31.9539,
                  longitude: 35.9106,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debug info printed to console')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Debug error: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshOrders,
        child: StreamBuilder<List<Order>>(
          stream: _orderController.getCompletedOrders(),
          builder: (context, AsyncSnapshot<List<Order>> snapshot) {
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

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات تم توصيلها',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              );
            }

            // Sort orders by completion date in descending order
            orders.sort((a, b) {
              final dateA = a.updatedAt ?? DateTime(0);
              final dateB = b.updatedAt ?? DateTime(0);
              return dateB.compareTo(dateA);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderCard(order);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'رقم الطلب: ${order.orderId}',
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Text(
                    'تم التوصيل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            FutureBuilder<String>(
              future: _orderController.getCustomerName(order.userId),
              builder: (context, snapshot) {
                return Text(
                  'اسم العميل: ${snapshot.data ?? 'جاري التحميل...'}',
                  style: const TextStyle(fontSize: 14.0),
                );
              },
            ),
            const SizedBox(height: 8.0),
            Text(
              'العنوان: ${order.deliveryAddress ?? 'غير متوفر'}',
              style: const TextStyle(fontSize: 14.0),
            ),
            const SizedBox(height: 8.0),
            Text(
              'التكلفة الإجمالية: ${order.totalPrice.toStringAsFixed(2)} شيكل',
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (order.updatedAt != null) ...[
              const SizedBox(height: 8.0),
              Text(
                'تاريخ التوصيل: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(order.updatedAt!)}',
                style: const TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
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
                  icon: const Icon(Icons.info_outline),
                  label: const Text('عرض التفاصيل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
