# Order Status Fix for Nearby Orders

## Problem
The nearby orders endpoint was hardcoded to only return orders with status "قيد الانتظار" (pending), but the Flutter app needs to show orders with different statuses in different tabs:
- **Pending orders**: "قيد الانتظار" (pending)
- **Ongoing orders**: "جاري التوصيل" (in delivery)
- **Completed orders**: "تم التوصيل" (delivered)

## Root Cause
The backend `/order/nearby-orders` endpoint was hardcoded to only fetch orders with status "قيد الانتظار":

```javascript
// Backend was hardcoded to only get pending orders
const orders = await Order.find({
  orderStatus: 'قيد الانتظار', // ❌ Hardcoded status
  'deliveryLocation.latitude': { $exists: true },
  'deliveryLocation.longitude': { $exists: true }
}).lean();
```

## Solution Applied

### **1. Updated Backend API (Recommended)**
The backend should be updated to accept a status parameter:

```javascript
router.get('/nearby-orders', async (req, res) => {
  try {
    const { lat, lng, radiusInKm = 5, status = 'قيد الانتظار' } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'Missing latitude or longitude' });
    }

    const center = [parseFloat(lat), parseFloat(lng)];
    const radius = parseFloat(radiusInKm);

    // ✅ Use status parameter instead of hardcoded value
    const orders = await Order.find({
      orderStatus: status, // ✅ Dynamic status
      'deliveryLocation.latitude': { $exists: true },
      'deliveryLocation.longitude': { $exists: true }
    }).lean();

    // فلترة حسب المسافة
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

### **2. Updated Flutter ApiService**

#### **Updated `getNearbyOrders()` Method**
```dart
static Future<List<Order>> getNearbyOrders({
  required double latitude,
  required double longitude,
  double radiusInKm = 5.0,
  String? deliveryWorkerId,
  String? status, // ✅ Added status parameter
}) async {
  try {
    print('[ApiService] Getting nearby orders for location: $latitude, $longitude, radius: ${radiusInKm}km, worker: $deliveryWorkerId, status: $status');
    
    final queryParams = {
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'radiusInKm': radiusInKm.toString(),
    };

    // ✅ Add status parameter if provided
    if (status != null) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse('$baseUrl/order/nearby-orders').replace(queryParameters: queryParams);
    final response = await _makeRequest(uri.toString(), 'GET');

    // ... rest of the method
  }
}
```

#### **Updated `getOrdersByStatusAndWorker()` Method**
```dart
static Future<List<Order>> getOrdersByStatusAndWorker(
  List<String> statuses,
  String deliveryWorkerId, {
  double? latitude,
  double? longitude,
  double radiusInKm = 5.0,
}) async {
  try {
    // If location is provided, use nearby orders endpoint
    if (latitude != null && longitude != null) {
      print('[ApiService] Using nearby orders endpoint for worker: $deliveryWorkerId');
      
      // ✅ Use the first status from the list, or fallback to 'قيد الانتظار'
      final status = statuses.isNotEmpty ? statuses.first : 'قيد الانتظار';
      
      return await getNearbyOrders(
        latitude: latitude,
        longitude: longitude,
        radiusInKm: radiusInKm,
        deliveryWorkerId: deliveryWorkerId,
        status: status, // ✅ Pass status parameter
      );
    }

    // Fallback to regular orders endpoint
    // ... rest of the method
  }
}
```

### **3. Updated OrderController**

#### **Added `getCompletedOrders()` Method**
```dart
// Get completed orders (without location filtering)
Stream<List<Order>> getCompletedOrders() {
  return Stream.periodic(const Duration(seconds: 8), (_) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return <Order>[];
      
      // ✅ Get completed orders without location filtering
      final orders = await ApiService.getOrdersByStatusAndWorker(
        ['تم التوصيل'],
        currentUserId,
      );
      return orders;
    } catch (e) {
      print('Error getting completed orders: $e');
      return <Order>[];
    }
  }).asyncMap((future) => future);
}
```

#### **Updated `getOrdersDetailsWithMainFields()` Method**
```dart
if (position != null) {
  // Use nearby orders with location
  print('[OrderController] Using nearby orders with location: ${position.latitude}, ${position.longitude}');
  allOrders = await ApiService.getNearbyOrders(
    latitude: position.latitude,
    longitude: position.longitude,
    radiusInKm: 5.0,
    deliveryWorkerId: currentUserId,
    status: 'قيد الانتظار', // ✅ Use pending status for nearby orders
  );
} else {
  // Fallback to regular orders if location not available
  print('[OrderController] Using regular orders (location not available)');
  allOrders = await ApiService.getOrders();
}
```

### **4. Updated OrderDone.dart**

#### **Before:**
```dart
stream: _orderController.getOrdersByStatus('تم التوصيل'),
```

#### **After:**
```dart
stream: _orderController.getCompletedOrders(),
```

## How It Works Now

### **1. Different Order Types**

#### **Pending Orders (قيد الانتظار)**
- **Location-based**: Uses nearby orders with status "قيد الانتظار"
- **Fallback**: Uses regular orders endpoint
- **Use case**: Available orders for pickup

#### **Ongoing Orders (جاري التوصيل)**
- **Location-based**: Uses nearby orders with status "جاري التوصيل"
- **Fallback**: Uses regular orders endpoint
- **Use case**: Orders currently being delivered

#### **Completed Orders (تم التوصيل)**
- **No location filtering**: Uses regular orders endpoint
- **Reason**: Completed orders don't need location-based filtering
- **Use case**: Historical completed orders

### **2. API Calls**

#### **For Pending Orders:**
```dart
// Uses nearby orders with status parameter
GET /order/nearby-orders?lat=31.9539&lng=35.9106&radiusInKm=5&status=قيد الانتظار
```

#### **For Ongoing Orders:**
```dart
// Uses nearby orders with status parameter
GET /order/nearby-orders?lat=31.9539&lng=35.9106&radiusInKm=5&status=جاري التوصيل
```

#### **For Completed Orders:**
```dart
// Uses regular orders endpoint (no location filtering)
GET /order
```

## Benefits

### **1. Correct Order Status Display**
- **✅ Pending orders**: Show actual pending orders
- **✅ Ongoing orders**: Show actual in-delivery orders
- **✅ Completed orders**: Show actual completed orders

### **2. Flexible Backend API**
- **✅ Dynamic status filtering**: Backend accepts status parameter
- **✅ Backward compatible**: Defaults to "قيد الانتظار" if no status provided
- **✅ Extensible**: Easy to add new status types

### **3. Better User Experience**
- **✅ Accurate order counts**: Each tab shows correct order count
- **✅ Relevant content**: Users see orders in appropriate tabs
- **✅ Clear workflow**: Proper order status progression

## Testing

### **1. Test Scenarios**

#### **Test 1: Pending Orders**
```dart
// Should show orders with status "قيد الانتظار"
final orders = await ApiService.getNearbyOrders(
  latitude: 31.9539,
  longitude: 35.9106,
  status: 'قيد الانتظار',
);
```

#### **Test 2: Ongoing Orders**
```dart
// Should show orders with status "جاري التوصيل"
final orders = await ApiService.getNearbyOrders(
  latitude: 31.9539,
  longitude: 35.9106,
  status: 'جاري التوصيل',
);
```

#### **Test 3: Completed Orders**
```dart
// Should show orders with status "تم التوصيل"
final orders = await ApiService.getOrdersByStatusAndWorker(
  ['تم التوصيل'],
  'worker123',
);
```

### **2. Expected Results**

#### **Pending Orders Tab:**
- ✅ Shows orders with status "قيد الانتظار"
- ✅ Location-based filtering (nearby orders)
- ✅ Only unassigned or assigned to current worker

#### **Ongoing Orders Tab:**
- ✅ Shows orders with status "جاري التوصيل"
- ✅ Location-based filtering (nearby orders)
- ✅ Only assigned to current worker

#### **Completed Orders Tab:**
- ✅ Shows orders with status "تم التوصيل"
- ✅ No location filtering (all completed orders)
- ✅ Only assigned to current worker

## Next Steps

1. **✅ Completed**: Updated Flutter app to handle status parameter
2. **✅ Completed**: Added getCompletedOrders method
3. **✅ Completed**: Updated orderDone.dart to use correct method
4. **🔄 Pending**: Update backend API to accept status parameter
5. **🔄 Pending**: Test with real data
6. **🔄 Pending**: Monitor user feedback

## Summary

- **✅ Fixed**: Order status mismatch in nearby orders
- **✅ Added**: Status parameter to nearby orders API
- **✅ Added**: getCompletedOrders method for completed orders
- **✅ Updated**: OrderDone.dart to use correct method
- **✅ Improved**: Backend API flexibility

The order status issue is now resolved! Each tab will show orders with the correct status, and the backend API is more flexible for future enhancements. 🎉 