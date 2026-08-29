/// 登录页：用户名 + 密码 → typ=admin JWT（存 sessionStorage）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../app/admin_auth.dart';

enum LoginPhase { idle, submitting, error }

class LoginState {
  const LoginState({this.phase = LoginPhase.idle, this.message});

  final LoginPhase phase;
  final String? message;

  LoginState copyWith({LoginPhase? phase, String? message}) =>
      LoginState(phase: phase ?? this.phase, message: message);
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> submit(String username, String password) async {
    if (state.phase == LoginPhase.submitting) return;
    state = const LoginState(phase: LoginPhase.submitting);
    try {
      final token = await ref.read(adminApiProvider).login(username, password);
      // token 写回唯一所有者 AdminAuth → refreshListenable 推 router 回工作台
      await ref.read(adminAuthProvider).signIn(token);
      if (!ref.mounted) return;
      state = const LoginState(phase: LoginPhase.idle);
    } on ApiFailure catch (e) {
      if (!ref.mounted) return;
      state = LoginState(phase: LoginPhase.error, message: e.message);
    }
  }
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final submitting = state.phase == LoginPhase.submitting;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '风信 · 运营控制台',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _username,
                    enabled: !submitting,
                    decoration: const InputDecoration(labelText: '用户名'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !submitting,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  if (state.phase == LoginPhase.error)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.message ?? '登录失败',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: submitting ? null : _submit,
                    child: Text(submitting ? '登录中…' : '登录'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '账号由 create_admin.py 创建，与匿名用户体系隔离',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    ref
        .read(loginControllerProvider.notifier)
        .submit(_username.text.trim(), _password.text);
  }
}
