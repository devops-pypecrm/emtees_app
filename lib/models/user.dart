class AppUser {
  final String id;
  final String name;
  final String role;
  final String? phone;
  final String? unionId;
  final String? email;
  final bool mustChangePassword;
  final String? username;
  final String? status;
  final String? notificationsPausedUntil;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    this.unionId,
    this.email,
    this.mustChangePassword = false,
    this.username,
    this.status,
    this.notificationsPausedUntil,
  });

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
  bool get isStaff =>
      role == 'admin' || role == 'academic_head' || role == 'super_admin';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      phone: json['phone'] as String?,
      unionId: json['unionId'] as String?,
      email: json['email'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      username: json['username'] as String?,
      status: json['status'] as String?,
      notificationsPausedUntil: json['notificationsPausedUntil'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'phone': phone,
        'unionId': unionId,
        'email': email,
        'mustChangePassword': mustChangePassword,
        'username': username,
        'status': status,
        'notificationsPausedUntil': notificationsPausedUntil,
      };
}
