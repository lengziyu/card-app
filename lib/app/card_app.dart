import 'package:card_app/core/theme/app_theme.dart';
import 'package:card_app/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';

class CardApp extends StatelessWidget {
  const CardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '集卡',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
