import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ReflectionsPage extends StatefulWidget {
  final String? incomingPrompt;

  const ReflectionsPage({Key? key, this.incomingPrompt}) : super(key: key);

  @override
  State<ReflectionsPage> createState() => _ReflectionsPageState();
}

class _ReflectionsPageState extends State<ReflectionsPage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> moods = ['🥰', '😐', '😤', '🧘', '😮', '🤯'];
  String? _lastSaved;
  String? _selectedMood;

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLastReflection();

    if (widget.incomingPrompt != null && widget.incomingPrompt!.isNotEmpty) {
      _controller.text = "${widget.incomingPrompt}\n\n";
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final available = await _speech.initialize();
      setState(() => _speechAvailable = available);
    });
  }

  Future<void> _loadLastReflection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSaved = prefs.getString('last_reflection');
    });
  }

  void startListening() async {
    if (_speechAvailable && !_isListening) {
      setState(() => _isListening = true);
      await _speech.listen(onResult: (result) {
        final currentText = _controller.text;
        final newText = result.recognizedWords;
        setState(() {
          _controller.text = currentText.trim().endsWith(".")
              ? "$currentText $newText"
              : "$currentText ${newText.trim()}";
        });
      });
    }
  }

  void stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _saveReflection() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      setState(() => _isSaving = false);
      return;
    }

    final savedData = {
      'user_id': user.id, 
      'mood': _selectedMood ?? '',
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      
      await Supabase.instance.client.from('reflections').insert(savedData);

    
      await Supabase.instance.client.from('archive').insert({
        'user_id': user.id,
        'type': 'reflection',
        'content': text,
        'mood': _selectedMood ?? '',
        'timestamp': savedData['timestamp'],
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_reflection', "${savedData['mood']} ${savedData['text']}");

      setState(() {
        _controller.clear();
        _selectedMood = null;
        _lastSaved = "${savedData['mood']} ${savedData['text']}";
      });

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved to cloud and archive 🌸")),
      );
    } 
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving reflection: $e")),
      );
    } 
    finally {
     setState(() => _isSaving = false);
    }
  }


 @override
Widget build(BuildContext context) {
  final prompt = widget.incomingPrompt;
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  return Scaffold(
    appBar: AppBar(
      title: Text("Reflection", style: GoogleFonts.lora(fontSize: 26)),
      backgroundColor: Colors.deepPurple,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null && prompt.isNotEmpty) ...[
              Text("Prompt:", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('"$prompt"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.deepPurpleAccent,
                  )),
              const SizedBox(height: 20),
            ],
            const Text("Select your mood:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: moods.map((emoji) {
                final isSelected = _selectedMood == emoji;
                return ChoiceChip(
                  label: Text(emoji, style: const TextStyle(fontSize: 24)),
                  selected: isSelected,
                  onSelected: (_) => setState(() {
                    _selectedMood = isSelected ? null : emoji;
                  }),
                  selectedColor: Colors.deepPurple.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Type or speak your thoughts...",
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isListening ? stopListening : startListening,
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  label: Text(_isListening ? "Stop Listening" : "Speak Reflection"),
                ),
                const SizedBox(width: 12),
                if (_isListening)
                  const Text("Listening...", style: TextStyle(color: Colors.deepPurple)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveReflection,
              icon: const Icon(Icons.save),
              label: Text(_isSaving ? "Saving..." : "Save Reflection"),
            ),
            if (_lastSaved != null) ...[
              const SizedBox(height: 30),
              const Text("Last saved:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_lastSaved!, style: const TextStyle(fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    ),
  );
 }
}
