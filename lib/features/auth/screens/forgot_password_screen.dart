import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

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
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);
    if (mounted) setState(() => _sent = ok);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    if (_sent) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Check your inbox',
                  message: 'If an account exists for ${_email.text.trim()}, a reset link is on its way. '
                      'It can take a minute — remember to look in spam.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: CButton(label: 'Back to sign in', onPressed: () => context.pop()),
              ),
            ],
          ),
        ),
      );
    }

    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'We’ll email you a link to set a new one.',
      failure: controller.failure,
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _email,
            enabled: !state.isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'College email',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (v) => Validators.email(v),
          ),
        ),
        Gap.h24,
        CButton(label: 'Send reset link', loading: state.isLoading, onPressed: _submit),
      ],
    );
  }
}
