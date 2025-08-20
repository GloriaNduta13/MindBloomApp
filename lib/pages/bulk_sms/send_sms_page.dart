import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sms_service.dart';
import 'sms_history.dart';
import 'sms_credentials_provider.dart';

class TemplateFile {
  final String name;
  final String signedUrl;
  final DateTime createdAt;

  TemplateFile({required this.name, required this.signedUrl, required this.createdAt});
}

class SendSmsPage extends StatefulWidget {
  const SendSmsPage({super.key});

  @override
  State<SendSmsPage> createState() => _SendSmsPageState();
}

class _SendSmsPageState extends State<SendSmsPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _senderIdController = TextEditingController();

  List<String> _recipients = [];
  List<String> _headers = [];
  bool _isSending = false;
  int? _selectedColumnIndex;
  List<TemplateFile> _templates = [];
  TemplateFile? _selectedTemplate;
  String? _apiKey;
  String? _username;
  String? _senderId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('sms_api_key');
      _username = prefs.getString('sms_username');
      _senderId = prefs.getString('sms_sender_id');
      _apiKeyController.text = _apiKey ?? '';
      _usernameController.text = _username ?? '';
      _senderIdController.text = _senderId ?? '';
    });
    
    await _loadTemplates();
  }
  

  Future<void> _loadTemplates() async {
    try {
      final files = await Supabase.instance.client.storage.from('templates').list();
      final xlsxFiles = files.where((f) => f.name.endsWith('.xlsx')).toList();

      final templates = <TemplateFile>[];
      for (final file in xlsxFiles) {
        final signedUrl = await Supabase.instance.client.storage
            .from('templates')
            .createSignedUrl(file.name, 60);
        templates.add(TemplateFile(
          name: file.name,
          signedUrl: signedUrl,
          createdAt: DateTime.parse(file.createdAt!),
        ));
      }

      templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() => _templates = templates);
        if (templates.isNotEmpty) {
          final firstTemplate = templates.first;
          final response = await http.get(Uri.parse(firstTemplate.signedUrl));
          if (response.statusCode == 200) {
            await _processExcelFileBytes(response.bodyBytes, firstTemplate.name);
            setState(() => _selectedTemplate = firstTemplate);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load templates: $e")),
        );
      }
    }
  }

  Future<void> _processExcelFileBytes(Uint8List bytes, String fileName) async {
    try {
      final workbook = excel.Excel.decodeBytes(bytes);
      final sheet = workbook.tables[workbook.tables.keys.first];

      if (sheet != null && sheet.rows.isNotEmpty) {
        final headers = sheet.rows.first.map((cell) => cell?.value.toString() ?? '').toList();
        final bestColumn = _autoDetectPhoneColumn(sheet);
        final numbers = _extractNumbers(sheet, bestColumn);

        if (mounted) {
          setState(() {
            _selectedColumnIndex = bestColumn;
            _recipients = numbers;
            _headers = headers;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Processed '$fileName'. Auto-selected '${headers[bestColumn]}' with ${_recipients.length} valid numbers")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Excel sheet is empty or unreadable")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to process Excel file: $e")),
        );
      }
    }
  }

  Future<void> _uploadNewTemplate() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = "template_$timestamp.xlsx";
        final bytes = file.bytes;

        if (bytes != null) {
          await Supabase.instance.client.storage.from('templates').uploadBinary(fileName, bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploaded ${file.name} successfully.")));
            await _loadTemplates();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      }
    }
  }

  int _autoDetectPhoneColumn(excel.Sheet sheet) {
    final regex = RegExp(r'^(?:\+254|07|01)\d{8}$');
    int bestIndex = 0;
    int maxValid = 0;

    for (int i = 0; i < sheet.rows.first.length; i++) {
      int count = 0;
      for (var row in sheet.rows.skip(1)) {
        if (row.length > i) {
          final cell = row[i];
          if (cell != null && cell.value != null) {
            String raw = cell.value.toString().trim();
            if (raw.length == 9 && raw.startsWith('7')) raw = '0$raw';
            if (regex.hasMatch(raw)) count++;
          }
        }
      }
      if (count > maxValid) {
        maxValid = count;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  List<String> _extractNumbers(excel.Sheet sheet, int columnIndex) {
    final regex = RegExp(r'^(?:\+254|07|01)\d{8}$');
    final numbers = <String>[];

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.length > columnIndex) {
        final cell = row[columnIndex];
        if (cell != null && cell.value != null) {
          String raw = cell.value.toString().trim();
          if (raw.length == 9 && raw.startsWith('7')) raw = '0$raw';
          if (regex.hasMatch(raw)) numbers.add(raw);
        }
      }
    }
    return numbers;
  }

  Future<void> _sendSms() async {
    setState(() => _isSending = true);
    final message = _messageController.text.trim();
    final user = Supabase.instance.client.auth.currentUser;

    if (message.isEmpty || _recipients.isEmpty || _apiKey == null || _username == null || _senderId == null || user == null) {
      if (mounted) {
        setState(() => _isSending = false);
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Missing Info'),
            content: Text('Please enter a message, upload valid numbers, and ensure all API credentials are set.'),
          ),
        );
      }
      return;
    }

    try {
      final success = await SmsService.sendSms(
        recipients: _recipients,
        message: message,
        apiKey: _apiKey!,
        username: _username!,
        senderId: _senderId!,
      );

      if (success) {
        final timestamp = DateTime.now().toIso8601String();
        final logs = _recipients.map((number) => {
          'user_id': user.id,
          'recipients': number,
          'message': message,
          'timestamp': timestamp,
          'sender_id': _senderId,
          'username': _username,
        }).toList();

        await Supabase.instance.client.from('sent_sms').insert(logs);

        if (mounted) {
          _messageController.clear();
          setState(() {
            _recipients.clear();
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? "Message sent" : "Failed to send message")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending message: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send SMS"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SmsHistoryPage()),
              );
            },
            tooltip: 'View SMS History',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // REMOVED THE WIDGETS FOR ENTERING AND SAVING CREDENTIALS
              // AS THIS IS NOW HANDLED BY THE ONBOARDING AND SETTINGS PAGES

              const Text("Templates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TemplateFile>(
                      value: _selectedTemplate,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Select Template",
                        border: OutlineInputBorder(),
                      ),
                      items: _templates.map((template) {
                        return DropdownMenuItem(
                          value: template,
                          child: Text(template.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (newTemplate) async {
                        if (newTemplate != null) {
                          setState(() => _selectedTemplate = newTemplate);
                          final response = await http.get(Uri.parse(newTemplate.signedUrl));
                          if (response.statusCode == 200) {
                            await _processExcelFileBytes(response.bodyBytes, newTemplate.name);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Failed to download template.")),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: _uploadNewTemplate,
                    tooltip: "Upload a new template",
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_headers.isNotEmpty) ...[
                const Text("Select Column for Phone Numbers:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedColumnIndex,
                  decoration: const InputDecoration(
                    labelText: "Phone Number Column",
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(_headers.length, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(_headers[i]),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      final url = _selectedTemplate!.signedUrl;
                      final response = await http.get(Uri.parse(url));
                      if (response.statusCode == 200) {
                        final workbook = excel.Excel.decodeBytes(response.bodyBytes);
                        final sheet = workbook.tables[workbook.tables.keys.first];
                        final numbers = _extractNumbers(sheet!, value);
                        if (mounted) {
                          setState(() {
                            _selectedColumnIndex = value;
                            _recipients = numbers;
                          });
                        }
                      }
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),

              const Text("Message Body", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: "Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: Text(_isSending ? "Sending..." : "Send SMS to ${_recipients.length} recipients"),
                onPressed: _isSending || _recipients.isEmpty ? null : _sendSms,
              ),
              
              const SizedBox(height: 20),
              if (_recipients.isNotEmpty) ...[
                const Text("Preview Recipients:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _recipients.length,
                    itemBuilder: (_, index) => Text(_recipients[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}