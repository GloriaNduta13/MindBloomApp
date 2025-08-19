import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final TextEditingController _goalController = TextEditingController();
  String _selectedDay = 'Monday';
  final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  bool _showGoals = false;
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _fetchGoals(); 
  }

  Future<void> _fetchGoals() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('planner')
        .select()
        .eq('user_id', user.id) 
        .eq('day', _selectedDay)
        .order('timestamp', ascending: false);

    final data = response;

    if (mounted) {
      setState(() {
        _goals = List<Map<String, dynamic>>.from(data);
        _showGoals = true;
      });
    }
    print("Fetched goals: $_goals");
    print("Current user ID: ${user.id}");
    print("Selected day: $_selectedDay");

  }

  Future<void> _saveGoal() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client.from('planner').insert({
        'user_id': user.id,
        'title': goal,
        'day': _selectedDay,
        'done': false,
        'timestamp': DateTime.now().toIso8601String(),
        'priority': '🔵 Medium',
      });

      _goalController.clear();
      await _fetchGoals();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Goal added 🌱")),
      );
    } catch (e) {
        print("Error saving goal: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save goal: $e")),
        );
      }
  }


  Future<void> _toggleDone(int index, bool? val) async {
    final goal = _goals[index];
    final id = goal['id'];

    await Supabase.instance.client
        .from('planner')
        .update({'done': val})
        .eq('id', id);

    await _fetchGoals();
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, int index) {
    final title = goal['title'] ?? '';
    final done = goal['done'] ?? false;
    final priority = goal['priority'] ?? '🔵';

    final textStyle = GoogleFonts.lora().copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? Colors.grey : Colors.black,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CheckboxListTile(
        title: Text("$priority $title", style: textStyle),
        value: done,
        onChanged: (val) => _toggleDone(index, val),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  return Scaffold(
    appBar: AppBar(
      title: Text("Planner", style: GoogleFonts.lora(fontSize: 26)),
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
              children: days.map((day) {
                final isSelected = _selectedDay == day;
                return ChoiceChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedDay = day;
                      _showGoals = false;
                    });
                    _fetchGoals();
                  },
                  selectedColor: Colors.deepPurple.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              decoration: InputDecoration(
                labelText: "What's your intention?",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _saveGoal,
                ),
              ),
            ),
            const Divider(height: 24),
            Text("Goals for $_selectedDay",
                style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_goals.isEmpty)
              const Text("No goals yet 🌱")
            else
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _showGoals ? 1.0 : 0.0,
                child: Column(
                  children: List.generate(
                    _goals.length,
                    (index) => _buildGoalCard(_goals[index], index),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
 }
}
