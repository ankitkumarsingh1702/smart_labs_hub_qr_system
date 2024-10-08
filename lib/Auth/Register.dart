// lib/Auth/RegisterUser.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/homescreen.dart'; // Import the HomeScreen class
import 'LoginUser.dart'; // Import the LoginScreen class

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String selectedBranch = '';
  List<String> permittedEmails = [];
  List<String> branches = [];

  bool _isLoading = false; // To show a loading indicator during registration
  bool _isTermsAccepted = false; // To track the state of the Terms and Conditions checkbox

  @override
  void initState() {
    super.initState();
    _fetchPermittedEmails();
    _fetchBranches();
  }

  // Fetch permitted emails in real-time using Firestore
  void _fetchPermittedEmails() {
    FirebaseFirestore.instance
        .collection('smartlabsuserspermitted')
        .doc('permittedemail')
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          permittedEmails = data.values.map((e) => e.toString()).toList();
        });
      }
    }, onError: (error) {
      // Handle errors appropriately in your app
      print('Error fetching permitted emails: $error');
      setState(() {
        permittedEmails = [];
      });
    });
  }

  // Fetch branch items in real-time using Firestore
  void _fetchBranches() {
    FirebaseFirestore.instance
        .collection('DropdownButtonFormField') // Corrected Collection Name
        .doc('items')
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        print('Fetched data: $data'); // Debug print
        List<String> branchList = data.values.map((e) => e.toString()).toList();

        setState(() {
          branches = branchList;
          // Set the default selected branch if not already set
          if (selectedBranch.isEmpty && branches.isNotEmpty) {
            selectedBranch = branches[0];
          } else if (!branches.contains(selectedBranch)) {
            selectedBranch = branches.isNotEmpty ? branches[0] : '';
          }
        });
      } else {
        // Handle the case where the document does not exist
        print('No branches document found.');
        setState(() {
          branches = [];
          selectedBranch = '';
        });
      }
    }, onError: (error) {
      // Handle errors appropriately in your app
      print('Error fetching branches: $error');
      setState(() {
        branches = [];
        selectedBranch = '';
      });
    });
  }


  // Method to register the user and save data to Firestore
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (!_isTermsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
              Text('You must accept the Terms and Conditions.')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final enteredEmail = _emailController.text.trim();
      final enteredPassword = _passwordController.text.trim();

      // Special case for admin login
      if (enteredEmail.toLowerCase() == 'admin@aitpune' &&
          enteredPassword == '12345678') {
        // Direct login for admin without any other validation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        setState(() {
          _isLoading = false;
        });
        return; // Skip further execution for admin case
      }

      // Normal user registration flow
      if (permittedEmails.contains(enteredEmail)) {
        try {
          // Register the user using Firebase Authentication
          UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: enteredEmail,
            password: enteredPassword,
          );

          // Use the user's UID as the document ID
          final String uid = userCredential.user!.uid;

          // Save user data in Firestore using UID as the document ID
          await FirebaseFirestore.instance
              .collection('smartlabsusers')
              .doc(uid)
              .set({
            'name': _nameController.text.trim(),
            'branch': selectedBranch,
            'email': enteredEmail,
            'uid': uid,
            'createdAt':
            FieldValue.serverTimestamp(), // Timestamp for registration
          });

          // Navigate to HomeScreen after successful registration
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } on FirebaseAuthException catch (e) {
          String errorMessage =
              'An error occurred. Please try again.';
          if (e.code == 'email-already-in-use') {
            errorMessage =
            'This email is already registered. Please log in instead.';
            // Optionally, navigate to the Login Screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                action: SnackBarAction(
                  label: 'Login',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                ),
              ),
            );
          } else if (e.code == 'weak-password') {
            errorMessage = 'The password provided is too weak.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          } else if (e.code == 'invalid-email') {
            errorMessage =
            'The email address is not valid.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                  Text(e.message ?? errorMessage)),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'You are not allowed to register with this email.')),
        );
      }
    }
  }

  // Dispose controllers when not needed to free up resources
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Widget for the Register Screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      Colors.white, // Match the background color from the Login Screen
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding:
            const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo at the top (assuming you have a logo to place)
                  Image.asset(
                    'lib/assets/aitlogoo.png',
                    height: 100,
                    fit: BoxFit.cover,
                    color: const Color(0xFF4CAF50), // Applying the color
                    colorBlendMode:
                    BlendMode.srcIn, // Blending the color with the image
                  ),
                  const SizedBox(height: 20),

                  // "Register" text
                  const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                      FontWeight.bold,
                      color: Colors.black, // Changed to black
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(
                        color: Colors.black), // Input text color set to black
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(
                          color: Colors.black), // Label color changed to black
                      filled: true,
                      fillColor: Colors.white,
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType:
                    TextInputType.emailAddress,
                    style: const TextStyle(
                        color: Colors.black), // Input text color set to black
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(
                          color: Colors.black), // Label color changed to black
                      filled: true,
                      fillColor: Colors.white,
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Please enter your email';
                      }
                      // Basic email validation
                      if (!RegExp(
                          r'^[^@]+@[^@]+\.[^@]+')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(
                        color: Colors.black), // Input text color set to black
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                          color: Colors.black), // Label color changed to black
                      filled: true,
                      fillColor: Colors.white,
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(8.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Branch Dropdown with real-time fetched items
                  branches.isEmpty
                      ? const CircularProgressIndicator()
                      : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey
                              .withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset:
                          const Offset(0, 3), // changes position of shadow
                        ),
                      ],
                    ),
                    child:
                    DropdownButtonFormField<String>(
                      value: selectedBranch.isNotEmpty
                          ? selectedBranch
                          : null,
                      style: const TextStyle(
                          color:
                          Colors.black), // Dropdown text color set to black
                      items: branches
                          .map((branch) =>
                          DropdownMenuItem(
                            value: branch,
                            child: Padding(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                  horizontal:
                                  8.0),
                              child: Text(
                                branch,
                                style: const TextStyle(
                                    color: Colors
                                        .black), // Text color changed to black
                              ),
                            ),
                          ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedBranch = value!;
                        });
                      },
                      decoration:
                      InputDecoration(
                        labelText: 'Branch',
                        labelStyle: const TextStyle(
                            color: Colors
                                .black), // Label color changed to black
                        filled: true,
                        fillColor:
                        Colors.white, // Background color changed to white
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                              8.0),
                        ),
                      ),
                      dropdownColor:
                      Colors.white, // Dropdown menu background color
                      icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors
                              .black), // Dropdown arrow color
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Terms and conditions
                  Row(
                    children: [
                      Checkbox(
                        value: _isTermsAccepted,
                        onChanged: (bool? value) {
                          setState(() {
                            _isTermsAccepted =
                                value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I confirm that I have read and understood the Terms and Conditions and Privacy Policy of the site.',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                              Colors.black), // Text color changed to black
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Register button
                  ElevatedButton(
                    onPressed:
                    _isLoading ? null : _register,
                    style:
                    ElevatedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 12),
                      backgroundColor:
                      const Color(0xFF4CAF50), // Button color as per the Login Screen
                      minimumSize:
                      const Size(double.infinity, 40),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'Register',
                      style: TextStyle(
                          color: Colors
                              .white,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigate to Login Screen
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account?",
                        style: TextStyle(
                            color: Colors
                                .black),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                const LoginScreen()),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                              color: Color(
                                  0xFF4CAF50)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
