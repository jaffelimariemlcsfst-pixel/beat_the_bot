import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final provider = context.read<UserProvider>();
      if (_isLogin) {
        await provider.signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
      } else {
        await provider.signUp(_emailCtrl.text.trim(), _passCtrl.text.trim());
      }
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFC9FBE),
        title: Text(
          _isLogin ? 'Sign In' : 'Create Account',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              const Icon(Icons.smart_toy_rounded,
                  size: 72, color: Color(0xFFFC9FBE)),
              const SizedBox(height: 12),
              Text(
                _isLogin ? 'Welcome back!' : 'Join the battle!',
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5E2A7E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? 'Sign in to continue your journey'
                    : 'Create an account to save your progress',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF816380),
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 36),

              // Email field
              _buildField('Email', _emailCtrl, false),
              const SizedBox(height: 16),

              // Password field
              _buildField('Password', _passCtrl, true),
              const SizedBox(height: 12),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontFamily: 'Nunito',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE65A3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito'),
                    elevation: 6,
                    shadowColor: const Color(0x33FF99C7),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Sign In' : 'Register'),
                ),
              ),

              const SizedBox(height: 16),

              // Toggle login/register
              TextButton(
                onPressed: () => setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                }),
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : 'Already have an account? Sign In',
                  style: const TextStyle(
                    color: Color(0xFF9A6C99),
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool obscure) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(fontFamily: 'Nunito', color: Color(0xFF5E2A7E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF9A6C99),
          fontFamily: 'Nunito',
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFC9FBE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEE65A3), width: 2),
        ),
      ),
    );
  }
}