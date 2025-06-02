import 'package:flutter/material.dart';
import 'package:fr_wpkit/home.dart';
import 'package:fr_wpkit/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(),
      darkTheme: ThemeData.dark(),
      home: HomePage(),
    );
  }
}
