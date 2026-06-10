import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home_page.dart';
import 'platform/process_text.dart';
import 'process_text_page.dart';
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
        home: const _Root(),
      ),
    );
  }
}

/// Chooses the start screen: the process-text editor when launched from another
/// app's selection menu (Android), otherwise the normal home screen.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final Future<String?> _initialText = const ProcessTextService().getInitialText();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initialText,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final selected = snapshot.data;
        if (selected != null && selected.isNotEmpty) {
          return ProcessTextPage(initialText: selected);
        }
        return const HomePage();
      },
    );
  }
}
