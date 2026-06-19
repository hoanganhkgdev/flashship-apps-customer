class OrderModel {
  final int id;
  final String code;
  final String serviceType;
  final String status;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupPhone;
  final String? senderName;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? deliveryPhone;
  final String? receiverName;
  final String? orderNote;
  final String? storeName;
  final String? pickupPlaceName;
  final String paymentMethod;
  final int? codAmount;
  final double? distanceKm;
  final num shippingFee;
  final int discountAmount;
  final int nightSurcharge;
  final String? voucherCode;
  final int? driverRating;
  final int? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverAvatarUrl;
  final double? driverLat;
  final double? driverLng;
  final String createdAt;
  final String? cancelReason;

  const OrderModel({
    required this.id,
    required this.code,
    required this.serviceType,
    required this.status,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.pickupPhone,
    this.senderName,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryPhone,
    this.receiverName,
    this.orderNote,
    this.storeName,
    this.pickupPlaceName,
    this.paymentMethod = 'prepaid',
    this.codAmount,
    this.distanceKm,
    required this.shippingFee,
    this.discountAmount = 0,
    this.nightSurcharge = 0,
    this.voucherCode,
    this.driverRating,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverAvatarUrl,
    this.driverLat,
    this.driverLng,
    required this.createdAt,
    this.cancelReason,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
    id: j['id'] as int,
    code: j['code'] as String? ?? '',
    serviceType: j['service_type'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    pickupAddress: j['pickup_address'] as String?,
    pickupLat: j['pickup_lat'] != null ? double.tryParse(j['pickup_lat'].toString()) : null,
    pickupLng: j['pickup_lng'] != null ? double.tryParse(j['pickup_lng'].toString()) : null,
    pickupPhone: j['pickup_phone'] as String?,
    senderName: j['sender_name'] as String?,
    deliveryAddress: j['delivery_address'] as String?,
    deliveryLat: j['delivery_lat'] != null ? double.tryParse(j['delivery_lat'].toString()) : null,
    deliveryLng: j['delivery_lng'] != null ? double.tryParse(j['delivery_lng'].toString()) : null,
    deliveryPhone: j['delivery_phone'] as String?,
    receiverName: j['receiver_name'] as String?,
    orderNote: j['order_note'] as String?,
    storeName: j['store_name'] as String?,
    pickupPlaceName: j['pickup_place_name'] as String?,
    paymentMethod: j['payment_method'] as String? ?? 'prepaid',
    codAmount: (j['cod_amount'] as num?)?.toInt(),
    distanceKm: j['distance_km'] != null ? double.tryParse(j['distance_km'].toString()) : null,
    shippingFee:    j['shipping_fee'] as num? ?? 0,
    discountAmount: (j['discount_amount'] as num?)?.toInt() ?? 0,
    nightSurcharge: (j['night_surcharge'] as num?)?.toInt() ?? 0,
    voucherCode:    j['voucher_code'] as String?,
    driverRating:   j['driver_rating'] as int?,
    driverId:   (j['driver'] as Map?)?['id'] as int?,
    driverName: (j['driver'] as Map?)?.containsKey('name') == true
        ? j['driver']['name'] as String?
        : null,
    driverPhone: (j['driver'] as Map?)?.containsKey('phone') == true
        ? j['driver']['phone'] as String?
        : null,
    driverAvatarUrl: (j['driver'] as Map?)?['avatar_url'] as String?,
    driverLat: (j['driver'] as Map?)?['latitude'] != null
        ? double.tryParse(j['driver']['latitude'].toString())
        : null,
    driverLng: (j['driver'] as Map?)?['longitude'] != null
        ? double.tryParse(j['driver']['longitude'].toString())
        : null,
    createdAt: j['created_at'] as String? ?? '',
    cancelReason: j['cancel_reason'] as String?,
  );

  bool get isActive => ['pending', 'assigned', 'processing'].contains(status);
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get canCancel => status == 'pending';
  bool get canRate => isCompleted && driverRating == null && driverName != null;
  bool get isCod => paymentMethod == 'cod';

  OrderModel copyWith({String? status}) => OrderModel(
    id: id, code: code, serviceType: serviceType,
    status: status ?? this.status,
    pickupAddress: pickupAddress, pickupLat: pickupLat, pickupLng: pickupLng,
    pickupPhone: pickupPhone, senderName: senderName,
    deliveryAddress: deliveryAddress, deliveryLat: deliveryLat, deliveryLng: deliveryLng,
    deliveryPhone: deliveryPhone, receiverName: receiverName,
    orderNote: orderNote, storeName: storeName, pickupPlaceName: pickupPlaceName,
    paymentMethod: paymentMethod, codAmount: codAmount, distanceKm: distanceKm,
    shippingFee: shippingFee, discountAmount: discountAmount,
    nightSurcharge: nightSurcharge, voucherCode: voucherCode,
    driverRating: driverRating, driverId: driverId,
    driverName: driverName, driverPhone: driverPhone, driverAvatarUrl: driverAvatarUrl,
    driverLat: driverLat, driverLng: driverLng,
    createdAt: createdAt, cancelReason: cancelReason,
  );

  OrderModel withDriverLocation(double lat, double lng) => OrderModel(
    id: id, code: code, serviceType: serviceType, status: status,
    pickupAddress: pickupAddress, pickupLat: pickupLat, pickupLng: pickupLng,
    pickupPhone: pickupPhone, senderName: senderName,
    deliveryAddress: deliveryAddress, deliveryLat: deliveryLat, deliveryLng: deliveryLng,
    deliveryPhone: deliveryPhone, receiverName: receiverName,
    orderNote: orderNote, storeName: storeName, pickupPlaceName: pickupPlaceName,
    paymentMethod: paymentMethod, codAmount: codAmount, distanceKm: distanceKm,
    shippingFee: shippingFee, discountAmount: discountAmount,
    nightSurcharge: nightSurcharge, voucherCode: voucherCode,
    driverRating: driverRating, driverId: driverId,
    driverName: driverName, driverPhone: driverPhone, driverAvatarUrl: driverAvatarUrl,
    driverLat: lat, driverLng: lng,
    createdAt: createdAt, cancelReason: cancelReason,
  );
}
