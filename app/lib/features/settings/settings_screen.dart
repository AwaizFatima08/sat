import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/result.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/auth_service.dart';
import 'package:moduleup/data/content_bank.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyUrl = 'https://tools.homilabs.org/moduleup/privacy-policy.html';
const deletionUrl = 'https://tools.homilabs.org/moduleup/delete-account.html';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final guest = user?.isGuest ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Account and settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              guest
                  ? 'Guest'
                  : (user?.email ?? user?.displayName ?? 'Signed in'),
            ),
            subtitle: Text(
              guest
                  ? 'Create an account to keep your progress on any phone.'
                  : 'Your progress syncs to this account.',
            ),
          ),
          if (guest)
            ListTile(
              leading: const Icon(Icons.how_to_reg_outlined),
              title: const Text('Create account / sign in'),
              onTap: () => context.push('/signin'),
            ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Target score, test date, weekly goal'),
            onTap: () => context.push('/setup'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Module Up'),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => unawaited(launchUrl(Uri.parse(privacyUrl))),
          ),
          const Divider(),
          if (!guest)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/welcome');
              },
            ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: AppColors.wrong,
            ),
            title: const Text(
              'Delete account and data',
              style: TextStyle(color: AppColors.wrong),
            ),
            onTap: () => unawaited(_delete(context, ref)),
          ),
        ],
      ),
    );
  }

  static Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'This permanently deletes your account, your scores, practice history and mistake '
          'notebook. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.wrong),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(progressRepositoryProvider)?.deleteAll();
    final r = await ref.read(authServiceProvider).deleteUser();
    if (!context.mounted) return;
    switch (r) {
      case Ok():
        context.go('/welcome');
      case Err(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
        if (failure.code == FailureCode.requiresRecentLogin) {
          await ref.read(authServiceProvider).signOut();
          if (context.mounted) context.go('/welcome');
        }
    }
  }
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(contentBankProvider).value?.version ?? '';
    final items = ref.watch(contentBankProvider).value?.items.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.l),
        children: [
          Text(
            'Module Up: Digital SAT Prep',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.s),
          Text('Content release $version · $items questions'),
          const SizedBox(height: AppSpace.l),
          const Text(
            'Every question, passage, explanation and lesson in this app is original work by HomiLabs, '
            'written in the style of the Digital SAT. No College Board material is used. Short '
            'literary excerpts, where used, come from public-domain works and are credited.',
          ),
          const SizedBox(height: AppSpace.m),
          const Text(
            'Scores are estimates based on Module Up questions. They are not official SAT scores.',
          ),
          const SizedBox(height: AppSpace.m),
          const Text(
            'SAT® is a trademark registered by the College Board, which is not affiliated with, '
            'and does not endorse, this app.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpace.l),
          const Text(
            'Made by HomiLabs · tools.homilabs.org',
            style: TextStyle(color: AppColors.muted),
          ),
          TextButton(
            onPressed: () => unawaited(launchUrl(Uri.parse(deletionUrl))),
            child: const Text('Delete your account from the web'),
          ),
        ],
      ),
    );
  }
}
