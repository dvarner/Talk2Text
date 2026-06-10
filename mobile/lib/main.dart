import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home_page.dart';
import 'state/app_controller.dart';

void main() {
  runApp(const Talk2TextApp());
}

class Talk2TextApp extends StatelessWidget {
  const Talk2TextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController()..init(),
      lazy: false,
      child: MaterialApp(
        title: 'Talk2Text',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1f538d),
            brightness: Brightness.dark,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}
