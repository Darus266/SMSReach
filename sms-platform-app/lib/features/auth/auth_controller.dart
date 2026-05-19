import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

class AuthController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

  bool get isAuthenticated => api.isAuthenticated;

  /// Clear existing error logs
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Perform authentication login request
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await api.asyncMapPost(ApiConstants.login, {
        'email': email,
        'password': password,
      });

      if (res != null && res['success'] == true) {
        final token = res['data']?['token'] ?? res['token'];
        api.setToken(token);
        
        // Mock user details since we have verified authentic session
        _currentUser = {
          'email': email,
          'companyName': res['data']?['companyName'] ?? 'Ma Super Entreprise',
          'role': res['data']?['role'] ?? 'Administrateur',
        };
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      throw Exception(res['message'] ?? 'Erreur d\'authentification inconnue.');
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Perform register sign-up request
  Future<bool> register(String email, String password, String companyName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await api.asyncMapPost(ApiConstants.register, {
        'email': email,
        'password': password,
        'companyName': companyName,
      });

      if (res != null && res['success'] == true) {
        final token = res['data']?['token'] ?? res['token'];
        api.setToken(token);
        
        _currentUser = {
          'email': email,
          'companyName': companyName,
          'role': 'Administrateur',
        };

        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw Exception(res['message'] ?? 'Erreur d\'inscription.');
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Reset session and wipe out authentication credentials
  void logout() {
    api.setToken(null);
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
