import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/auth_service.dart';
import 'package:moduleup/data/progress_repository.dart';
import 'package:moduleup/features/auth/auth_screens.dart';
import 'package:moduleup/features/guides/guides_screen.dart';
import 'package:moduleup/features/home/home_screen.dart';
import 'package:moduleup/features/paper/papers_screen.dart';
import 'package:moduleup/features/paper/review_screen.dart';
import 'package:moduleup/features/paper/score_report_screen.dart';
import 'package:moduleup/features/paper/test_screen.dart';
import 'package:moduleup/features/practice/drill_screen.dart';
import 'package:moduleup/features/practice/practice_screen.dart';
import 'package:moduleup/features/practice/skill_screen.dart';
import 'package:moduleup/features/progress/progress_screen.dart';
import 'package:moduleup/features/settings/settings_screen.dart';

/// Re-runs router redirects when sign-in or profile state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref
      ..listen(authStateProvider, (_, _) => notifyListeners())
      ..listen(
        progressProvider.select((p) => p.value?.profile != null),
        (_, _) => notifyListeners(),
      );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final user = auth.value;
      final loc = state.matchedLocation;
      final open = loc == '/welcome' || loc == '/signin';
      if (user == null) return open ? null : '/welcome';
      final progress = ref.read(progressProvider);
      if (loc == '/welcome') return '/';
      if (progress.hasValue &&
          progress.value!.profile == null &&
          loc != '/setup' &&
          loc != '/signin') {
        return '/setup';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const EmailAuthScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practice',
                builder: (_, _) => const PracticeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (_, _) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/guides', builder: (_, _) => const GuidesScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/practice/:type',
        builder: (_, s) => SkillScreen(type: s.pathParameters['type']!),
      ),
      GoRoute(path: '/drill', builder: (_, _) => const DrillScreen()),
      GoRoute(path: '/papers', builder: (_, _) => const PapersScreen()),
      GoRoute(
        path: '/paper/result',
        builder: (_, _) => const ScoreReportScreen(),
      ),
      GoRoute(
        path: '/paper/:id',
        builder: (_, s) => PaperIntroScreen(formId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/test', builder: (_, _) => const TestScreen()),
      GoRoute(
        path: '/attempt/:id',
        builder: (_, s) => ScoreReportScreen(formId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/review/:id',
        builder: (_, s) => ReviewScreen(formId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/guides/:key',
        builder: (_, s) => GuideScreen(guide: s.pathParameters['key']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  static const _titles = ['Module Up', 'Practice', 'Progress', 'Guides'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_titles[shell.currentIndex]),
      actions: [
        IconButton(
          tooltip: 'Account and settings',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    ),
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: 'Practice',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights),
          label: 'Progress',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Guides',
        ),
      ],
    ),
  );
}

class ModuleUpApp extends ConsumerWidget {
  const ModuleUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Module Up',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}
