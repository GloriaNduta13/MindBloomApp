import 'package:flutter/foundation.dart';

class SmsCredentialsProvider extends ChangeNotifier {
  String? _apiKey;
  String? _username;
  String? _senderId;

  String? get apiKey => _apiKey;
  String? get username => _username;
  String? get senderId => _senderId;

  void setCredentials({
    required String? apiKey,
    required String? username,
    required String? senderId,
  }) {
    _apiKey = apiKey;
    _username = username;
    _senderId = senderId;
    notifyListeners();
  }

  void clearCredentials() {
    _apiKey = null;
    _username = null;
    _senderId = null;
    notifyListeners();
  }
}