const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Function to handle the initial timer creation
exports.handleDeliveryTimer = functions.firestore
    .document('delivery_timers/{timerId}')
    .onCreate(async (snap, context) => {
        const timerData = snap.data();
        const orderId = timerData.orderId;
        const scheduledTime = timerData.scheduledTime.toDate();

        // Schedule the status update
        await admin.firestore().collection('scheduled_updates').doc(orderId).set({
            'orderId': orderId,
            'scheduledTime': scheduledTime,
            'status': 'pending'
        });

        return null;
    });

// Function to check and process scheduled updates
exports.processScheduledUpdates = functions.pubsub
    .schedule('every 1 minutes')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        
        // Get all pending updates that are due
        const updates = await admin.firestore()
            .collection('scheduled_updates')
            .where('status', '==', 'pending')
            .where('scheduledTime', '<=', now)
            .get();

        // Process each update
        const batch = admin.firestore().batch();
        
        for (const doc of updates.docs) {
            const data = doc.data();
            const orderId = data.orderId;

            // Update the order status
            const orderRef = admin.firestore().collection('orders').doc(orderId);
            batch.update(orderRef, {
                'orderStatus': 'جاري التوصيل',
                'deliveryStartedAt': now
            });

            // Mark the scheduled update as completed
            batch.update(doc.ref, {
                'status': 'completed',
                'processedAt': now
            });
        }

        // Commit all updates
        await batch.commit();
        
        return null;
    }); 