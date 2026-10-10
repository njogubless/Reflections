import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/brand.dart';
import '../../../notifications/presentation/notification_pages.dart';

/// Notification bell (with unread dot) and profile emblem shown on tab headers.
class HeaderActions extends ConsumerWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: unread > 0
              ? 'Notifications, $unread unread'
              : 'Notifications',
          onPressed: () => context.push(Routes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            smallSize: 8,
            backgroundColor: AppColors.goldDeep,
            child: const Icon(Icons.notifications_none),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Semantics(
            button: true,
            label: 'Profile',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go(Routes.profile),
              child: const LogoEmblem(size: 38),
            ),
          ),
        ),
      ],
    );
  }
}
