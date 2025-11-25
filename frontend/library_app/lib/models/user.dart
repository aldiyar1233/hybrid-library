class User {
  final int id;
  final String username;
  final String email;
  final String userType;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    this.phone,
    this.firstName,
    this.lastName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      userType: json['user_type'],
      phone: json['phone'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'user_type': userType,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAdminUser => userType == 'admin';
}