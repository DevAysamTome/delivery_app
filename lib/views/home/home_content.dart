import 'package:delivery_app/controller/order_controller.dart';
import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:flutter/material.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = OrderController();

    return Column(
      children: [
        // قسم الإحصائيات
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildStatisticCard(
                    'الطلبات الجديدة', orderController.getNewOrdersCount()),
              ),
              Expanded(
                child: _buildStatisticCard('الطلبات الجارية',
                    orderController.getInProgressOrdersCount()),
              ),
            ],
          ),
        ),
        // قسم الطلبات الحديثة
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الطلبات الحديثة',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildOrdersList(),
        ),
      ],
    );
  }

  Widget _buildStatisticCard(String title, Stream<int> countStream) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard(title, 'جاري التحميل...');
        } else if (snapshot.hasError) {
          return _buildCard(title, 'خطأ');
        } else if (!snapshot.hasData) {
          return _buildCard(title, '0');
        } else {
          return _buildCard(title, snapshot.data.toString());
        }
      },
    );
  }

  Widget _buildCard(String title, String value) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    final OrderController orderController = OrderController();

    return StreamBuilder<Map<String, dynamic>>(
      stream: orderController.getOrdersDetailsWithMainFields(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print(snapshot.error);
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد طلبات متاحة'));
        }

        final mainOrder = snapshot.data!['mainOrder'];
        final storeOrders = snapshot.data!['storeOrders'] as List;

        // تصفية الطلبات المكتملة فقط
        final completedStoreOrders = storeOrders.where((storeOrder) {
          return mainOrder['orderStatus'] == 'مكتمل'; // التحقق من حالة الطلب
        }).toList();

        if (completedStoreOrders.isEmpty) {
          return const Center(child: Text('لا توجد طلبات مكتملة'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: completedStoreOrders.length,
          itemBuilder: (context, index) {
            final storeOrder = completedStoreOrders[index];
            final userId = mainOrder['userId'];

            return FutureBuilder<String>(
              future: orderController.getCustomerName(userId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildOrderCard(
                    'جاري التحميل...',
                    'العنوان: ${storeOrder['items'][0]['placeName']} ',
                    Colors.grey,
                  );
                }

                if (userSnapshot.hasError || !userSnapshot.hasData) {
                  return _buildOrderCard(
                    'خطأ في جلب اسم العميل',
                    'العنوان: ${storeOrder['items'][0]['placeName'] ?? 'غير متوفر'}',
                    Colors.redAccent,
                  );
                }

                final customerName = userSnapshot.data ?? 'غير معروف';

                return _buildOrderCard(
                  customerName,
                  'العنوان: ${storeOrder['items'][0]['placeName']}',
                  Colors.white,
                  onAccept: () async {
                    await orderController.acceptOrder(
                        mainOrder['orderId'], userId);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsScreen(
                          orderId: mainOrder['orderId'],
                          userId: userId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(
    String customerName,
    String address,
    Color cardColor, {
    VoidCallback? onAccept,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          child: Icon(Icons.delivery_dining, color: Colors.white),
        ),
        title: Text(
          customerName,
          style: const TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          address,
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: onAccept != null
            ? IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: onAccept,
              )
            : null,
      ),
    );
  }
}
