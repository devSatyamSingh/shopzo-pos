import 'user_model.dart';

class LoginResponseModel {
  const LoginResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final dynamic userJson = json['user'];
    final dynamic access = json['accessToken'];
    final dynamic refresh = json['refreshToken'];

    if (userJson is! Map) {
      throw const FormatException('Login response: "user" missing');
    }
    if (access is! String || access.isEmpty) {
      throw const FormatException('Login response: "accessToken" missing');
    }
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('Login response: "refreshToken" missing');
    }

    return LoginResponseModel(
      user: UserModel.fromJson(Map<String, dynamic>.from(userJson)),
      accessToken: access,
      refreshToken: refresh,
    );
  }
}
