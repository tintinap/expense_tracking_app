import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native (iOS / Android / macOS / Windows / Linux) implementation.
/// Writes to the documents directory and opens the share sheet.
Future<void> saveAndShareExcel(List<int> bytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(path)]);
}
