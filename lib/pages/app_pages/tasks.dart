import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

enum TaskFilter { all, today, upcoming, completed }

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TextEditingController _taskController = TextEditingController();
  DateTime? _dueDate;
  TaskFilter _filter = TaskFilter.all;
  String _priority = '🔴 High';

  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;

  final List<String> priorities = ['🔴 High', '🟡 Medium', '🟢 Low'];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("User not logged in");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("User not logged in");
      return;
    }

    try {
      await Supabase.instance.client.from('tasks').insert({
        'title': title,
        'done': false,
        'dueDate': _dueDate?.toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
        'priority': _priority,
        'user_id': userId,
      });

      _taskController.clear();
      _dueDate = null;
      _priority = '🔴 High';

      await _fetchTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task saved ✅")),
      );
    } catch (e) {
      print("Error saving task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save task")),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> tasks) {
    final now = DateTime.now();
    return tasks.where((task) {
      final done = task['done'] ?? false;
      final dueDate = task['dueDate'] != null
          ? DateTime.tryParse(task['dueDate']) ?? DateTime.now()
          : null;

      switch (_filter) {
        case TaskFilter.today:
          return dueDate != null &&
              dueDate.year == now.year &&
              dueDate.month == now.month &&
              dueDate.day == now.day &&
              !done;
        case TaskFilter.upcoming:
          return dueDate != null && dueDate.isAfter(now) && !done;
        case TaskFilter.completed:
          return done;
        case TaskFilter.all:
          return true;
      }
    }).toList();
  }

  Future<void> _toggleDone(int id, bool? val) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .update({'done': val})
          .eq('id', id);

      await _fetchTasks();
    } catch (e) {
      print("Error updating task: $e");
    }
  }

  Future<void> _deleteTask(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task"),
        content: const Text("Are you sure you want to delete this task?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('tasks')
            .delete()
            .eq('id', id);

        await _fetchTasks();
      } catch (e) {
        print("Error deleting task: $e");
      }
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title'] ?? '';
    final done = task['done'] ?? false;
    final due = task['dueDate'] != null
        ? DateTime.tryParse(task['dueDate'])
        : null;
    final priority = task['priority'] ?? '';
    final id = task['id'];

    final textStyle = GoogleFonts.lora().copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? Colors.grey : Colors.black,
    );

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CheckboxListTile(
        title: Text("$priority $title", style: textStyle),
        subtitle: due != null
            ? Text("Due: ${due.day}/${due.month}/${due.year}")
            : null,
        value: done,
        onChanged: (val) => _toggleDone(id, val),
        secondary: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteTask(id),
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
  final filteredTasks = _applyFilter(_tasks);

  return Scaffold(
    appBar: AppBar(
      title: Text("Tasks", style: GoogleFonts.lora(fontSize: 26)),
      backgroundColor: Colors.deepPurple,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: "Task title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Pick Due Date"),
                ),
                const SizedBox(width: 12),
                if (_dueDate != null)
                  Text("Due: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}",
                      style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _priority,
              onChanged: (val) => setState(() => _priority = val!),
              items: priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveTask,
              icon: const Icon(Icons.save),
              label: const Text("Save Task"),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tasks View", style: GoogleFonts.lora(fontSize: 18)),
                DropdownButton<TaskFilter>(
                  value: _filter,
                  onChanged: (f) => setState(() => _filter = f!),
                  items: const [
                    DropdownMenuItem(value: TaskFilter.all, child: Text("All")),
                    DropdownMenuItem(value: TaskFilter.today, child: Text("Today")),
                    DropdownMenuItem(value: TaskFilter.upcoming, child: Text("Upcoming")),
                    DropdownMenuItem(value: TaskFilter.completed, child: Text("Completed")),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (filteredTasks.isEmpty)
              const Text("No tasks yet 🌱")
            else
              Column(children: filteredTasks.map(_buildTaskCard).toList()),
          ],
        ),
      ),
    ),
  );
 }
}
