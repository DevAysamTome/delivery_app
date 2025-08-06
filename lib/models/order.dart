import 'dart:convert';

class Order {
  final String? id; // MongoDB _id
  final dynamic orderId; // Sequential order number (can be string or int)
  final String orderStatus;
  final String storeId;
  final String userId;
  final double totalPrice;
  final double? deliveryCost;
  final int? deliveryTime;
  final String? deliveryOption;
  final String? paymentOption;
  final DateTime? orderEndTime;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? userLocation;
  final Map<String, dynamic>? restaurantLocation;
  final Map<String, dynamic>? deliveryLocation;
  final String? deliveryAddress;
  final String placeName;
  final List<String> selectedAddOns;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? assignedTo; // Delivery worker ID

  Order({
    this.id,
    required this.orderId,
    required this.orderStatus,
    required this.storeId,
    required this.userId,
    required this.totalPrice,
    this.deliveryCost,
    this.deliveryTime,
    this.deliveryOption,
    this.paymentOption,
    this.orderEndTime,
    required this.items,
    this.userLocation,
    this.restaurantLocation,
    this.deliveryLocation,
    this.deliveryAddress,
    required this.placeName,
    required this.selectedAddOns,
    this.createdAt,
    this.updatedAt,
    this.assignedTo,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'],
      orderId: json['orderId'], // Keep as dynamic (string or int)
      orderStatus: json['orderStatus'] ?? '',
      storeId: json['storeId'] ?? '',
      userId: json['userId'] ?? '',
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      deliveryCost: json['deliveryCost']?.toDouble(),
      deliveryTime: json['deliveryTime'],
      deliveryOption: json['deliveryOption'],
      paymentOption: json['paymentOption'],
      orderEndTime: json['orderEndTime'] != null 
          ? DateTime.parse(json['orderEndTime']) 
          : null,
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      userLocation: json['userLocation'],
      restaurantLocation: json['restaurantLocation'],
      deliveryLocation: json['deliveryLocation'],
      deliveryAddress: json['deliveryAddress'],
      placeName: json['placeName'] ?? '',
      selectedAddOns: List<String>.from(json['selectedAddOns'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      assignedTo: json['assignedTo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'orderId': orderId,
      'orderStatus': orderStatus,
      'storeId': storeId,
      'userId': userId,
      'totalPrice': totalPrice,
      if (deliveryCost != null) 'deliveryCost': deliveryCost,
      if (deliveryTime != null) 'deliveryTime': deliveryTime,
      if (deliveryOption != null) 'deliveryOption': deliveryOption,
      if (paymentOption != null) 'paymentOption': paymentOption,
      if (orderEndTime != null) 'orderEndTime': orderEndTime!.toIso8601String(),
      'items': items,
      if (userLocation != null) 'userLocation': userLocation,
      if (restaurantLocation != null) 'restaurantLocation': restaurantLocation,
      if (deliveryLocation != null) 'deliveryLocation': deliveryLocation,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      'placeName': placeName,
      'selectedAddOns': selectedAddOns,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (assignedTo != null) 'assignedTo': assignedTo,
    };
  }

  Order copyWith({
    String? id,
    dynamic orderId,
    String? orderStatus,
    String? storeId,
    String? userId,
    double? totalPrice,
    double? deliveryCost,
    int? deliveryTime,
    String? deliveryOption,
    String? paymentOption,
    DateTime? orderEndTime,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? userLocation,
    Map<String, dynamic>? restaurantLocation,
    Map<String, dynamic>? deliveryLocation,
    String? deliveryAddress,
    String? placeName,
    List<String>? selectedAddOns,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedTo,
  }) {
    return Order(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderStatus: orderStatus ?? this.orderStatus,
      storeId: storeId ?? this.storeId,
      userId: userId ?? this.userId,
      totalPrice: totalPrice ?? this.totalPrice,
      deliveryCost: deliveryCost ?? this.deliveryCost,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      paymentOption: paymentOption ?? this.paymentOption,
      orderEndTime: orderEndTime ?? this.orderEndTime,
      items: items ?? this.items,
      userLocation: userLocation ?? this.userLocation,
      restaurantLocation: restaurantLocation ?? this.restaurantLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      placeName: placeName ?? this.placeName,
      selectedAddOns: selectedAddOns ?? this.selectedAddOns,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}
