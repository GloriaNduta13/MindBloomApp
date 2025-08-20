import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<String> tags = ['dream', 'gratitude', 'goals', 'memory', 'intentions'];
  List<String> selectedTags = [];
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to view your journal")),
      );
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('journal')
          .select()
          .eq('user_id', user.id)
          .order('timestamp', ascending: false);

      if (data != null && data is List) {
        setState(() {
          _entries = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch entries: $e")),
      );
    }
  }

  Future<void> _saveEntry() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('journal').insert({
        'user_id': user.id,
        'title': title,
        'body': body,
        'tags': selectedTags,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _titleController.clear();
      _bodyController.clear();
      selectedTags.clear();

      await _fetchEntries();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Journal saved 📓")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save entry: $e")),
      );
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final id = entry['id'];
    final titleController = TextEditingController(text: entry['title']);
    final bodyController = TextEditingController(text: entry['body']);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Entry"),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: "Body"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client
                  .from('journal')
                  .update({
                    'title': titleController.text.trim(),
                    'body': bodyController.text.trim(),
                  })
                  .eq('id', id);

              Navigator.of(context).pop();
              await _fetchEntries();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(int id) async {
  try {
    await Supabase.instance.client
        .from('journal')
        .delete()
        .eq('id', id is int ? id : int.parse(id.toString()));

    print("Delete response: success"); 

    await _fetchEntries();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Entry deleted 🗑️")),
    );
  } catch (e) {
     print("❌ Delete error: $e");
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text("Failed to delete entry: $e")),
      );
    }
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final title = entry['title'] ?? 'Untitled';
    final body = entry['body'] ?? '';
    final timestamp = DateTime.parse(entry['timestamp']);
    final formatted = "${timestamp.day}/${timestamp.month}/${timestamp.year}";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(
          body.length > 100 ? "${body.substring(0, 100)}..." : body,
          style: GoogleFonts.lora(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editEntry(entry),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteEntry(entry['id']),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text("Journal", style: GoogleFonts.lora(fontSize: 26)),
        backgroundColor: Colors.deepPurple,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: tags.map((tag) {
                  final isSelected = selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? selectedTags.add(tag)
                            : selectedTags.remove(tag);
                      });
                    },
                    selectedColor: Colors.deepPurple.shade200,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                minLines: 6,
                maxLines: 15,
                decoration: const InputDecoration(
                  labelText: "Write your thoughts...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saveEntry,
                icon: const Icon(Icons.save),
                label: const Text("Save Entry"),
              ),
              const Divider(height: 32),
              Text("Previous entries", style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_entries.isEmpty)
                const Text("No entries yet 🌱")
              else
                Column(children: _entries.map(_buildEntryCard).toList()),
            ],
          ),
        ),
      ),
    );
  }
}
