import 'dart:typed_data';

import 'file_saver.dart';

class FileSaverStub implements FileSaver {
  @override
  Future<void> saveImage(Uint8List imageBytes, String fileName) {
    throw UnsupportedError('File saving is not supported on this platform.');
  }
}

FileSaver createFileSaver() => FileSaverStub();
