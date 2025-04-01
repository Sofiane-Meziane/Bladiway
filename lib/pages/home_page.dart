import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Home Screen')),
      body: const Center(
        child: Text('Hello, Flutter!', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
