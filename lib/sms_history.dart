import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pdf_export.dart';
import 'excel_export.dart';

class SmsHistoryPage extends StatefulWidget {
  const SmsHistoryPage({super.key});

  @override
  State<SmsHistoryPage> createState() => _SmsHistoryPageState();
}

class _SmsHistoryPageState extends State<SmsHistoryPage> {
  List<Map<String, dynamic>> _messageHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessageHistory();
  }

  Future<void> _loadMessageHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final logs = await Supabase.instance.client
          .from('sent_sms')
          .select()
          .eq('user_id', user.id)
          .order('timestamp', ascending: false);
      setState(() {
        _messageHistory = List<Map<String, dynamic>>.from(logs);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportMessageHistory(String format) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot export. User not authenticated.")),
        );
      }
      return;
    }

    if (_messageHistory.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No message history to export.")),
        );
      }
      return;
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    if (format == 'pdf') {
      await exportPdfFile('sms_history_$timestamp.pdf', _messageHistory);
    } else if (format == 'excel') {
      await exportExcelFile('sms_history_$timestamp.xlsx', _messageHistory);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exported as ${format.toUpperCase()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<String>> groupedMessages = {};
    for (var log in _messageHistory) {
      final key = '${log['timestamp']}|${log['message']}';
      if (!groupedMessages.containsKey(key)) {
        groupedMessages[key] = [];
      }
      groupedMessages[key]!.add(log['recipients']);
    }

    final List<String> sortedKeys = groupedMessages.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('SMS History', style: GoogleFonts.lora()),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: _exportMessageHistory,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: Text("Export as PDF")),
              const PopupMenuItem(value: 'excel', child: Text("Export as Excel")),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedMessages.isEmpty
              ? const Center(child: Text("No message history available."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedKeys.length,
                  itemBuilder: (_, index) {
                    final key = sortedKeys[index];
                    final parts = key.split('|');
                    final timestamp = parts[0];
                    final message = parts[1];
                    final recipients = groupedMessages[key]!.join(', ');

                    final formattedTimestamp = DateTime.parse(timestamp).toLocal().toString().substring(0, 16);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          message,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To: $recipients'),
                            const SizedBox(height: 4),
                            Text(
                              'Sent: $formattedTimestamp',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}