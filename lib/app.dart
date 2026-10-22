import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';

class SigaApp extends StatelessWidget {
  const SigaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'S.I.G.A • Belém',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const HomePage(),
      );
}
