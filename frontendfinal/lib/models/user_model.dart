class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isPremium;
  final String paymentStatus;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'user',
    this.isPremium = false,
    this.paymentStatus = 'free_tier',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'user',
      isPremium: json['isPremium'] ?? json['is_premium'] ?? false,
      paymentStatus: json['paymentStatus'] ?? json['payment_status'] ?? 'free_tier',
    );
  }
}