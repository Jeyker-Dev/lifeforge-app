import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class LifeForgeApp extends ConsumerWidget {
  const LifeForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LifeForge',
      debugShowCheckedModeBanner: false,
      theme: buildForgeTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
