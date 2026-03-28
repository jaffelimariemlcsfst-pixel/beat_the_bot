import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_progress.dart';
import 'dart:io';

class SupabaseService {
  static const String _supabaseUrl = 'https://yftqbbrocytsggrmuyjj.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmdHFiYnJvY3l0c2dncm11eWpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjYwNzUsImV4cCI6MjA5MDA0MjA3NX0.95DFA5l1tQlz_HLECdPyq-6jYRBA8fl-oDHVl_6NF9Q';

  static const _kToken = 'sb_access_token';
  static const _kUserId = 'sb_user_id';
  static const _kRefresh = 'sb_refresh_token';

  String? _accessToken;
  String? _userId;
  String? _refreshToken;

  String? get userId => _userId;
  bool get isLoggedIn => _accessToken != null && _userId != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer ${_accessToken ?? _anonKey}',
      };

  // ─── SESSION PERSISTENCE ─────────────────────────────────────────────────

  /// Restores saved session from shared_preferences on app start.
  /// Returns true if a session was found.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final uid = prefs.getString(_kUserId);
    final refresh = prefs.getString(_kRefresh); // ADD THIS
    if (token != null && uid != null) {
      _accessToken = token;
     _userId = uid;
     _refreshToken = refresh; // ADD THIS
     return true;
    }
    return false;
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null && _userId != null) {
      await prefs.setString(_kToken, _accessToken!);
      await prefs.setString(_kUserId, _userId!);
      if (_refreshToken != null) {
        await prefs.setString(_kRefresh, _refreshToken!); // ADD THIS
      }
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kRefresh); // ADD THIS
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────

  Future<void> signUp(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/auth/v1/signup'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['msg'] ?? data['message'] ?? 'Sign up failed');
    }

    _accessToken = data['access_token'];
    _userId = data['user']?['id'];
    _refreshToken = data['refresh_token']; // ADD THIS LINE IN BOTH
    await _persistSession();
  }

  Future<void> signIn(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=password'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
          data['error_description'] ?? data['msg'] ?? 'Sign in failed');
    }

    _accessToken = data['access_token'];
    _userId = data['user']?['id'];
    _refreshToken = data['refresh_token']; // ADD THIS LINE IN BOTH
    await _persistSession();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _userId = null;
    await _clearSession();
  }
  Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      _userId = data['user']?['id'] ?? _userId;
      await _persistSession();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── PROFILE ─────────────────────────────────────────────────────────────

  Future<String?> getUsername() async {
    if (_userId == null) return null;

    final response = await http.get(
      Uri.parse(
          '$_supabaseUrl/rest/v1/profiles?id=eq.$_userId&select=username&limit=1'),
      headers: _headers,
    );

    if (response.statusCode >= 400) return null;
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return null;
    return rows.first['username'] as String?;
  }

  Future<void> updateUsername(String username) async {
    if (_userId == null) throw Exception('Not authenticated');

    final response = await http.patch(
      Uri.parse('$_supabaseUrl/rest/v1/profiles?id=eq.$_userId'),
      headers: {
        ..._headers,
        'Prefer': 'return=minimal',
      },
      body: jsonEncode({'username': username}),
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to update username: ${response.body}');
    }
  }

  // ─── AVATAR ──────────────────────────────────────────────────────────────

  Future<String> uploadAvatar(File imageFile) async {
    if (_userId == null) throw Exception('Not authenticated');

    final path = '$_userId/$_userId.jpg';
    final uploadUrl = '$_supabaseUrl/storage/v1/object/avatars/$path';
    final bytes = await imageFile.readAsBytes();

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.headers.addAll({
      'Authorization': 'Bearer ${_accessToken ?? _anonKey}',
      'x-upsert': 'true',
    });
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: '$_userId.jpg',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Avatar upload failed: ${response.body}');
    }

    return getAvatarUrl();
  }

  String getAvatarUrl() {
    if (_userId == null) throw Exception('Not authenticated');
    final path = '$_userId/$_userId.jpg';
    return '$_supabaseUrl/storage/v1/object/public/avatars/$path';
  }

  // ─── PROGRESS ────────────────────────────────────────────────────────────

  Future<void> saveProgress(String userId, UserProgress progress) async {
    final body = jsonEncode({
      'user_id': userId,
      'level': progress.level,
      'xp': progress.xp,
      'high_score': progress.highScore ?? 0,
      'unlocked_topics': progress.unlockedTopics,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/user_progress?on_conflict=user_id'),
      headers: {
        ..._headers,
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: body,
    );

    if (response.statusCode >= 400) {
      throw Exception('Supabase save error ${response.statusCode}');
    }
  }

  Future<UserProgress?> loadProgress(String userId) async {
    final response = await http.get(
      Uri.parse(
          '$_supabaseUrl/rest/v1/user_progress?user_id=eq.$userId&limit=1'),
      headers: _headers,
    );

    if (response.statusCode >= 400) return null;

    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return null;

    final row = rows.first as Map<String, dynamic>;
    return UserProgress(
      level: row['level'] ?? 1,
      xp: row['xp'] ?? 0,
      highScore: row['high_score'] ?? 0,
      unlockedTopics: List<String>.from(row['unlocked_topics'] ?? []),
    );
  }
}