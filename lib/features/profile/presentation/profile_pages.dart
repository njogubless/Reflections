import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../qa/presentation/qa_providers.dart';
import '../../recording/presentation/providers/recording_providers.dart';
import '../../sermons/presentation/controllers/audio_player_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());
    final submissions = ref.watch(mySubmissionsProvider).value?.length;
    final questions = ref.watch(myQuestionsProvider).value?.length;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.page,
        title: const BrandTitle(section: 'Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.firstName.characters.first.toUpperCase(),
                    style: context.text.headlineMedium?.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isEmpty ? 'Member' : user.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineSmall,
                      ),
                      Text(
                        user.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      if (user.role != UserRole.user)
                        Chip(
                          avatar: const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.teal,
                          ),
                          label: Text(
                            user.role.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => context.push(Routes.editProfile),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          if (!user.emailVerified) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              color: AppColors.pendingBg,
              border: false,
              child: Row(
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.pending,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text('Please verify your email address.'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .sendEmailVerification();
                        if (context.mounted) {
                          showAppSnack(context, 'Verification email sent.');
                        }
                      } on AppException catch (e) {
                        if (context.mounted) showAppSnack(context, e.message);
                      }
                    },
                    child: const Text('Resend'),
                  ),
                ],
              ),
            ),
          ],
          if (user.isAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            HeroCard(
              onTap: () => context.push(Routes.admin),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Admin workspace',
                      style: context.text.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('MY CONTENT', style: context.devotionText.overline),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mic_none),
                  title: const Text('My recordings'),
                  subtitle: submissions == null
                      ? null
                      : Text('$submissions submitted'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.myRecordings),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('My questions'),
                  subtitle: questions == null ? null : Text('$questions asked'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.myQuestions),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.notifications),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('ACCOUNT', style: context.devotionText.overline),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change password'),
                  subtitle: const Text('We’ll email you a reset link'),
                  onTap: () async {
                    final email = user.email;
                    if (email == null) return;
                    try {
                      await ref
                          .read(authRepositoryProvider)
                          .sendPasswordReset(email);
                      if (context.mounted) {
                        showAppSnack(context, 'Reset link sent to $email.');
                      }
                    } on AppException catch (e) {
                      if (context.mounted) showAppSnack(context, e.message);
                    }
                  },
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Refresh account permissions'),
                  subtitle: const Text('Use after a role change'),
                  onTap: () async {
                    try {
                      await ref.read(authRepositoryProvider).refreshClaims();
                      if (context.mounted) {
                        showAppSnack(context, 'Account refreshed.');
                      }
                    } on AppException catch (e) {
                      if (context.mounted) showAppSnack(context, e.message);
                    }
                  },
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.changes),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: AppColors.changes),
                  ),
                  onTap: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Sign out?',
                      message:
                          'Drafts stay on this device and will be here when you return.',
                      confirmLabel: 'Sign out',
                    );
                    if (!ok) return;
                    await ref
                        .read(audioPlayerControllerProvider.notifier)
                        .stop();
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                    } on AppException catch (e) {
                      if (context.mounted) showAppSnack(context, e.message);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: LogoEmblem(size: 48)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Devotion — Reflections of Faith',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(currentUserProvider)?.displayName,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(_name.text);
      if (mounted) context.pop();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (v) =>
                Validators.required(v, field: 'Name') ??
                Validators.maxLength(v, 80),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_error != null) ...[
            InlineError(_error!),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
