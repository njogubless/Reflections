import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../media/media_storage.dart';

/// Displays an image stored at a Firebase Storage *path*, with an
/// on-brand fallback when there is no image or it fails to load.
class StorageImage extends ConsumerWidget {
  const StorageImage({
    super.key,
    required this.path,
    this.fallbackIcon = Icons.auto_stories_outlined,
    this.fit = BoxFit.cover,
  });

  final String? path;
  final IconData fallbackIcon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = path;
    if (p == null || p.isEmpty) return _Fallback(icon: fallbackIcon);
    final url = ref.watch(mediaUrlProvider(p));
    return url.when(
      data: (u) => Image.network(
        u,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _Fallback(icon: fallbackIcon),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const ColoredBox(color: AppColors.surfaceLow),
      ),
      loading: () => const ColoredBox(color: AppColors.surfaceLow),
      error: (_, _) => _Fallback(icon: fallbackIcon),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDeep],
      ),
    ),
    child: Center(child: Icon(icon, color: AppColors.gold, size: 28)),
  );
}
