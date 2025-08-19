import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;

List<String> extractPhoneNumbers(Uint8List fileBytes, {int columnIndex = 0}) {
  final workbook = excel.Excel.decodeBytes(fileBytes);
  final sheet = workbook.tables[workbook.tables.keys.first];
  final numbers = <String>[];

  final regex = RegExp(r'^(?:\+254|07|01)\d{8}$');

  for (var i = 1; i < sheet!.rows.length; i++) {
    final row = sheet.rows[i];
    if (row.length > columnIndex) {
      final cell = row[columnIndex];
      if (cell != null && cell.value != null) {
        String raw = cell.value.toString().trim();
        if (RegExp(r'^\d{9}$').hasMatch(raw)) raw = '0$raw';
        if (regex.hasMatch(raw)) {
          numbers.add(raw);
        } else {
          print("Invalid number: $raw");
        }
      }
    }
  }

  return numbers;
}

Future<List<String>> pickExcelFile({int columnIndex = 0}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );

  if (result != null && result.files.first.bytes != null) {
    final fileBytes = result.files.first.bytes!;
    final numbers = extractPhoneNumbers(fileBytes, columnIndex: columnIndex);
    print("Extracted ${numbers.length} valid phone numbers from column $columnIndex");
    return numbers;
  }

  print("No file selected or file is empty");
  return [];
}

class SmsService {
  static const String _baseUrl = 'https://api.mspace.co.ke/smsapi/v2/sendtext';

  static Future<bool> sendSms({
    required List<String> recipients,
    required String message,
    required String apiKey,
    required String username,
    required String senderId,
  }) async {
    if (recipients.isEmpty || message.trim().isEmpty) {
      print("No recipients or message is empty");
      return false;
    }

    final encodedMessage = Uri.encodeComponent(message);
    final recipientString = recipients.join(',');

    final url = Uri.parse(
      '$_baseUrl/apikey=$apiKey'
      '/username=$username'
      '/senderId=$senderId'
      '/recipient=$recipientString'
      '/message=$encodedMessage',
    );

    bool success = false;
    String responseBody = '';

    try {
      final response = await http.get(url);
      responseBody = response.body;
      success = response.statusCode == 200 && responseBody.toLowerCase().contains("success");

      print(success
          ? 'SMS Response: $responseBody'
          : 'Error ${response.statusCode}: $responseBody');
    } catch (e) {
      print('Exception during SMS send: $e');
    }

   
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId != null) {
      for (final number in recipients) {
        try {
          await supabase.from('sent_sms').insert({
            'user_id': userId,
            'recipients': number,
            'message': message,
            'timestamp': DateTime.now().toIso8601String(),
            'status': success ? 'sent' : 'failed',
          });
        } catch (e) {
          print("Failed to log SMS for $number: $e");
        }
      }
    } else {
      print("No authenticated user — skipping Supabase logging");
    }

    return success;
  }
}
