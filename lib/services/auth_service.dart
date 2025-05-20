import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  // Get Supabase client instance
  final _supabase = Supabase.instance.client;
  
  // User state
  User? _user;
  bool _isLoading = true;
  String? _error;
  
  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Constructor
  AuthService() {
    init();
  }
  
  // Initialize and check for existing session
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Check if we have a saved session
      final session = _supabase.auth.currentSession;
      
      if (session != null) {
        _user = session.user;
      }
      
      // Listen for auth state changes
      _supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        
        switch (event) {
          case AuthChangeEvent.signedIn:
            _user = session?.user;
            break;
          case AuthChangeEvent.signedOut:
            _user = null;
            break;
          case AuthChangeEvent.userUpdated:
            _user = session?.user;
            break;
          default:
            break;
        }
        
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );
      
      _user = response.user;
      
      // Save name to user profile if provided
      if (name != null && _user != null) {
        await _supabase.from('profiles').upsert({
          'id': _user!.id,
          'name': name,
          'email': email,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      _user = response.user;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign in with Google
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.neesh://login-callback/',
      );
      // Auth state listener will update the user state
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _supabase.auth.signOut();
      _user = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update user profile
  Future<void> updateProfile({
    required String name,
    String? avatarUrl,
  }) async {
    if (_user == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _supabase.from('profiles').upsert({
        'id': _user!.id,
        'name': name,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_user == null) return null;
    
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();
      
      return response;
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
}
