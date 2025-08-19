import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reflection.dart';

class PromptPage extends StatefulWidget {
  const PromptPage({Key? key}) : super(key: key);

  @override
  State<PromptPage> createState() => _PromptPageState();
}

class _PromptPageState extends State<PromptPage> {
  final List<String> prompts = [
    "What does memory sound like?",
    "If fear vanished, what would replace caution?",
    "Describe time using a color.",
    "Are you your thoughts or the witness of them?",
    "If you met your future self in a dream, what would you ask?",
    "Where does silence begin?",
  ];

  late String currentPrompt;

  @override
  void initState() {
    super.initState();
    currentPrompt = prompts[Random().nextInt(prompts.length)];
  }

  void shufflePrompt() {
    setState(() {
      currentPrompt = prompts[Random().nextInt(prompts.length)];
    });
  }

  Future<void> _logPrompt() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('prompt_logs').insert({
      'user_id': userId,
      'prompt': currentPrompt,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _savePrompt() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('saved_prompts').insert({
      'user_id': userId,
      'prompt': currentPrompt,
      'saved_at': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Prompt saved!")),
    );
  }

  @override
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  return Scaffold(
    appBar: AppBar(
      title: Text("Surreal Prompts", style: GoogleFonts.lora(fontSize: 26)),
      backgroundColor: Colors.deepPurple,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Today's curiosity catalyst:",
                style: GoogleFonts.lora(fontSize: 18)),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey(currentPrompt),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '"$currentPrompt"',
                  style: const TextStyle(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.shuffle),
              label: const Text("Shuffle Prompt"),
              onPressed: shufflePrompt,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text("Reflect on this"),
              onPressed: () async {
                await _logPrompt();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReflectionsPage(incomingPrompt: currentPrompt),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.bookmark),
              label: const Text("Save Prompt"),
              onPressed: _savePrompt,
            ),
          ],
        ),
      ),
    ),
  );
 }
}
