import 'package:flutter/material.dart';

/// The application shell. Owned by the Mobile lane (setup-mvp-foundations, design §2);
/// a placeholder until `implement-android-capture-and-store`.
class PaperdropApp extends StatelessWidget {
  const PaperdropApp({super.key});

  static const String title = 'Paperdrop for Ninox';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: title,
      home: Scaffold(body: Center(child: Text(title))),
    );
  }
}
