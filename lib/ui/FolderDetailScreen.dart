// lib/screens/FolderDetailScreen.dart

import 'dart:io' show File, Platform; // Conditional import to prevent issues on mobile
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart'; // To generate a random UID
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_gallery_saver/image_gallery_saver.dart'; // To save images to gallery on mobile
import 'package:permission_handler/permission_handler.dart'; // To handle permissions
import 'dart:html' as html; // For web-specific file handling

class FolderDetailScreen extends StatefulWidget {
  final String folderName;

  const FolderDetailScreen({Key? key, required this.folderName}) : super(key: key);

  @override
  _FolderDetailScreenState createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _qrNameController = TextEditingController();
  bool isUploading = false;
  String? pdfUrl;

  final ScreenshotController screenshotController = ScreenshotController(); // For capturing QR screenshot

  @override
  void dispose() {
    _qrNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white, // Set AppBar background to white
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              _pickPdfAndUpload(context, folderName: widget.folderName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildFolderQrList()), // Display list of QR codes in the folder
          if (isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(), // Show loading indicator during upload
            ),
        ],
      ),
    );
  }

  // Build QR Code List within the Folder from Firestore
  Widget _buildFolderQrList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser?.uid)
          .collection('folders')
          .doc(widget.folderName)
          .collection('independent_qr_code')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final qrDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: qrDocs.length,
            itemBuilder: (context, index) {
              final qrData = qrDocs[index].data() as Map<String, dynamic>;
              final qrName = qrData['name'] ?? 'Unnamed QR Code';
              final qrUrl = qrData['qrUrl'];
              final qrId = qrDocs[index].id; // Document ID for actions

              return ListTile(
                leading: const Icon(Icons.qr_code, color: Colors.green), // QR code icon
                title: Text(
                  qrName,
                  style: const TextStyle(color: Colors.black), // QR name text
                ),
                trailing: const Icon(Icons.qr_code_2, color: Colors.green), // Secondary QR icon
                onTap: () {
                  _showQrModalBottomSheet(qrName, qrUrl);
                },
                onLongPress: () {
                  _confirmDeleteOrUpdateQr(qrId, isFolder: true, folderName: widget.folderName);
                },
              );
            },
          );
        } else {
          return const Center(
            child: Text(
              'No QR codes in this folder.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }
      },
    );
  }

  // Show QR Code in a Modal Bottom Sheet
  void _showQrModalBottomSheet(String qrName, String qrUrl) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your QR Code is ready for the world! ⭐',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const SizedBox(height: 10),
                // Wrap both QR code and name inside Screenshot
                Screenshot(
                  controller: screenshotController,
                  child: Container(
                    color: Colors.white, // Ensure white background
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        QrImageView(
                          data: qrUrl,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          qrName,
                          style: const TextStyle(
                            color: Colors.black, // Black text
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Optional: If you want to display the name outside the screenshot as well
                // Text(qrName, style: const TextStyle(color: Colors.black)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        controller:
                        TextEditingController(text: qrUrl),
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy,
                                color: Colors.black),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: qrUrl));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'QR URL copied to clipboard!')),
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderSide:
                            const BorderSide(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        _saveQRCode(); // Call the save method
                      },
                      icon: const Icon(Icons.save,
                          color: Colors.white),
                      label: const Text('Download',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF689F38), // Custom color
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        _shareQRCode(); // Call the share method
                      },
                      icon: const Icon(Icons.share,
                          color: Colors.white),
                      label: const Text('Share',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF689F38), // Custom color
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Save QR code using Screenshot controller
  Future<void> _saveQRCode() async {
    try {
      final Uint8List? capturedImage = await screenshotController.capture();

      if (capturedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error capturing QR Code image.')),
        );
        return;
      }

      if (kIsWeb) {
        // Web-specific logic for downloading
        final blob = html.Blob([capturedImage]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "qr_code_${Uuid().v4()}.png")
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code downloaded successfully (web).')),
        );
      } else {
        // Mobile logic for downloading
        if (Platform.isAndroid || Platform.isIOS) {
          // Check and request storage permission
          var permissionStatus = await Permission.storage.status;
          if (!permissionStatus.isGranted) {
            permissionStatus = await Permission.storage.request();
            if (!permissionStatus.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission is required to save the QR code.')),
              );
              return;
            }
          }

          // Save the image to gallery
          final result = await ImageGallerySaver.saveImage(
            capturedImage,
            quality: 80,
            name: 'qr_code_${Uuid().v4()}',
          );

          if (result['isSuccess'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR Code saved successfully to gallery.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save QR Code.')),
            );
          }
        } else {
          // Handle other platforms if necessary
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported platform for saving QR Code.')),
          );
        }
      }
    } catch (e) {
      // Catch any unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  // Share QR code
  Future<void> _shareQRCode() async {
    try {
      final Uint8List? capturedImage =
      await screenshotController.capture();
      if (capturedImage != null) {
        if (kIsWeb) {
          // On web, sharing images directly is limited. Share the URL instead.
          await Share.share('Here is the QR code: $pdfUrl');
        } else {
          // On mobile/Desktop
          final directory = (await getTemporaryDirectory()).path;
          String filePath =
              '$directory/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
          File file = File(filePath);
          await file.writeAsBytes(capturedImage);
          await Share.shareXFiles([XFile(file.path)], text: 'Here is the QR code');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error capturing QR Code image.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR Code: $e')),
      );
    }
  }

  // Pick PDF and Upload for QR Code within Folder
  Future<void> _pickPdfAndUpload(BuildContext context, {String? folderName}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // Ensure bytes are available on web
    );

    if (result != null) {
      if (kIsWeb) {
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        if (fileBytes != null) {
          setState(() {
            isUploading = true;
          });
          await _uploadPdfToFirebaseWeb(fileBytes, fileName, context, folderName: folderName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to retrieve file bytes.')),
          );
        }
      } else {
        String? filePath = result.files.single.path;
        if (filePath != null) {
          File file = File(filePath);
          String fileName = result.files.single.name;
          setState(() {
            isUploading = true;
          });
          await _uploadPdfToFirebase(file, fileName, context, folderName: folderName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File path is null')),
          );
        }
      }
    }
  }

  // Upload PDF to Firebase for Web
  Future<void> _uploadPdfToFirebaseWeb(Uint8List fileBytes, String fileName, BuildContext context, {String? folderName}) async {
    try {
      String uniqueFileName = '${Uuid().v4()}_$fileName';
      String filePath = 'pdfs/$uniqueFileName';
      UploadTask uploadTask =
      FirebaseStorage.instance.ref().child(filePath).putData(fileBytes);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String pdfDownloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        pdfUrl = pdfDownloadUrl;
        isUploading = false;
      });

      _showQrNameDialog(context, pdfDownloadUrl, folderName: folderName);
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  // Upload PDF to Firebase for Mobile/Desktop
  Future<void> _uploadPdfToFirebase(File file, String fileName, BuildContext context, {String? folderName}) async {
    try {
      String uniqueFileName = '${Uuid().v4()}_$fileName';
      String filePath = 'pdfs/$uniqueFileName';
      UploadTask uploadTask = FirebaseStorage.instance.ref().child(filePath).putFile(file);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String pdfDownloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        pdfUrl = pdfDownloadUrl;
        isUploading = false;
      });

      _showQrNameDialog(context, pdfDownloadUrl, folderName: folderName);
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  // Show QR Name Dialog for QR Code within Folder
  void _showQrNameDialog(BuildContext context, String pdfUrl, {String? folderName}) {
    final TextEditingController _assetPasswordController = TextEditingController();
    final TextEditingController _wifiPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter QR Code Details'),
          content: SingleChildScrollView( // To prevent overflow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _qrNameController,
                  decoration: const InputDecoration(hintText: 'QR Code Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _assetPasswordController,
                  decoration: const InputDecoration(hintText: 'Document Password'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _wifiPasswordController,
                  decoration: const InputDecoration(hintText: 'Device Password'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _createIndependentQrCode(
                  pdfUrl,
                  assetPassword: _assetPasswordController.text.trim(),
                  wifiPassword: _wifiPasswordController.text.trim(),
                  folderName: folderName,
                );
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Create Independent QR code or Folder QR code and store in Firestore with Random UID
  Future<void> _createIndependentQrCode(String pdfUrl,
      {String? folderName, required String assetPassword, required String wifiPassword}) async {
    final qrName = _qrNameController.text.trim();
    if (qrName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Name cannot be empty.')));
      return;
    }

    String randomUid = Uuid().v4();

    try {
      // Fetch the branch from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        String branch = userDoc['branch'];

        String docId = '$branch$randomUid';

        // Updated QR Link with Full Path
        String qrLink =
            'https://ait-smart-lab.vercel.app/smartlabsusers/${currentUser!.uid}/independent_qr_code/$docId';

        String qrLinkWithPath;
        if (folderName == null) {
          qrLinkWithPath = qrLink;
        } else {
          qrLinkWithPath =
          'https://ait-smart-lab.vercel.app/smartlabsusers/${currentUser!.uid}/folders/$folderName/independent_qr_code/$docId';
        }

        Map<String, dynamic> qrData = {
          'pdfUrl': pdfUrl,
          'name': qrName,
          'created_at': FieldValue.serverTimestamp(),
          'qrUrl': qrLinkWithPath,
          'branch': branch,
          'asset_password': assetPassword, // Saving asset password
          'wifi_password': wifiPassword,   // Saving Wi-Fi password
        };

        if (folderName == null) {
          // Independent QR Code
          await FirebaseFirestore.instance
              .collection('smartlabsusers')
              .doc(currentUser!.uid)
              .collection('independent_qr_code')
              .doc(docId)
              .set(qrData);
        } else {
          // QR Code under a specific folder
          await FirebaseFirestore.instance
              .collection('smartlabsusers')
              .doc(currentUser!.uid)
              .collection('folders')
              .doc(folderName)
              .collection('independent_qr_code')
              .doc(docId)
              .set(qrData);
        }

        setState(() {
          _qrNameController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(folderName == null
                  ? 'Independent QR Code created!'
                  : 'QR Code created in folder "$folderName"!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error fetching branch')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating QR code: $e')));
    }
  }

  // Confirmation Dialog for Deleting or Updating QR Code
  void _confirmDeleteOrUpdateQr(String qrId, {required bool isFolder, String? folderName}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('QR Code Options'),
          content: const Text('Would you like to delete or update this QR Code?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _updateQr(qrId, isFolder: isFolder, folderName: folderName);
              },
              child: const Text('Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Set update button color
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteQr(qrId, isFolder: isFolder, folderName: folderName);
              },
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Set delete button color to red
              ),
            ),
          ],
        );
      },
    );
  }

  // Update QR Code
  Future<void> _updateQr(String qrId, {required bool isFolder, String? folderName}) async {
    try {
      DocumentReference qrDocRef;
      if (isFolder && folderName != null) {
        qrDocRef = FirebaseFirestore.instance
            .collection('smartlabsusers')
            .doc(currentUser!.uid)
            .collection('folders')
            .doc(folderName)
            .collection('independent_qr_code')
            .doc(qrId);
      } else {
        qrDocRef = FirebaseFirestore.instance
            .collection('smartlabsusers')
            .doc(currentUser!.uid)
            .collection('independent_qr_code')
            .doc(qrId);
      }

      DocumentSnapshot qrDoc = await qrDocRef.get();
      if (!qrDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code does not exist!')),
        );
        return;
      }

      Map<String, dynamic> qrData =
      qrDoc.data() as Map<String, dynamic>;
      String? oldPdfUrl = qrData['pdfUrl'];

      // Prompt user to pick a new PDF
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // Ensure bytes are available on web
      );

      if (result == null) {
        // User canceled the picker
        return;
      }

      if (kIsWeb) {
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        if (fileBytes != null) {
          setState(() {
            isUploading = true;
          });

          await _uploadNewPdfWeb(fileBytes, fileName, qrDocRef, oldPdfUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to retrieve file bytes.')),
          );
        }
      } else {
        String? filePath = result.files.single.path;
        if (filePath != null) {
          File newFile = File(filePath);
          String newFileName = result.files.single.name;

          setState(() {
            isUploading = true;
          });

          await _uploadNewPdfMobile(newFile, newFileName, qrDocRef, oldPdfUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File path is null')),
          );
        }
      }
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating QR Code: $e')),
      );
    }
  }

  // Upload New PDF for Web
  Future<void> _uploadNewPdfWeb(Uint8List fileBytes, String fileName,
      DocumentReference qrDocRef, String? oldPdfUrl) async {
    try {
      String uniqueFileName = '${Uuid().v4()}_$fileName';
      String filePath = 'pdfs/$uniqueFileName';
      UploadTask uploadTask =
      FirebaseStorage.instance.ref().child(filePath).putData(fileBytes);

      TaskSnapshot newSnapshot =
      await uploadTask.whenComplete(() => {});
      String newPdfDownloadUrl =
      await newSnapshot.ref.getDownloadURL();

      // Update Firestore document with new pdfUrl
      await qrDocRef.update({
        'pdfUrl': newPdfDownloadUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Delete old PDF from Storage if it exists
      if (oldPdfUrl != null && oldPdfUrl.isNotEmpty) {
        try {
          Reference oldPdfRef =
          FirebaseStorage.instance.refFromURL(oldPdfUrl);
          await oldPdfRef.delete();
        } catch (e) {
          // Handle error if old PDF deletion fails
          print('Error deleting old PDF from Storage: $e');
        }
      }

      setState(() {
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code updated successfully!')),
      );
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading new file: $e')),
      );
    }
  }

  // Upload New PDF for Mobile/Desktop
  Future<void> _uploadNewPdfMobile(File newFile, String fileName,
      DocumentReference qrDocRef, String? oldPdfUrl) async {
    try {
      String uniqueFileName = '${Uuid().v4()}_$fileName';
      String filePath = 'pdfs/$uniqueFileName';
      UploadTask uploadTask =
      FirebaseStorage.instance.ref().child(filePath).putFile(newFile);

      TaskSnapshot newSnapshot =
      await uploadTask.whenComplete(() => {});
      String newPdfDownloadUrl =
      await newSnapshot.ref.getDownloadURL();

      // Update Firestore document with new pdfUrl
      await qrDocRef.update({
        'pdfUrl': newPdfDownloadUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Delete old PDF from Storage if it exists
      if (oldPdfUrl != null && oldPdfUrl.isNotEmpty) {
        try {
          Reference oldPdfRef =
          FirebaseStorage.instance.refFromURL(oldPdfUrl);
          await oldPdfRef.delete();
        } catch (e) {
          // Handle error if old PDF deletion fails
          print('Error deleting old PDF from Storage: $e');
        }
      }

      setState(() {
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code updated successfully!')),
      );
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading new file: $e')),
      );
    }
  }

  // Delete QR Code
  Future<void> _deleteQr(String qrId, {required bool isFolder, String? folderName}) async {
    try {
      DocumentReference qrDocRef;
      if (isFolder && folderName != null) {
        qrDocRef = FirebaseFirestore.instance
            .collection('smartlabsusers')
            .doc(currentUser!.uid)
            .collection('folders')
            .doc(folderName)
            .collection('independent_qr_code')
            .doc(qrId);
      } else {
        qrDocRef = FirebaseFirestore.instance
            .collection('smartlabsusers')
            .doc(currentUser!.uid)
            .collection('independent_qr_code')
            .doc(qrId);
      }

      // Get the QR code data
      DocumentSnapshot qrDoc = await qrDocRef.get();
      if (qrDoc.exists) {
        Map<String, dynamic> qrData =
        qrDoc.data() as Map<String, dynamic>;
        String? pdfUrl = qrData['pdfUrl'];

        // Delete the PDF from Firebase Storage if exists
        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          try {
            Reference pdfRef =
            FirebaseStorage.instance.refFromURL(pdfUrl);
            await pdfRef.delete();
          } catch (e) {
            // Handle error if PDF deletion fails
            print('Error deleting PDF from Storage: $e');
          }
        }

        // Delete the QR code document
        await qrDocRef.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code deleted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code does not exist!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting QR Code: $e')),
      );
    }
  }
}
