import 'package:flutter/material.dart';

import '../features/splash/presentation/pages/splash_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J2I Barbearia',
      home: SplashPage(),
    );
  }
}
