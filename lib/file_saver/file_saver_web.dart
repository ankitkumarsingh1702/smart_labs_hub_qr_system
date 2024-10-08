import 'dart:typed_data';
import 'dart:html' as html;
import 'file_saver.dart';

class FileSaverWeb implements FileSaver {
  @override
  Future<void> saveImage(Uint8List imageBytes, String fileName) async {
    final blob = html.Blob([imageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "$fileName.png")
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

FileSaver createFileSaver() => FileSaverWeb();
