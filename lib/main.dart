import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme/obsidian_prime.dart';

void main() {
  runApp(const ArchlenceApp());
}

class ArchlenceApp extends StatelessWidget {
  const ArchlenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archlence',
      debugShowCheckedModeBanner: false,
      theme: obsidianPrimeTheme(),
      home: const AppShell(),
    );
  }
}
