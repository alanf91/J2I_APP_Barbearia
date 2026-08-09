import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J2I Barbearia',
      home: const Scaffold(
        body: Center(
          child: Text('J2I Barbearia'),
        ),
      ),
    );
  }
}