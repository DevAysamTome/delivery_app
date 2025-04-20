const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { PubSub } = require('@google-cloud/pubsub');

admin.initializeApp();
const pubsub = new PubSub();

exports.checkStoreOrdersStatus = functions.firestore
  .document('orders/{orderId}/storeOrders/{storeOrderId}')
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const storeOrderId = context.params.storeOrderId;

    const beforeStatus = change.before.data().orderStatus;
    const afterStatus = change.after.data().orderStatus;

    if (beforeStatus === afterStatus) {
      console.log(`No status change in storeOrder ${storeOrderId}`);
      return null;
    }

    console.log(`Detected change in storeOrder ${storeOrderId}. Checking all storeOrders...`);

    const orderRef = admin.firestore().collection('orders').doc(orderId);
    const storeOrdersRef = orderRef.collection('storeOrders');

    const snapshot = await storeOrdersRef.get();
    if (snapshot.empty) {
      console.log('No storeOrders found.');
      return null;
    }

    const allReady = snapshot.docs.every(doc =>
      doc.data().orderStatus?.trim() === 'تم تجهيز الطلب'
    );

    if (!allReady) {
      console.log('Not all storeOrders are ready.');
      return null;
    }

    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
      console.log(`Order ${orderId} not found.`);
      return null;
    }

    const mainOrderStatus = orderDoc.data().orderStatus;
    if (mainOrderStatus === 'تم تجهيز الطلب') {
      console.log('Main order already marked as ready.');
      return null;
    }

    await orderRef.update({ orderStatus: 'تم تجهيز الطلب' });
    console.log(`Main order ${orderId} marked as ready.`);

    // Optional: publish to pubsub
    try {
      const message = JSON.stringify({ orderId });
      await pubsub.topic('orderCompleted').publish(Buffer.from(message));
      console.log('Published to orderCompleted topic:', message);
    } catch (err) {
      console.error('PubSub error:', err);
    }

    return null;
  });
