import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color(0xFF333333),
      ),
      body: Center(
        child: const Text(
          'History Screen',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
      backgroundColor: const Color(0xFF333333),
    );
  }
}
