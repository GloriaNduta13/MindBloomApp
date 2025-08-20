import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({Key? key}) : super(key: key);

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Map<String, dynamic>> _reflections = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReflections();
  }

  Future<void> _fetchReflections() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("User not logged in");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('reflections')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _reflections = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching reflections: $e");
      setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete this reflection?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Supabase.instance.client
                    .from('reflections')
                    .delete()
                    .eq('id', id);
                Navigator.pop(context);
                await _fetchReflections();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reflection deleted 🗑️")),
                );
              } catch (e) {
                print("Delete error: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to delete: $e")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, int id, Map<String, dynamic> data) {
    final TextEditingController editController = TextEditingController(text: data['text'] ?? '');
    String? selectedMood = data['mood'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Edit Reflection"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: ['🥰', '😐', '😤', '🧘', '😮', '🤯'].map((emoji) {
                  final isSelected = selectedMood == emoji;
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 20)),
                    selected: isSelected,
                    onSelected: (_) {
                      setModalState(() {
                        selectedMood = emoji;
                      });
                    },
                    selectedColor: Colors.deepPurple.shade200,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: "Update your reflection...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('reflections')
                      .update({
                        'text': editController.text.trim(),
                        'mood': selectedMood ?? '',
                        'timestamp': DateTime.now().toIso8601String(),
                      })
                      .eq('id', id);
                  Navigator.pop(context);
                  await _fetchReflections();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reflection updated 💡")),
                  );
                } catch (e) {
                  print("Update error: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to update: $e")),
                  );
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.deepPurple)),
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
      title: Text("Archive", style: GoogleFonts.lora(fontSize: 26)),
      backgroundColor: Colors.deepPurple,
    ),
    body: SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reflections.isEmpty
              ? const Center(child: Text("No reflections saved yet 💭"))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: _reflections.length,
                  itemBuilder: (context, index) {
                    final data = _reflections[index];
                    final mood = data['mood'] ?? '';
                    final text = data['text'] ?? '';
                    final timestampRaw = data['timestamp'];
                    final timestamp = timestampRaw != null
                        ? DateTime.tryParse(timestampRaw) ?? DateTime.now()
                        : DateTime.now();
                    final formatted = DateFormat('MMM d, yyyy – h:mm a').format(timestamp);
                    final id = data['id'];

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("$mood $text", style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              "Saved: $formatted",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.deepPurple),
                                  onPressed: () => _showEditDialog(context, id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(context, id),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    ),
  );
 }
}
