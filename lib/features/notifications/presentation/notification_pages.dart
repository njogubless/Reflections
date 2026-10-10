import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/notification_data.dart';
import '../domain/entities/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirestoreNotificationRepository(ref.watch(firestoreProvider)),
);

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Stream.empty();
    return ref.watch(notificationRepositoryProvider).watch(user.uid);
  },
);

final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(user.uid);
});

/// Where tapping a notification leads.
String? routeForNotification(AppNotification n) {
  final id = n.relatedEntityId;
  if (id == null) return null;
  return switch (n.type) {
    NotificationType.recordingSubmitted ||
    NotificationType.recordingApproved ||
    NotificationType.recordingRejected ||
    NotificationType.recordingChangesRequested ||
    NotificationType.recordingPublished => Routes.recording(id),
    NotificationType.questionAnswered => Routes.question(id),
    NotificationType.newSubmissionForReview => Routes.adminReview(id),
    NotificationType.other => null,
  };
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final user = ref.watch(currentUserProvider);
    final repo = ref.read(notificationRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (list.value?.any((n) => !n.isRead) ?? false)
            TextButton(
              onPressed: () async {
                try {
                  await repo.markAllRead(user!.uid, list.value!);
                } on AppException catch (e) {
                  if (context.mounted) showAppSnack(context, e.message);
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: AsyncValueView(
        value: list,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) => items.isEmpty
            ? const EmptyView(
                icon: Icons.notifications_none,
                title: 'You’re all caught up',
                message:
                    'Updates about your recordings and questions will appear here.',
              )
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(indent: 72),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return ListTile(
                    minVerticalPadding: 12,
                    leading: CircleAvatar(
                      backgroundColor: n.isRead
                          ? AppColors.surfaceHigh
                          : AppColors.goldContainer,
                      child: Icon(
                        _icon(n.type),
                        color: n.isRead
                            ? AppColors.inkMuted
                            : AppColors.goldDeep,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: n.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${n.body}\n${formatRelative(n.createdAt)}',
                      style: context.text.bodySmall,
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      if (!n.isRead && user != null) {
                        try {
                          await repo.markRead(user.uid, n.id);
                        } on AppException catch (e) {
                          if (context.mounted) showAppSnack(context, e.message);
                        }
                      }
                      final route = routeForNotification(n);
                      if (route != null && context.mounted) context.push(route);
                    },
                  );
                },
              ),
      ),
    );
  }

  IconData _icon(NotificationType t) => switch (t) {
    NotificationType.recordingApproved ||
    NotificationType.recordingPublished => Icons.check_circle_outline,
    NotificationType.recordingRejected => Icons.block,
    NotificationType.recordingChangesRequested => Icons.edit_outlined,
    NotificationType.recordingSubmitted ||
    NotificationType.newSubmissionForReview => Icons.mic_none,
    NotificationType.questionAnswered => Icons.forum_outlined,
    NotificationType.other => Icons.notifications_none,
  };
}
