# Troubleshooting Order Status Issue

## Problem Summary
The order status is showing as "تم التوصيل" (delivered) but the actual orders have status "قيد الانتظار" (pending).

## Immediate Solutions Applied

### **1. Temporary Client-Side Filtering**
Since the backend API hasn't been updated yet to accept the status parameter, I've implemented client-side filtering:

```dart
// In getNearbyOrders method
// TODO: Filter by status when backend supports it
// For now, we'll filter by status on the client side
List<Order> statusFilteredOrders = filteredOrders;
if (status != null) {
  statusFilteredOrders = filteredOrders.where((order) => order.orderStatus == status).toList();
  print('[ApiService] Filtered by status "$status": ${filteredOrders.length} -> ${statusFilteredOrders.length} orders');
}
```

### **2. Fallback for Completed Orders**
For completed orders, I've created a separate method that doesn't use the nearby orders endpoint:

```dart
// Get completed orders (without location filtering)
Stream<List<Order>> getCompletedOrders() {
  return Stream.periodic(const Duration(seconds: 8), (_) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return <Order>[];
      
      // Get all orders and filter by status and worker
      final response = await ApiService.getOrders();
      
      // Filter by status and worker
      final completedOrders = response.where((order) {
        final statusMatch = order.orderStatus == 'تم التوصيل';
        final workerMatch = order.assignedTo == currentUserId;
        return statusMatch && workerMatch;
      }).toList();
      
      return completedOrders;
    } catch (e) {
      print('Error getting completed orders: $e');
      return <Order>[];
    }
  }).asyncMap((future) => future);
}
```

### **3. Debug Method Added**
I've added a debug method to help troubleshoot:

```dart
// Debug method to test nearby orders endpoint
static Future<void> debugNearbyOrders({
  required double latitude,
  required double longitude,
  double radiusInKm = 5.0,
}) async {
  // ... debug implementation
}
```

## How to Debug

### **Step 1: Use the Debug Button**
1. Open the "الطلبات المكتملة" (Completed Orders) screen
2. Tap the bug icon (🐛) in the app bar
3. Check the console output for debug information

### **Step 2: Check Console Output**
Look for these debug messages:
```
[ApiService] DEBUG: Testing nearby orders endpoint
[ApiService] DEBUG: Requesting URL: https://backend-jm4h.onrender.com/api/order/nearby-orders?lat=31.9539&lng=35.9106&radiusInKm=5
[ApiService] DEBUG: Response status: 200
[ApiService] DEBUG: Found X orders from backend
[ApiService] DEBUG: Order 0 - ID: 123, Status: قيد الانتظار, AssignedTo: worker123
```

### **Step 3: Verify Order Status**
Check if the orders returned from the backend have the correct status:
- **Expected**: Orders with status "تم التوصيل" (delivered)
- **Actual**: Orders with status "قيد الانتظار" (pending)

## Possible Issues and Solutions

### **Issue 1: Backend Returns Wrong Status**
**Problem**: Backend is returning orders with status "قيد الانتظار" instead of "تم التوصيل"

**Solution**: 
1. Check the backend database to see what status the orders actually have
2. Update the backend nearby orders endpoint to accept status parameter
3. Or filter orders by status in the backend

### **Issue 2: Frontend Filtering Not Working**
**Problem**: Client-side filtering is not working correctly

**Solution**:
1. Check the console logs for filtering messages
2. Verify that the status comparison is working
3. Add more debug logging

### **Issue 3: Wrong Orders Being Fetched**
**Problem**: The wrong orders are being fetched from the backend

**Solution**:
1. Check the backend API endpoint
2. Verify the query parameters
3. Check if the backend is filtering correctly

## Testing Steps

### **Test 1: Check Backend Response**
```dart
// Add this to your code temporarily
await ApiService.debugNearbyOrders(
  latitude: 31.9539,
  longitude: 35.9106,
);
```

### **Test 2: Check All Orders**
```dart
// Test getting all orders
final allOrders = await ApiService.getOrders();
print('Total orders: ${allOrders.length}');
for (final order in allOrders) {
  print('Order ${order.orderId}: ${order.orderStatus}');
}
```

### **Test 3: Check Completed Orders**
```dart
// Test completed orders specifically
final completedOrders = await ApiService.getOrdersByStatusAndWorker(
  ['تم التوصيل'],
  'your-worker-id',
);
print('Completed orders: ${completedOrders.length}');
```

## Expected Results

### **If Everything Works:**
- ✅ Debug shows orders with status "تم التوصيل"
- ✅ Completed orders tab shows only delivered orders
- ✅ Order counts are accurate
- ✅ No errors in console

### **If There Are Issues:**
- ❌ Debug shows wrong status
- ❌ Completed orders tab shows pending orders
- ❌ Order counts are wrong
- ❌ Errors in console

## Next Steps

### **Immediate Actions:**
1. **Test the debug button** to see what the backend is returning
2. **Check console output** for any errors or unexpected data
3. **Verify order status** in the backend database

### **If Backend Needs Update:**
1. **Update backend API** to accept status parameter
2. **Test the new API** with status filtering
3. **Remove client-side filtering** once backend is updated

### **If Frontend Needs Fix:**
1. **Check filtering logic** in the Flutter app
2. **Add more debug logging** to track the issue
3. **Test with different order statuses**

## Backend API Update Needed

The backend `/order/nearby-orders` endpoint should be updated to accept a status parameter:

```javascript
router.get('/nearby-orders', async (req, res) => {
  try {
    const { lat, lng, radiusInKm = 5, status = 'قيد الانتظار' } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'Missing latitude or longitude' });
    }

    const center = [parseFloat(lat), parseFloat(lng)];
    const radius = parseFloat(radiusInKm);

    // Use status parameter instead of hardcoded value
    const orders = await Order.find({
      orderStatus: status, // Dynamic status
      'deliveryLocation.latitude': { $exists: true },
      'deliveryLocation.longitude': { $exists: true }
    }).lean();

    // Filter by distance
    const nearby = orders.filter(order => {
      const orderLat = order.deliveryLocation.latitude;
      const orderLng = order.deliveryLocation.longitude;

      const distance = geofire.distanceBetween(center, [orderLat, orderLng]);
      return distance <= radius;
    });

    res.json(nearby);
  } catch (err) {
    res.status(500).json({ error: 'فشل في جلب الطلبات القريبة', details: err.message });
  }
});
```

## Summary

The issue is likely that:
1. **Backend is returning wrong status** - Orders have status "قيد الانتظار" instead of "تم التوصيل"
2. **Backend API needs update** - Should accept status parameter for filtering
3. **Frontend filtering is working** - But filtering the wrong data

**Immediate action**: Use the debug button to see what the backend is actually returning, then we can determine the next steps based on the results. 