class DeliveryPerson {
  final String? id; // MongoDB _id
  final String userId; // Firebase Auth UID or custom user ID
  final String fullName; // Changed from name to fullName
  final String email; // Added email field
  final String phoneNumber; // Added phoneNumber field
  final bool isAvailable;
  final String? currentOrderId;
  final double? latitude;
  final double? longitude;
  final String? fcmToken;
  final String status; // 'متاح' or 'غير متاح'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryPerson({
    this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.isAvailable,
    this.currentOrderId,
    this.latitude,
    this.longitude,
    this.fcmToken,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'isAvailable': isAvailable,
      if (currentOrderId != null) 'currentOrderId': currentOrderId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory DeliveryPerson.fromJson(Map<String, dynamic> json) {
    return DeliveryPerson(
      id: json['_id'],
      userId: json['userId'] ?? json['_id'] ?? '', // Support both userId and _id
      fullName: json['fullName'] ?? json['name'] ?? '', // Support both fullName and name
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      currentOrderId: json['currentOrderId'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      fcmToken: json['fcmToken'],
      status: json['status'] ?? 'غير متاح',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  DeliveryPerson copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    bool? isAvailable,
    String? currentOrderId,
    double? latitude,
    double? longitude,
    String? fcmToken,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryPerson(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isAvailable: isAvailable ?? this.isAvailable,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fcmToken: fcmToken ?? this.fcmToken,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Getters for backward compatibility
  String get name => fullName;
  String get phone => phoneNumber;
} 