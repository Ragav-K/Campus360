import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/c_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Shared controller — see the same note in RegisterScreen.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(authControllerProvider.notifier).clearError(),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text);
    // On success the router's redirect moves us to /pulse; nothing to do here.
    if (!ok && mounted) setState(() {}); // surface the banner
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final loading = state.isLoading;

    return AuthScaffold(
      showBack: false,
      title: 'Welcome back',
      subtitle: 'Sign in to see what’s happening on campus.',
      failure: controller.failure,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'College email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                // Domain is not enforced at sign-in — only at registration.
                validator: (v) => Validators.email(v),
              ),
              Gap.h16,
              TextFormField(
                controller: _password,
                enabled: !loading,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => Validators.required(v, field: 'Password'),
              ),
            ],
          ),
        ),
        Gap.h8,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading ? null : () => context.push(Routes.forgotPassword),
            child: const Text('Forgot password?'),
          ),
        ),
        Gap.h8,
        CButton(label: 'Sign in', loading: loading, onPressed: _submit),
        Gap.h16,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here?', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: loading ? null : () => context.push(Routes.register),
              child: const Text('Create an account'),
            ),
          ],
        ),
        Gap.h8,
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Text('or', style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        Gap.h16,
        // Visiting campus? Browse without an account (anonymous auth).
        CButton(
          label: 'Continue as guest',
          icon: Icons.person_outline_rounded,
          variant: CButtonVariant.outlined,
          onPressed: loading
              ? null
              : () async {
                  final ok = await ref.read(authControllerProvider.notifier).continueAsGuest();
                  if (!ok && mounted) setState(() {}); // surface the banner
                },
        ),
        Gap.h8,
        Text(
          'Guests can use the whole app. Your reports and orders stay on this '
          'device until you create an account.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
