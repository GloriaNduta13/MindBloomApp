import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonaPage extends StatefulWidget {
  const PersonaPage({Key? key}) : super(key: key);

  @override
  State<PersonaPage> createState() => _PersonaPageState();
}

class _PersonaPageState extends State<PersonaPage> {
  final List<String> avatars = ['😌', '🧠', '🌱', '🪷', '🛸'];
  String? selectedAvatar;
  double alignment = 0.5;
  final TextEditingController _mantraController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPersona();
  }

  Future<void> _loadPersona() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("User not logged in");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('personas')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          selectedAvatar = response['avatar'];
          alignment = (response['alignment'] as num?)?.toDouble() ?? 0.5;
          _mantraController.text = response['mantra'] ?? '';
        });
      }
    } catch (e) {
      print("Error loading persona: $e");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _savePersona() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("User not logged in");
      return;
    }

    final summary =
        "${selectedAvatar ?? '🪐'} • ${_mantraController.text.trim()} • Alignment: ${alignment.toStringAsFixed(2)}";

    try {
      await Supabase.instance.client.from('personas').upsert({
        'user_id': userId,
        'avatar': selectedAvatar ?? '🪐',
        'alignment': alignment,
        'mantra': _mantraController.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Persona saved! $summary")),
      );
    } catch (e) {
      print("Error saving persona: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save persona")),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  final alignmentLabel = alignment < 0.33
      ? 'Rational 🧠'
      : alignment < 0.66
          ? 'Curious 🌀'
          : 'Mystic 🌙';
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  return Scaffold(
    appBar: AppBar(
      title: Text("Your Persona", style: GoogleFonts.lora(fontSize: 26)),
      backgroundColor: Colors.deepPurple,
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Choose your vibe:", style: GoogleFonts.lora(fontSize: 18)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: avatars.map((emoji) {
                      final isSelected = selectedAvatar == emoji;
                      return ChoiceChip(
                        label: Text(emoji, style: const TextStyle(fontSize: 24)),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            selectedAvatar = emoji;
                          });
                        },
                        selectedColor: Colors.deepPurple.shade200,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text("Philosophical alignment:", style: GoogleFonts.lora(fontSize: 18)),
                  Slider(
                    value: alignment,
                    onChanged: (value) => setState(() => alignment = value),
                    min: 0,
                    max: 1,
                    label: alignmentLabel,
                    divisions: 3,
                    activeColor: Colors.deepPurple,
                  ),
                  const SizedBox(height: 24),
                  Text("Your mantra:", style: GoogleFonts.lora(fontSize: 18)),
                  TextField(
                    controller: _mantraController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Speak your truth...",
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.deepPurple.shade50,
                    child: ListTile(
                      leading: Text(selectedAvatar ?? '🪐',
                          style: const TextStyle(fontSize: 32)),
                      title: Text(
                        _mantraController.text.isEmpty
                            ? "Your mantra here..."
                            : _mantraController.text,
                      ),
                      subtitle: Text("Alignment: ${alignment.toStringAsFixed(2)}"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save Persona"),
                    onPressed: _savePersona,
                  ),
                ],
              ),
            ),
          ),
  );
 }
}
