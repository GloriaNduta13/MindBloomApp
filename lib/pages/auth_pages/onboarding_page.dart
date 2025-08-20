import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gloriaapp/pages/app_pages/home.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final apiKeyController = TextEditingController();
  final usernameController = TextEditingController();
  final senderIdController = TextEditingController();

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_api_key', apiKeyController.text.trim());
    await prefs.setString('sms_username', usernameController.text.trim());
    await prefs.setString('sms_sender_id', senderIdController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credentials saved successfully!')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Setup'),
        automaticallyImplyLeading: false, 
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Please enter your SMS credentials to continue.",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(labelText: 'API Key'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: senderIdController,
              decoration: const InputDecoration(labelText: 'Sender ID'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveCredentials,
              child: const Text('Save and Continue'),
            ),
          ],
        ),
      ),
    );
  }
}