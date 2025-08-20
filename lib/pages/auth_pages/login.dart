import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:gloriaapp/pages/app_pages/home.dart';
import 'package:gloriaapp/pages/bulk_sms/sms_credentials_provider.dart';
import '../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool isLoading = false;
  bool isSignUpMode = false;

  Future<void> signIn() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (response.session != null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
      } else {
        _showError("Login failed. Please check your credentials.");
      }
    } on AuthException catch (e) {
      _showError("Error: ${e.message}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> signUp() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = response.user;
      if (user != null) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
      } else {
        _showMessage("Check your email to confirm your account.");
        setState(() => isSignUpMode = false);
      }
    } catch (e) {
      _showError("Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getRedirectUrl(),
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError("Google sign-in failed: ${e.toString()}");
    }
  }

  String _getRedirectUrl() {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'com.mindbloom.app://login-callback';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSignUpMode) ...[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: isSignUpMode ? signUp : signIn,
                  child: Text(isSignUpMode ? "Sign Up" : "Login"),
                ),
                TextButton(
                  onPressed: () => setState(() => isSignUpMode = !isSignUpMode),
                  child: Text(isSignUpMode
                      ? "Already have an account? Login"
                      : "Don't have an account? Sign Up"),
                ),
                const Divider(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("Sign in with Google"),
                  onPressed: signInWithGoogle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}