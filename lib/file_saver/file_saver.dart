import 'dart:typed_data';

// Conditional imports based on the platform.
import 'file_saver_stub.dart'
if (dart.library.io) 'file_saver_mobile.dart'
if (dart.library.html) 'file_saver_web.dart';

// Abstract class defining the contract.
abstract class FileSaver {
  Future<void> saveImage(Uint8List imageBytes, String fileName);
}

// Factory method to get the appropriate FileSaver implementation.
FileSaver getFileSaver() => createFileSaver();
