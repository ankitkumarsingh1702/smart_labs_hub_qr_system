// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Auth/register.dart';
import 'ui/homescreen.dart'; // Updated import to match file name

// Add this import for Firebase options
import 'dart:io' show Platform;

// For web platform detection
import 'package:flutter/foundation.dart' show kIsWeb;

// Define Firebase configuration for web
const firebaseConfig = {
  'apiKey': "AIzaSyDwzbyp2aX_7BMoBGA4DQuJnBXWhaYvvIM",
  'authDomain': "smartlabsait.firebaseapp.com",
  'projectId': "smartlabsait",
  'storageBucket': "smartlabsait.appspot.com",
  'messagingSenderId': "383564120676",
  'appId': "1:383564120676:web:4d31c67d6d052aa59ed571",
  'measurementId': "G-ZBRVQTJNSR"
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options for web
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseConfig['apiKey']!,
        authDomain: firebaseConfig['authDomain']!,
        projectId: firebaseConfig['projectId']!,
        storageBucket: firebaseConfig['storageBucket']!,
        messagingSenderId: firebaseConfig['messagingSenderId']!,
        appId: firebaseConfig['appId']!,
        measurementId: firebaseConfig['measurementId']!,
      ),
    );
  } else {
    // For mobile platforms, initialize without options
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Labs',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF333333),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthCheck(), // Check if the user is logged in or not
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to listen to authentication changes in real-time
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking the auth state, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the user is logged in, navigate to HomeScreen
        if (snapshot.hasData && snapshot.data != null) {
          final User? user = snapshot.data;
          if (user != null && user.uid.isNotEmpty) {
            // Optionally, show a Snackbar with the UID
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logged in as UID: ${user.uid}')),
              );
            });
            return const HomeScreen();
          } else {
            // If user data is inconsistent, navigate to RegisterScreen
            return const RegisterScreen();
          }
        }

        // If no user is logged in, navigate to RegisterScreen
        return const RegisterScreen();
      },
    );
  }
}
