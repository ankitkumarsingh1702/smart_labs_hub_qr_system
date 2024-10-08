import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../Generate_QR/print_qr.dart'; // Import the new Print QR screen

class GenerateQRScreen extends StatefulWidget {
  const GenerateQRScreen({Key? key}) : super(key: key);

  @override
  _GenerateQRScreenState createState() => _GenerateQRScreenState();
}

class _GenerateQRScreenState extends State<GenerateQRScreen> {
  bool _isLoading = false;

  Future<void> _pickAndUploadPDF() async {
    // Pick a PDF file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      // Get the file
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      String randomUID = Uuid().v4(); // Generate random UID

      setState(() {
        _isLoading = true; // Show loader
      });

      try {
        // Check if the folder or path exists in Firebase Storage before uploading
        final storageRef = FirebaseStorage.instance.ref().child('pdfs/qr$randomUID.pdf');

        // Upload the file to Firebase Storage
        TaskSnapshot snapshot = await storageRef.putFile(file);

        // Get the file URL
        String fileUrl = await snapshot.ref.getDownloadURL();

        // Store metadata in Firestore
        DocumentReference docRef = FirebaseFirestore.instance.collection('smartlabsqr').doc('qr$randomUID');

        // Save metadata in Firestore
        await docRef.set({
          'createdAt': DateTime.now().toIso8601String(),
          'fileName': fileName,
          'fileUrl': fileUrl,
          'qrId': 'qr$randomUID',
        });

        setState(() {
          _isLoading = false; // Hide loader
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false; // Hide loader
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF333333), // Background color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0, // No shadow for app bar
        title: const Text(
          'Smart Labs',
          style: TextStyle(
            fontFamily: 'Itim',
            fontSize: 27,
            letterSpacing: 0.027,
            color: Color(0xFFD9D9D9), // App bar text color
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.yellowAccent),
            onPressed: () {
              // Action for menu icon
            },
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cards layout for icons
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 20.0,
                  crossAxisSpacing: 20.0,
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadPDF, // Trigger PDF upload
                      child: _buildCard('lib/assets/pdf_icon.png', 'PDF'),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to PrintQRScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PrintQRScreen()),
                        );
                      },
                      child: _buildCard('lib/assets/print_qr.png', 'PRINT QR'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Show loader when uploading
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  // Helper method to build each card with the yellow margin
  Widget _buildCard(String imagePath, String label) {
    return Container(
      padding: const EdgeInsets.all(5.0), // Yellow margin padding
      decoration: BoxDecoration(
        color: const Color(0xFFFDB623), // Yellow margin color
        borderRadius: BorderRadius.circular(12), // Rounded corners for the margin
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF444444), // Card background color
          borderRadius: BorderRadius.circular(12), // Rounded corners for the card itself
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: 50,
              height: 50,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Itim',
                fontSize: 16,
                color: Color(0xFFD9D9D9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
