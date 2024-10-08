// lib/screens/HomeScreen.dart

import 'dart:io' show File; // Conditional import to prevent issues on web
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
import '../Auth/register.dart'; // Ensure correct relative path
import 'package:flutter/foundation.dart' show kIsWeb;

import 'FolderDetailScreen.dart';
import '../file_saver/file_saver.dart'; // Import the FileSaver abstraction

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _qrNameController = TextEditingController();
  bool isUploading = false;
  String? pdfUrl;

  final ScreenshotController screenshotController = ScreenshotController();
  late TabController _tabController;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // GlobalKey for Scaffold

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Initialize TabController with 2 tabs
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    _qrNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Assign the key to Scaffold
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My QR Codes',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            // Use the key to open the drawer
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Text(
                'AIT Smart Labs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.folder),
              title: Text('My Folders'),
              onTap: () {
                // Close the drawer
                Navigator.pop(context);
                // Switch to the "Folders" tab (index 0)
                _tabController.animateTo(0);
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Sign Out'),
              onTap: () async {
                // Close the drawer
                Navigator.pop(context);
                try {
                  // Sign out the user
                  await FirebaseAuth.instance.signOut();
                  // Navigate to RegisterScreen and remove all previous routes
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterScreen()),
                        (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  // Handle sign out errors if any
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                    color: Colors.white), // Set color to white to hide it
              ),
              labelColor: Colors.green, // Color for the selected tab
              unselectedLabelColor: Colors.black, // Color for unselected tabs
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder), // No color here, it will change based on selection
                      const SizedBox(width: 8),
                      Text(
                        'Labs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code), // No color here, it will change based on selection
                      const SizedBox(width: 8),
                      Text(
                        'QR Codes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // First Tab for Folders
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon:
                              const Icon(Icons.add, color: Colors.white),
                              label: const Text('Create QR Code'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                Colors.green, // Set the background color
                                foregroundColor:
                                Colors.white, // Set the text (and icon) color to white
                              ),
                              onPressed: () {
                                _pickPdfAndUpload(context); // Independent QR Code flow
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              _showCreateFolderDialog(context); // Folder Creation flow
                            },
                            child: const Icon(
                                Icons.create_new_folder,
                                color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildFolderList()),
                    ],
                  ),
                ),
                // Second Tab for Independent QR Codes
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SmartLabs QR Codes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      Expanded(child: _buildIndependentQrList()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(), // Show loading during upload
            ),
        ],
      ),
    );
  }

  // Build Folder List from Firestore
  Widget _buildFolderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser?.uid)
          .collection('folders')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final folderDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: folderDocs.length,
            itemBuilder: (context, index) {
              final folderData = folderDocs[index].data() as Map<String, dynamic>;
              final folderName = folderData['name'] ?? 'Unnamed Folder';
              return ListTile(
                leading: const Icon(Icons.folder, color: Colors.grey),
                title: Text(
                  folderName,
                  style: const TextStyle(color: Colors.black),
                ),
                trailing: const Icon(Icons.qr_code, color: Colors.green),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FolderDetailScreen(folderName: folderName),
                    ),
                  );
                },
                // Long press for deletion (folders only)
                onLongPress: () {
                  _confirmDeleteFolder(folderName);
                },
              );
            },
          );
        } else {
          return const Center(
            child: Text(
              'No folders created yet.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }
      },
    );
  }

  // Build Independent QR Code List from Firestore
  Widget _buildIndependentQrList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser?.uid)
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
                leading: const Icon(Icons.qr_code, color: Colors.green),
                title: Text(
                  qrName,
                  style: const TextStyle(color: Colors.black),
                ),
                trailing: const Icon(Icons.qr_code_2, color: Colors.green),
                onTap: () {
                  _showQrModalBottomSheet(qrName, qrUrl);
                },
                // Long press for deletion and update
                onLongPress: () {
                  _confirmDeleteOrUpdateQr(
                      qrId, isFolder: false, folderName: null);
                },
              );
            },
          );
        } else {
          return const Center(
            child: Text(
              'No QR codes created yet.',
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
                Screenshot(
                  controller: screenshotController,
                  child: QrImageView(
                    data: qrUrl,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(qrName, style: const TextStyle(color: Colors.black)),
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
                        _saveQRCode();
                      },
                      icon: const Icon(Icons.save,
                          color: Colors.white),
                      label: const Text('Download',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF689F38),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        _shareQRCode();
                      },
                      icon: const Icon(Icons.share,
                          color: Colors.white),
                      label: const Text('Share',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF689F38),
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

  // Function to save QR code using FileSaver abstraction
  Future<void> _saveQRCode() async {
    try {
      final Uint8List? capturedImage =
      await screenshotController.capture();
      if (capturedImage != null) {
        final fileName = 'qr_code_${DateTime.now().millisecondsSinceEpoch}';
        await getFileSaver().saveImage(capturedImage, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code saved successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving QR Code: $e')),
      );
    }
  }

  // Function to share QR code
  Future<void> _shareQRCode() async {
    try {
      final Uint8List? capturedImage =
      await screenshotController.capture();
      if (capturedImage != null) {
        final directory = (await getTemporaryDirectory()).path;
        String filePath =
            '$directory/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
        File file = File(filePath);
        await file.writeAsBytes(capturedImage);
        await Share.shareXFiles([XFile(file.path)], text: 'Here is the QR code');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR Code: $e')),
      );
    }
  }

  // Folder Creation Dialog
  void _showCreateFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title:
          const Text('Create Labs', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _folderNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Lab Name',
              labelStyle: TextStyle(color: Colors.white),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child:
              const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                _createFolder();
                Navigator.of(context).pop();
              },
              child: const Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        );
      },
    );
  }

  // Folder Creation in Firestore
  Future<void> _createFolder() async {
    final folderName = _folderNameController.text.trim();
    if (folderName.isNotEmpty && currentUser != null) {
      // Check if folder already exists to prevent duplicate folder names
      final folderDoc = await FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser!.uid)
          .collection('folders')
          .doc(folderName)
          .get();

      if (folderDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder already exists!')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser!.uid)
          .collection('folders')
          .doc(folderName)
          .set({
        'name': folderName,
        'created_at': FieldValue.serverTimestamp(),
      });

      _folderNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder created successfully!')),
      );
    }
  }

  // Pick PDF and Upload for Independent QR Code
  Future<void> _pickPdfAndUpload(BuildContext context,
      {String? folderName}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // Ensure bytes are available on web
    );

    if (result != null) {
      if (kIsWeb) {
        // On web, use bytes
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        if (fileBytes != null) {
          await _uploadPdfToFirebaseWeb(
              fileBytes, fileName, context,
              folderName: folderName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to retrieve file bytes.')),
          );
        }
      } else {
        // On mobile/Desktop, use path
        String? filePath = result.files.single.path;
        if (filePath != null) {
          File file = File(filePath);
          String fileName = result.files.single.name;
          await _uploadPdfToFirebase(file, fileName, context,
              folderName: folderName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File path is null')),
          );
        }
      }
    }
  }

  // Upload PDF to Firebase for Web
  Future<void> _uploadPdfToFirebaseWeb(Uint8List fileBytes,
      String fileName, BuildContext context,
      {String? folderName}) async {
    try {
      setState(() {
        isUploading = true;
      });

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

      _showQrNameDialog(context, pdfDownloadUrl,
          folderName: folderName); // Pass folderName if any
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  // Upload PDF to Firebase for Mobile/Desktop
  Future<void> _uploadPdfToFirebase(File file, String fileName,
      BuildContext context,
      {String? folderName}) async {
    try {
      setState(() {
        isUploading = true;
      });

      String uniqueFileName = '${Uuid().v4()}_$fileName';
      String filePath = 'pdfs/$uniqueFileName';
      UploadTask uploadTask =
      FirebaseStorage.instance.ref().child(filePath).putFile(file);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      String pdfDownloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        pdfUrl = pdfDownloadUrl;
        isUploading = false;
      });

      _showQrNameDialog(context, pdfDownloadUrl,
          folderName: folderName); // Pass folderName if any
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  // Show QR Name Dialog for Independent QR Code or Folder QR Code
  void _showQrNameDialog(BuildContext context, String pdfUrl, {String? folderName}) {
    final TextEditingController _assetPasswordController = TextEditingController();
    final TextEditingController _wifiPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter QR Code Details'),
          content: Column(
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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
                Navigator.of(context).pop();
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




  // Confirmation Dialog for Deleting Folder
  void _confirmDeleteFolder(String folderName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: const Text(
              'Are you sure you want to delete this folder? This will delete all QR codes inside it.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel deletion
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteFolder(folderName);
                Navigator.of(context).pop(); // Close dialog
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

  // Delete Folder and its QR Codes
  Future<void> _deleteFolder(String folderName) async {
    try {
      // Reference to the folder
      CollectionReference folderRef = FirebaseFirestore.instance
          .collection('smartlabsusers')
          .doc(currentUser!.uid)
          .collection('folders');

      // Reference to the QR codes within the folder
      CollectionReference qrRef = folderRef
          .doc(folderName)
          .collection('independent_qr_code');

      // Get all QR codes in the folder
      QuerySnapshot qrSnapshot = await qrRef.get();

      // Delete each QR code
      for (var qrDoc in qrSnapshot.docs) {
        Map<String, dynamic> qrData =
        qrDoc.data() as Map<String, dynamic>;
        String? pdfUrl = qrData['pdfUrl'];
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
        await qrRef.doc(qrDoc.id).delete();
      }

      // Finally, delete the folder document
      await folderRef.doc(folderName).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Folder and its QR codes deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting folder: $e')),
      );
    }
  }

  // Confirmation Dialog for Deleting or Updating QR Code
  void _confirmDeleteOrUpdateQr(String qrId,
      {required bool isFolder, String? folderName}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('QR Code Options'),
          content: const Text(
              'Would you like to delete or update this QR Code?'),
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
                _updateQr(qrId,
                    isFolder: isFolder, folderName: folderName);
              },
              child: const Text('Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                Colors.blue, // Set update button color
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteQr(qrId,
                    isFolder: isFolder, folderName: folderName);
              },
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red, // Set delete button color to red
              ),
            ),
          ],
        );
      },
    );
  }

  // Update QR Code
  Future<void> _updateQr(String qrId,
      {required bool isFolder, String? folderName}) async {
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
        // On web, use bytes
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        if (fileBytes != null) {
          setState(() {
            isUploading = true;
          });

          await _uploadNewPdfWeb(fileBytes, fileName, qrDocRef,
              oldPdfUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to retrieve file bytes.')),
          );
        }
      } else {
        // On mobile/Desktop, use path
        String? filePath = result.files.single.path;
        if (filePath != null) {
          File newFile = File(filePath);
          String newFileName = result.files.single.name;

          setState(() {
            isUploading = true;
          });

          await _uploadNewPdfMobile(newFile, newFileName, qrDocRef,
              oldPdfUrl);
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
  Future<void> _deleteQr(String qrId,
      {required bool isFolder, String? folderName}) async {
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


