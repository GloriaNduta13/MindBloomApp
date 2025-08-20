import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gloriaapp/pages/providers/theme_provider.dart';
import 'package:gloriaapp/pages/bulk_sms/sms_credentials_provider.dart';

import 'package:gloriaapp/pages/settings/profile.dart';
import 'package:gloriaapp/pages/settings/settings.dart';
import 'package:gloriaapp/pages/app_pages/reflection.dart';
import 'package:gloriaapp/pages/app_pages/prompt.dart';
import 'package:gloriaapp/pages/app_pages/archive.dart';
import 'package:gloriaapp/pages/app_pages/persona.dart';
import 'package:gloriaapp/pages/app_pages/planner.dart';
import 'package:gloriaapp/pages/app_pages/tasks.dart';
import 'package:gloriaapp/pages/app_pages/journal.dart';
import 'package:gloriaapp/pages/welcome_page/welcome.dart';
import 'package:gloriaapp/pages/bulk_sms/send_sms_page.dart';
import 'package:gloriaapp/pages/bulk_sms/sms_history.dart';

Future<String?> fetchUserName() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null || !response.containsKey('name')) {
      print('Name not found in response');
      return null;
    }

    return response['name'] as String?;
  } catch (e) {
    print('Error fetching name: $e');
    return null;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: fetchUserName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final name = snapshot.data ?? "User";
        final quote = "In the middle of difficulty lies opportunity.";
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Welcome to MindBloom, $name!',
              style: GoogleFonts.lora(fontSize: 20),
            ),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.deepPurple,
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Profile',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                },
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                  child: const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                _drawerItem(context, Icons.person, 'Profile', const ProfilePage()),
                _drawerItem(context, Icons.self_improvement, 'Reflection', const ReflectionsPage()),
                _drawerItem(context, Icons.book, 'Journal', const JournalPage()),
                _drawerItem(context, Icons.lightbulb, 'Prompt', const PromptPage()),
                _drawerItem(context, Icons.schedule, 'Planner', const PlannerPage()),
                _drawerItem(context, Icons.task, 'Tasks', const TasksPage()),
                _drawerItem(context, Icons.face_retouching_natural, 'Persona', const PersonaPage()),
                _drawerItem(context, Icons.archive, 'Archive', const ArchivePage()),
                _drawerItem(context, Icons.settings, 'Settings', const SettingsPage()),
                _drawerItem(context, Icons.sms, 'Send SMS', const SendSmsPage()),
                _drawerItem(context, Icons.history, 'SMS History', const SmsHistoryPage()),

                Consumer<ThemeProvider>(
                   builder: (BuildContext context, ThemeProvider themeProvider, Widget? _) {
                     return SwitchListTile(
                       title: const Text("Dark Mode"),
                       secondary: const Icon(Icons.dark_mode),
                       value: themeProvider.isDarkMode,
                       onChanged: (val) => themeProvider.toggleDarkMode(val),
                      );
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {                  
                    Provider.of<SmsCredentialsProvider>(context, listen: false).clearCredentials();
                    
                    await Supabase.instance.client.auth.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomePage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hey $name!",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Today's muse:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '"$quote"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Write a reflection"),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ReflectionsPage()));
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ListTile _drawerItem(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }
}