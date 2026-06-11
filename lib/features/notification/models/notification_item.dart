class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String? orderCode;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.orderCode,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        orderCode: orderCode,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'order_code': orderCode,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'].toString(), // server returns int, local uses string
        title: json['title'] as String,
        body: json['body'] as String,
        orderCode: json['order_code'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] == true || json['is_read'] == 1,
      );
}
