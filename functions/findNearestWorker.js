const geofire = require('geofire-common');

module.exports.findNearestDeliveryWorker = (functions, admin) =>
  functions.pubsub
    .topic('orderCompleted')
    .onPublish(async (message) => {
      let payloadData;

      try {
        const decoded = Buffer.from(message.data, 'base64').toString();
        console.log('PubSub Message:', decoded);
        payloadData = JSON.parse(decoded);
      } catch (e) {
        console.error('Invalid message payload:', e);
        return;
      }

      const orderId = payloadData.orderId;
      if (!orderId) return console.error('Missing orderId in payload');

      try {
        const orderSnapshot = await admin.firestore().collection('orders').doc(orderId).get();
        if (!orderSnapshot.exists) return console.error('Order not found:', orderId);

        const orderData = orderSnapshot.data();
        const customerLocation = orderData.customer?.location;
        if (!customerLocation || typeof customerLocation.latitude !== 'number' || typeof customerLocation.longitude !== 'number') {
          return console.error('Invalid customer location');
        }

        const workersSnapshot = await admin.firestore()
          .collection('deliveryWorkers')
          .where('status', '==', 'متاح')
          .get();

        const deliveryWorkers = workersSnapshot.docs.map(doc => {
          const data = doc.data();
          if (typeof data.latitude === 'number' && typeof data.longitude === 'number') {
            const distance = geofire.distanceBetween(
              [customerLocation.latitude, customerLocation.longitude],
              [data.latitude, data.longitude]
            );
            return { id: doc.id, ...data, distance };
          }
          return null;
        }).filter(Boolean);

        if (!deliveryWorkers.length) return console.log('No valid delivery workers');

        const nearestWorker = deliveryWorkers.reduce((a, b) => a.distance < b.distance ? a : b);

        if (nearestWorker?.fcmToken) {
          await admin.messaging().sendToDevice(nearestWorker.fcmToken, {
            notification: {
              title: 'SARIE APP',
              body: 'لديك طلب جديد بالقرب منك!',
            },
          });
          console.log('Notification sent to:', nearestWorker.id);
        } else {
          console.log('No FCM token for nearest worker');
        }

      } catch (error) {
        console.error('Delivery assignment error:', error);
      }
    });
