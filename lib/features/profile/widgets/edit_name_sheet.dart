import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/c_button.dart';
import '../../auth/providers/auth_providers.dart';

Future<void> showEditNameSheet(BuildContext context, WidgetRef ref, {required String current}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _EditNameSheet(current: current),
    ),
  );
}

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.current});
  final String current;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.current);
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final ok = await ref.read(authControllerProvider.notifier).updateName(_controller.text);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      return;
    }

    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(authControllerProvider.notifier).failure?.message ??
              'Couldn\'t save your name.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your name', style: Theme.of(context).textTheme.titleMedium),
              Gap.h4,
              Text(
                'Shown on your reports and print orders, so staff know who to '
                'hand things to.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Gap.h16,
              TextFormField(
                controller: _controller,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: Validators.name,
              ),
              Gap.h24,
              CButton(label: 'Save', loading: _busy, onPressed: _save),
              Gap.h8,
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
