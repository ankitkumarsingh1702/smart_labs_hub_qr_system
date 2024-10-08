import 'dart:io'; // Required for File
import 'dart:typed_data'; // Required for Uint8List
import 'dart:ui'; // Required for the blur effect
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // For opening URLs
import 'package:qr_flutter/qr_flutter.dart'; // For QR code generation
import 'package:screenshot/screenshot.dart'; // For screenshot (QR code capture)
import 'package:share_plus/share_plus.dart'; // For sharing
import 'package:image_gallery_saver/image_gallery_saver.dart'; // For saving to gallery
import 'package:path_provider/path_provider.dart'; // For file paths
import 'package:flutter/services.dart'; // For clipboard functionality

class PrintQRScreen extends StatelessWidget {
  const PrintQRScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Labs - QR Data'),
        backgroundColor: const Color(0xFF333333),
      ),
      body: FutureBuilder(
        future: FirebaseFirestore.instance.collection('smartlabsqr').get(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching data.'));
          }

          final documents = snapshot.data?.docs ?? [];

          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              final fileName = document['fileName'];
              final fileUrl = document['fileUrl'];
              final qrId = document['qrId'];
              final createdAt = document['createdAt'];

              // Parse and format the date and time
              DateTime dateTime = DateTime.parse(createdAt);
              String formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
              String formattedTime = DateFormat('hh:mm a').format(dateTime); // AM/PM format

              return Card(
                color: const Color(0xFF444444), // Dark background for the card
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 4,
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Data and formatted date and time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Data",
                            style: const TextStyle(
                              fontFamily: "Itim",
                              fontSize: 22,
                              color: Color(0xFFD9D9D9),
                            ),
                          ),
                          Text(
                            "$formattedDate, $formattedTime", // Display formatted date and time
                            style: const TextStyle(
                              fontFamily: "Itim",
                              fontSize: 13,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // QR ID
                      Text(
                        'QR ID: $qrId',
                        style: const TextStyle(
                          fontFamily: "Itim",
                          fontSize: 17,
                          color: Color(0xFFD9D9D9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // File URL (Clickable)
                      GestureDetector(
                        onTap: () async {
                          // Open the URL in the default browser
                          if (await canLaunch(fileUrl)) {
                            await launch(fileUrl);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open URL')),
                            );
                          }
                        },
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            fontFamily: "Itim",
                            fontSize: 17,
                            color: Color(0xFFFFB347), // Highlighted color for the clickable link
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // "Show QR Code" Button
                      Center(
                        child: TextButton(
                          onPressed: () {
                            _showQRCode(context, fileUrl, qrId); // Show QR Code on click
                          },
                          child: const Text(
                            "Show QR Code",
                            style: TextStyle(
                              fontFamily: "Itim",
                              fontSize: 15,
                              color: Color(0xFFFFB347), // Button color
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Function to show QR code with blurred background and action buttons
  // Function to show QR code with blurred background and action buttons
  void _showQRCode(BuildContext context, String fileUrl, String qrId) {
    ScreenshotController screenshotController = ScreenshotController(); // For capturing QR screenshot

    // Construct the new URL
    String qrCodeDataUrl = 'https://ait-smart-lab.vercel.app/pdf/$qrId'; // Custom URL using qrId

    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop(); // Close the dialog on tap
          },
          child: Stack(
            children: [
              // Blurred background
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
              // Dialog for QR code display
              Dialog(
                backgroundColor: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // White patch behind QR code
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.white, // White background for the QR code
                      child: Screenshot(
                        controller: screenshotController,
                        child: QrImageView(
                          data: qrCodeDataUrl, // Use the custom URL for the QR code
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white, // Ensure the QR code has a white background
                          foregroundColor: Colors.black, // Black QR code
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // QR ID displayed below the QR code with copy icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          qrId,
                          style: const TextStyle(
                            fontFamily: "Itim",
                            fontSize: 8, // Smaller font size for QR ID
                            color: Colors.white, // White font for the QR ID
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: qrId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('QR ID copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Save and Share buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Capture only the QR code without the QR ID for saving
                            screenshotController.capture().then((Uint8List? capturedImage) async {
                              if (capturedImage != null) {
                                final result = await ImageGallerySaver.saveImage(
                                  capturedImage, // Save image as Uint8List
                                  name: "qr_code",
                                  quality: 80,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('QR Code saved to gallery!')),
                                );
                              }
                            });
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Capture only the QR code without the QR ID for sharing
                            screenshotController.capture().then((Uint8List? capturedImage) async {
                              if (capturedImage != null) {
                                final directory = (await getTemporaryDirectory()).path;
                                String filePath = '$directory/qr_code.png';
                                File file = File(filePath);
                                await file.writeAsBytes(capturedImage);
                                await Share.shareXFiles([XFile(file.path)], text: 'Here is the QR code');
                              }
                            });
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }



}



