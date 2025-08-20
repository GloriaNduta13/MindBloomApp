import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:open_filex/open_filex.dart';

Future<void> exportExcelFile(String fileName, List<Map<String, dynamic>> data) async {
  final workbook = excel.Excel.createExcel();
  final sheet = workbook['SMS History'];

  sheet.appendRow([
    excel.TextCellValue('Recipient'),
    excel.TextCellValue('Message'),
    excel.TextCellValue('Timestamp'),
  ]);

  for (final log in data) {
    sheet.appendRow([
      excel.TextCellValue(log['recipients'] ?? ''),
      excel.TextCellValue(log['message'] ?? ''),
      excel.TextCellValue((log['timestamp'] as String).substring(0, 16)),
    ]);
  }

  final bytes = workbook.save();

  if (kIsWeb) {
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(bytes!);

    await OpenFilex.open(file.path);
  }
}