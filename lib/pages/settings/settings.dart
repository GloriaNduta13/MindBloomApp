import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gloriaapp/pages/providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;

  final apiKeyController = TextEditingController();
  final usernameController = TextEditingController();
  final senderIdController = TextEditingController();

  final List<String> themes = ['Lavender', 'Earthy', 'Charcoal', 'Sunset'];
  final List<String> exportFormats = ['pdf', 'markdown'];

  String _selectedTheme = 'Lavender';
  bool _vibration = true;
  String _promptTime = '20:00';
  double _fontScale = 1.0;
  String _contrastMode = 'normal';
  bool _speechToText = true;
  bool _autoExport = false;
  String _exportFormat = 'pdf';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      final response = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _selectedTheme = response['theme'] ?? _selectedTheme;
          _vibration = response['vibration'] ?? _vibration;
          _promptTime = response['prompt_time'] ?? _promptTime;
          _fontScale = (response['font_scale'] as num?)?.toDouble() ?? _fontScale;
          _contrastMode = response['contrast_mode'] ?? _contrastMode;
          _speechToText = response['speech_to_text'] ?? _speechToText;
          _autoExport = response['auto_export'] ?? _autoExport;
          _exportFormat = response['export_format'] ?? _exportFormat;
        });

        final bool isDarkMode = response['dark_mode'] ?? false;
        Provider.of<ThemeProvider>(context, listen: false)
            .setTheme(_selectedTheme, isDarkMode);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      apiKeyController.text = prefs.getString('sms_api_key') ?? '';
      usernameController.text = prefs.getString('sms_username') ?? '';
      senderIdController.text = prefs.getString('sms_sender_id') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      return;
    }

    final bool isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    await supabase.from('user_settings').upsert({
      'user_id': userId,
      'theme': _selectedTheme,
      'dark_mode': isDarkMode,
      'vibration': _vibration,
      'prompt_time': _promptTime,
      'font_scale': _fontScale,
      'contrast_mode': _contrastMode,
      'speech_to_text': _speechToText,
      'auto_export': _autoExport,
      'export_format': _exportFormat,
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_api_key', apiKeyController.text.trim());
    await prefs.setString('sms_username', usernameController.text.trim());
    await prefs.setString('sms_sender_id', senderIdController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.lora(fontSize: 26)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SMS Credentials', style: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: "API Key", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: senderIdController,
                decoration: const InputDecoration(labelText: "Sender ID", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),

              Text('Theme Settings', style: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedTheme,
                decoration: const InputDecoration(labelText: 'Choose theme', border: OutlineInputBorder()),
                items: themes.map((theme) => DropdownMenuItem(value: theme, child: Text(theme))).toList(),
                onChanged: (val) {
                  setState(() => _selectedTheme = val!);
                  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                  themeProvider.setTheme(_selectedTheme, themeProvider.isDarkMode);
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return SwitchListTile(
                    title: const Text("Dark Mode"),
                    value: themeProvider.isDarkMode,
                    onChanged: (val) {
                      themeProvider.toggleDarkMode(val);
                      setState(() {});
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              Text('Notifications', style: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text("Vibration"),
                value: _vibration,
                onChanged: (val) => setState(() => _vibration = val),
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Prompt Time (HH:mm)", border: OutlineInputBorder()),
                controller: TextEditingController(text: _promptTime),
                onChanged: (val) => _promptTime = val,
              ),
              const SizedBox(height: 24),

              Text('Accessibility', style: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.bold)),
              Slider(
                value: _fontScale,
                min: 0.8,
                max: 1.5,
                divisions: 7,
                label: "Font scale: ${_fontScale.toStringAsFixed(1)}",
                onChanged: (val) => setState(() => _fontScale = val),
              ),
              DropdownButtonFormField<String>(
                value: _contrastMode,
                decoration: const InputDecoration(labelText: 'Contrast Mode', border: OutlineInputBorder()),
                items: ['normal', 'high'].map((mode) => DropdownMenuItem(value: mode, child: Text(mode))).toList(),
                onChanged: (val) => setState(() => _contrastMode = val!),
              ),
              SwitchListTile(
                title: const Text("Speech-to-Text"),
                value: _speechToText,
                onChanged: (val) => setState(() => _speechToText = val),
              ),
              const SizedBox(height: 24),

              Text('App Control', style: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text("Auto Export"),
                value: _autoExport,
                onChanged: (val) => setState(() => _autoExport = val),
              ),
              DropdownButtonFormField<String>(
                value: _exportFormat,
                decoration: const InputDecoration(labelText: 'Export Format', border: OutlineInputBorder()),
                items: exportFormats.map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _exportFormat = val!),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Settings"),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                onPressed: _saveSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}