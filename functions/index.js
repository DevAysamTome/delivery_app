const functions = require('firebase-functions');
const admin = require('firebase-admin');
const geofire = require('geofire-common'); // استخدم مكتبة GeoFire لحساب المسافات
admin.initializeApp();

exports.sendNotificationWhenOrderReady = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    const orderId = context.params.orderId;

    try {
      // تحقق مما إذا كانت حالة الطلبات الفرعية جميعها مكتملة
      const orderItemsSnapshot = await admin.firestore().collection('orders').doc(orderId).collection('storeOrders').get();
      const allItemsCompleted = orderItemsSnapshot.docs.every(doc => doc.data().orderStatus === 'مكتمل');

      if (allItemsCompleted && before.orderStatus !== 'مكتمل' && after.orderStatus !== 'مكتمل') {
        console.log('All items are completed. Updating main order status to completed.');

        // تحديث حالة الطلب الرئيسي إلى مكتمل
        await admin.firestore().collection('orders').doc(orderId).update({ orderStatus: 'مكتمل' });

        const customerLocation = { latitude: after.latitude, longitude: after.longitude };

        // الحصول على عمال التوصيل مع معلومات الموقع
        const deliveryWorkersSnapshot = await admin.firestore().collection('deliveryWorkers').get();
        const deliveryWorkers = deliveryWorkersSnapshot.docs.map(doc => ({
          ...doc.data(),
          id: doc.id,
          distance: geofire.distanceBetween(
            [customerLocation.latitude, customerLocation.longitude],
            [doc.data().latitude, doc.data().longitude]
          )
        }));

        // إيجاد أقرب عامل توصيل
        const nearestWorker = deliveryWorkers.reduce((prev, curr) => prev.distance < curr.distance ? prev : curr);

        if (!nearestWorker || !nearestWorker.fcmToken) {
          console.log('No delivery workers found or no tokens available.');
          return null;
        }

        const payload = {
          notification: {
            title: 'SARIE APP',
            body: 'لديك طلب جديد بالقرب منك!',
          },
        };

        // إرسال إشعار إلى أقرب عامل توصيل
        const response = await admin.messaging().sendToCondition(nearestWorker.fcmToken, payload);
        console.log('Successfully sent message to nearest worker:', response);
        return null;
      } else {
        return null;
      }
    } catch (error) {
      console.error('Error processing function:', error);
      throw new functions.https.HttpsError('unknown', 'An error occurred while processing the function', error);
    }
  });
