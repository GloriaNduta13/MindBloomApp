import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  String? email;
  String? name;
  String? avatarUrl;
  int savedPromptCount = 0;
  int reflectionCount = 0;

  final nameController = TextEditingController();
  final avatarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      email = user.email;
    });

    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    setState(() {
      name = profile['name'];
      avatarUrl = profile['avatar_url'];
      nameController.text = name ?? '';
      avatarController.text = avatarUrl ?? '';
    });

    final savedPrompts = await supabase
        .from('saved_prompts')
        .select('id')
        .eq('user_id', user.id);

    final reflections = await supabase
        .from('reflections')
        .select('id')
        .eq('user_id', user.id);

    setState(() {
      savedPromptCount = savedPrompts.length;
      reflectionCount = reflections.length;
    });
  }

  Future<void> _updateProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('profiles').upsert({
      'id': user.id,
      'name': nameController.text,
      'avatar_url': avatarController.text,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated!")),
    );

    _loadProfileData();
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
Widget build(BuildContext context) {
  final avatar = avatarUrl != null && avatarUrl!.isNotEmpty
      ? NetworkImage(avatarUrl!)
      : const AssetImage('assets/default_avatar.png');
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  return Scaffold(
    appBar: AppBar(
      title: Text('Profile', style: GoogleFonts.lora(fontSize: 24, color: Colors.white)),
      backgroundColor: Colors.deepPurple,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundImage: avatar as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(name ?? 'Your Name',
                  style: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Center(
              child: Text(email ?? '',
                  style: GoogleFonts.lora(fontSize: 16, color: Colors.grey[700])),
            ),
            const SizedBox(height: 30),
            Text("Saved Prompts: $savedPromptCount", style: GoogleFonts.lora(fontSize: 18)),
            const SizedBox(height: 10),
            Text("Reflections Written: $reflectionCount", style: GoogleFonts.lora(fontSize: 18)),
            const SizedBox(height: 30),
            Text("Edit Profile", style: GoogleFonts.lora(fontSize: 20)),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: avatarController,
              decoration: const InputDecoration(labelText: "Avatar URL"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Save Changes"),
              onPressed: _updateProfile,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Sign Out"),
              onPressed: _signOut,
            ),
          ],
        ),
      ),
    ),
  );
 }
}
