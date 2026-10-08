class NotificationItem {
  final String id;
  final String? realId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime? createdAt;

  NotificationItem({
    required this.id,
    this.realId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.data,
    this.createdAt,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      realId: realId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      data: data,
      createdAt: createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      realId: json['realId']?.toString(),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
