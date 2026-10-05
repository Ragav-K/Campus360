import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/c_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // The auth controller is shared with the sign-in screen; drop anything it
    // is still holding so a stale error doesn't greet a new arrival.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(authControllerProvider.notifier).clearError(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authControllerProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account created. We sent a verification link to ${_email.text.trim()}.')),
      );
      // Router redirect takes over from here.
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final config = ref.watch(remoteConfigValueProvider);
    final loading = state.isLoading;

    final domains = config.enforcedDomains;
    final domainHint = domains.isEmpty
        ? 'Use the email you check most often.'
        : 'Use your ${domains.map((d) => '@${d.replaceFirst('@', '')}').join(' or ')} address.';

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Campus360 is for students and staff of this campus.',
      failure: controller.failure,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                enabled: !loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: Validators.name,
              ),
              Gap.h16,
              TextFormField(
                controller: _email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'College email',
                  helperText: domainHint,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                // Enforced again server-side in the Auth onCreate trigger (§26).
                validator: (v) => Validators.email(v, allowedDomains: domains),
              ),
              Gap.h16,
              TextFormField(
                controller: _password,
                enabled: !loading,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters, with a letter and a number.',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: Validators.password,
              ),
              Gap.h16,
              TextFormField(
                controller: _confirm,
                enabled: !loading,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (v) => Validators.confirmPassword(v, _password.text),
              ),
            ],
          ),
        ),
        Gap.h24,
        CButton(label: 'Create account', loading: loading, onPressed: _submit),
        Gap.h16,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already registered?', style: Theme.of(context).textTheme.bodySmall),
            TextButton(onPressed: loading ? null : () => context.pop(), child: const Text('Sign in')),
          ],
        ),
      ],
    );
  }
}
