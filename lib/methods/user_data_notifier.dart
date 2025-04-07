import 'package:flutter/foundation.dart';

class UserDataNotifier extends ValueNotifier<Map<String, String>> {
  UserDataNotifier() : super({'name': '', 'photoUrl': ''});

  void updateUserData(String name, String photoUrl) {
    value = {'name': name, 'photoUrl': photoUrl};
    notifyListeners();
  }
}

// Instance globale accessible dans toute l'application
final userDataNotifier = UserDataNotifier();
