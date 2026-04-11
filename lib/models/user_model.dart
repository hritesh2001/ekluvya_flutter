/// Lightweight user model parsed from the auth API response.
class UserModel {
  final String? id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? accessToken;

  const UserModel({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.accessToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>? ?? json;
    return UserModel(
      id: response['id']?.toString(),
      firstName: response['first_name']?.toString(),
      lastName: response['last_name']?.toString(),
      email: response['email']?.toString(),
      phone: response['phone']?.toString(),
      accessToken: response['access_token']?.toString(),
    );
  }
}
