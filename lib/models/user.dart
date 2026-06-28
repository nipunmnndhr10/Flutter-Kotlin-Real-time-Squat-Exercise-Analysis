class User {
  final int userId;
  final String name;
  final String email;
  final String? token;

  User({
    required this.userId,
    required this.name,
    required this.email,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] ?? json['user_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'token': token,
    };
  }
}