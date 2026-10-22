import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moduleup/core/result.dart';
import 'package:moduleup/core/theme.dart';
import 'package:moduleup/data/auth_service.dart';
import 'package:moduleup/data/progress.dart';
import 'package:moduleup/data/progress_repository.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Shows the failure, or continues to [next] on success.
Future<void> _run(
  BuildContext context,
  Future<AuthResult> call, {
  String next = '/',
}) async {
  final result = await call;
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      context.go(next);
    case Err(:final failure):
      if (failure.code != FailureCode.cancelled) {
        _snack(context, failure.message);
      }
  }
}

/// Guests may try one practice set; anything more needs an account.
bool requireAccount(
  BuildContext context,
  WidgetRef ref, {
  bool forPaper = false,
}) {
  final user = ref.read(authStateProvider).value;
  final progress = ref.read(progressProvider).value ?? ProgressSnapshot.empty;
  if (user == null || !user.isGuest || (!forPaper && progress.drills.isEmpty)) {
    return true;
  }
  unawaited(
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Create your free account'),
        content: const Text(
          'Sign in with Google or email to keep practising, take the full papers and keep your '
          'progress on any phone. What you have done so far is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              unawaited(context.push('/signin'));
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    ),
  );
  return false;
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpace.l),
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 72,
                  color: AppColors.accent,
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  'Module Up',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                const Text(
                  'Digital SAT® Reading and Writing practice: 10 full adaptive papers, '
                  'skill drills and a progress board.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.xl),
                FilledButton.icon(
                  onPressed: () =>
                      unawaited(_run(context, auth.signInWithGoogle())),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: AppSpace.s),
                OutlinedButton.icon(
                  onPressed: () => context.push('/signin'),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Use email and password'),
                ),
                const SizedBox(height: AppSpace.s),
                TextButton(
                  onPressed: () => unawaited(
                    _run(context, auth.continueAsGuest(), next: '/setup'),
                  ),
                  child: const Text('Try one practice set first'),
                ),
                const SizedBox(height: AppSpace.l),
                const Text(
                  'SAT® is a trademark registered by the College Board, which is not affiliated '
                  'with, and does not endorse, this app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Email sign-in and account creation (also upgrades a guest in place).
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});
  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _create = ref.read(authStateProvider).value?.isGuest ?? false;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    await _run(
      context,
      _create
          ? auth.registerWithEmail(_email.text, _password.text)
          : auth.signInWithEmail(_email.text, _password.text),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    if (!_email.text.contains('@')) {
      _snack(context, 'Type your email address first.');
      return;
    }
    final r = await ref
        .read(authServiceProvider)
        .sendPasswordReset(_email.text);
    if (!mounted) return;
    _snack(context, switch (r) {
      Ok() => 'Check your email for a link to reset your password.',
      Err(:final failure) => failure.message,
    });
  }

  @override
  Widget build(BuildContext context) {
    final guest = ref.watch(authStateProvider).value?.isGuest ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(_create ? 'Create account' : 'Sign in')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.l),
          children: [
            if (guest)
              FilledButton.icon(
                onPressed: () => unawaited(
                  _run(
                    context,
                    ref.read(authServiceProvider).signInWithGoogle(),
                  ),
                ),
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
            if (guest)
              const Padding(
                padding: EdgeInsets.all(AppSpace.m),
                child: Text('or', textAlign: TextAlign.center),
              ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Enter your email address',
            ),
            const SizedBox(height: AppSpace.m),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: [
                if (_create)
                  AutofillHints.newPassword
                else
                  AutofillHints.password,
              ],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
                  (v ?? '').length >= 8 ? null : 'At least 8 characters',
              onFieldSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: AppSpace.l),
            FilledButton(
              onPressed: _busy ? null : () => unawaited(_submit()),
              child: Text(_create ? 'Create account' : 'Sign in'),
            ),
            if (!_create)
              TextButton(
                onPressed: () => unawaited(_reset()),
                child: const Text('Forgot password?'),
              ),
            TextButton(
              onPressed: () => setState(() => _create = !_create),
              child: Text(
                _create
                    ? 'I already have an account'
                    : 'New here? Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First run: name, target score, test date, weekly goal. Also used to edit.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final StudentProfile _initial =
      ref.read(progressProvider).value?.profile ??
      StudentProfile(
        name:
            ref.read(authStateProvider).value?.displayName?.split(' ').first ??
            '',
        targetScore: 650,
      );
  late final _name = TextEditingController(text: _initial.name);
  late double _target = _initial.targetScore.toDouble();
  late DateTime? _date = _initial.testDate;
  late double _goal = _initial.weeklyGoal.toDouble();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 60)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final profile = StudentProfile(
      name: _name.text.trim(),
      targetScore: _target.round(),
      testDate: _date,
      weeklyGoal: _goal.round(),
    );
    await ref.read(progressRepositoryProvider)?.saveProfile(profile);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About you')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.l),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'First name'),
        ),
        const SizedBox(height: AppSpace.l),
        Text('Target Reading and Writing score: ${_target.round()}'),
        Slider(
          value: _target,
          min: 400,
          max: 800,
          divisions: 40,
          label: '${_target.round()}',
          onChanged: (v) => setState(() => _target = v),
        ),
        const SizedBox(height: AppSpace.m),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Test date'),
          subtitle: Text(
            _date == null
                ? 'Not set'
                : MaterialLocalizations.of(context).formatMediumDate(_date!),
          ),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () => unawaited(_pickDate()),
        ),
        const SizedBox(height: AppSpace.m),
        Text('Weekly goal: ${_goal.round()} questions'),
        Slider(
          value: _goal,
          min: 30,
          max: 300,
          divisions: 27,
          label: '${_goal.round()}',
          onChanged: (v) => setState(() => _goal = v),
        ),
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          onPressed: () => unawaited(_save()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
