const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.handleDeliveryTimer = functions.firestore
    .document('delivery_timers/{timerId}')
    .onCreate(async (snap, context) => {
        const timerData = snap.data();
        const orderId = timerData.orderId;
        const scheduledTime = timerData.scheduledTime.toDate();

        // Calculate delay until the scheduled time
        const now = new Date();
        const delay = scheduledTime.getTime() - now.getTime();

        // If the scheduled time is in the future, set a timeout
        if (delay > 0) {
            await new Promise(resolve => setTimeout(resolve, delay));
        }

        // Update the order status
        try {
            await admin.firestore().collection('orders').doc(orderId).update({
                'orderStatus': 'جاري التوصيل',
                'deliveryStartedAt': admin.firestore.Timestamp.now()
            });

            // Delete the timer document
            await snap.ref.delete();

            return null;
        } catch (error) {
            console.error('Error updating order status:', error);
            throw error;
        }
    }); 