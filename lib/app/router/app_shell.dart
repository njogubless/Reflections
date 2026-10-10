import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/sermons/presentation/widgets/sermon_widgets.dart';
import '../theme/tokens.dart';

/// Bottom navigation shell with the docked mini-player above it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.headphones_outlined, Icons.headphones, 'Sermons'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Read'),
    (Icons.forum_outlined, Icons.forum, 'Questions'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniPlayer(),
        NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            for (final (icon, selected, label) in _items)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(selected),
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                label: label,
              ),
          ],
        ),
      ],
    ),
  );
}
