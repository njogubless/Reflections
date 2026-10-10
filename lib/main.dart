import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/theme/app_theme.dart';
import 'core/widgets/state_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final setupError = await bootstrapFirebase();
  runApp(
    setupError == null
        ? const ProviderScope(child: DevotionApp())
        : _SetupRequiredApp(message: setupError),
  );
}

class _SetupRequiredApp extends StatelessWidget {
  const _SetupRequiredApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: Scaffold(
      body: SafeArea(
        child: EmptyView(
          icon: Icons.settings_outlined,
          title: 'Firebase setup required',
          message: message,
        ),
      ),
    ),
  );
}
