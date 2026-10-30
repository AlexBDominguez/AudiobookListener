import 'package:flutter/material.dart';

import 'style_preview_screen.dart';
import 'theme/app_theme.dart';

class AudiobookApp extends StatelessWidget {
  const AudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audiolibros',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const StylePreviewScreen(),
    );
  }
}
