// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation – triggers a browser file download.
Future<void> saveAndShareExcel(List<int> bytes, String fileName) async {
  final base64 = base64Encode(Uint8List.fromList(bytes));
  final anchor = html.AnchorElement(
    href:
        'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64',
  )
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
