import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:open_filex/open_filex.dart';

Future<void> exportPdfFile(String fileName, List<Map<String, dynamic>> data) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, text: 'Sent SMS History'),
        pw.Table.fromTextArray(
          headers: ['Recipient', 'Message', 'Timestamp'],
          data: data.map((log) {
            return [
              log['recipients'] ?? '',
              log['message'] ?? '',
              (log['timestamp'] as String).substring(0, 16),
            ];
          }).toList(),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();

  if (kIsWeb) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(bytes);

    await OpenFilex.open(file.path);
  }
}