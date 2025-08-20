import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gloriaapp/pages/providers/theme_provider.dart';
import 'package:gloriaapp/pages/bulk_sms/sms_credentials_provider.dart';
import 'package:gloriaapp/pages/auth_pages/onboarding_page.dart';
import 'package:gloriaapp/pages/welcome_page/welcome.dart';
import 'package:gloriaapp/pages/app_pages/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  print('Test variable: ${dotenv.env['TEST_VAR']}');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode: false)),
        ChangeNotifierProvider(create: (_) => SmsCredentialsProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          return MaterialApp(
            title: 'MindBloom',
            theme: themeProvider.theme,
            debugShowCheckedModeBanner: false,
            home: const WelcomePage(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getStartingPage() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const WelcomePage();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('sms_api_key');
      if (apiKey == null || apiKey.isEmpty) {
        return const OnboardingPage();
      } else {
        return const HomePage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getStartingPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.data!;
      },
    );
  }
}