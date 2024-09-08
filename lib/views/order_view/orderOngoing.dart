import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/views/order_details/order_details_screen.dart';
import 'package:flutter/material.dart';

class OngoingOrdersTab extends StatelessWidget {
  const OngoingOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('orderStatus', isEqualTo: 'جاري التوصيل')
          .where('deliveryOption', isEqualTo: 'delivery')
          // فلترة الطلبات الجارية
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var orders = snapshot.data!.docs;
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            var order = orders[index];
            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                title: Text('رقم الطلب: ${order['orderId']}',
                    style: const TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.bold)),
                subtitle: Text('حالة الطلب: ${order['orderStatus']}'),
                trailing: Text('المبلغ الاجمالي: \$${order['totalPrice']}',
                    style: const TextStyle(
                        fontSize: 14.0, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(
                        orderId: order.id,
                        userId: order['userId'],
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
