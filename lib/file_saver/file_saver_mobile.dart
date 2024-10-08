import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'file_saver.dart';

class FileSaverMobile implements FileSaver {
  @override
  Future<void> saveImage(Uint8List imageBytes, String fileName) async {
    final result = await ImageGallerySaver.saveImage(
      imageBytes,
      name: fileName,
      quality: 80,
    );
    if (result['isSuccess'] != true) {
      throw Exception('Failed to save image to gallery.');
    }
  }
}

FileSaver createFileSaver() => FileSaverMobile();
