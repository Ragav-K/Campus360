import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/enums/lost_found_enums.dart';
import '../../../models/found_item.dart';
import '../../../models/lost_item.dart';
import '../../../widgets/c_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/lost_found_providers.dart';

/// One screen for both directions of reporting.
///
/// Lost and found reports ask for almost the same things, and two near-copies
/// would drift apart. The differences are held in [isLost] rather than in two
/// files: the wording, the date question, and the ownership secret — which only
/// a lost report has.
class ReportItemScreen extends ConsumerStatefulWidget {
  const ReportItemScreen({super.key, required this.isLost});

  final bool isLost;

  @override
  ConsumerState<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends ConsumerState<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _handover = TextEditingController();
  final _secret = TextEditingController();

  ItemCategory _category = ItemCategory.other;
  DateTime? _when;
  File? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _place.dispose();
    _handover.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80, // a print-quality photo of a lost umbrella helps nobody
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date != null) setState(() => _when = date);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);

    try {
      final repo = ref.read(lostFoundRepositoryProvider);
      final name = user.displayName.isEmpty ? 'A student' : user.displayName;

      if (widget.isLost) {
        await repo.reportLost(
          item: LostItem(
            id: '',
            ownerId: user.uid,
            ownerName: name,
            itemName: _name.text.trim(),
            category: _category,
            description: _description.text.trim(),
            locationName: _place.text.trim(),
            lostAt: _when,
            createdAt: DateTime.now(),
          ),
          identifyingDetails: _secret.text,
          photo: _photo,
        );
      } else {
        await repo.reportFound(
          item: FoundItem(
            id: '',
            finderId: user.uid,
            finderName: name,
            itemName: _name.text.trim(),
            category: _category,
            description: _description.text.trim(),
            locationName: _place.text.trim(),
            handoverNote: _handover.text.trim(),
            foundAt: _when,
            createdAt: DateTime.now(),
          ),
          photo: _photo,
        );
      }

      if (!mounted) return;
      router.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.isLost
              ? "Reported. We'll show you anything that looks like it."
              : 'Thanks for reporting it — the owner can now find you.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLost = widget.isLost;

    return Scaffold(
      appBar: AppBar(title: Text(isLost ? 'Report something lost' : 'Report something found')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
          children: [
            _PhotoPicker(
              photo: _photo,
              category: _category,
              onPick: _pickPhoto,
              onClear: () => setState(() => _photo = null),
              hint: isLost
                  ? 'A photo helps others recognise it.'
                  : 'A photo is the fastest way for the owner to spot it.',
            ),
            Gap.h24,

            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What is it?',
                hintText: 'Black leather wallet',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Give it a short name.' : null,
            ),
            Gap.h16,

            Text('Category', style: theme.textTheme.labelLarge),
            Gap.h8,
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final category in ItemCategory.values)
                  ChoiceChip(
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                    avatar: Text(category.emoji),
                    label: Text(category.label),
                  ),
              ],
            ),
            Gap.h16,

            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: isLost
                    ? 'Brown strap, slightly torn at the corner'
                    : 'What it looks like — colour, brand, condition',
                alignLabelWithHint: true,
              ),
            ),
            Gap.h16,

            TextFormField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isLost ? 'Where do you think you lost it?' : 'Where did you find it?',
                hintText: 'Library, second floor',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            Gap.h16,

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(isLost ? 'When did you lose it?' : 'When did you find it?'),
              subtitle: Text(
                _when == null
                    ? 'Not sure — that\'s fine'
                    : '${_when!.day}/${_when!.month}/${_when!.year}',
              ),
              trailing: TextButton(
                onPressed: _pickWhen,
                child: Text(_when == null ? 'Pick a date' : 'Change'),
              ),
            ),

            if (!isLost) ...[
              Gap.h16,
              TextFormField(
                controller: _handover,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Where is it now?',
                  hintText: 'Left at the library desk',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  helperText: 'Often more useful to the owner than your name.',
                ),
              ),
            ],

            if (isLost) ...[
              Gap.h24,
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.primary),
                          Gap.w8,
                          Text('Something only you would know',
                              style: theme.textTheme.titleSmall),
                        ],
                      ),
                      Gap.h8,
                      Text(
                        'Kept private. Nobody browsing can see this — it is how you '
                        'prove the item is yours when you claim it.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                      Gap.h12,
                      TextFormField(
                        controller: _secret,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'There is a torn photo of a dog inside',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            Gap.h32,
            CButton(
              label: isLost ? 'Report it lost' : 'Report it found',
              icon: Icons.send_rounded,
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.category,
    required this.onPick,
    required this.onClear,
    required this.hint,
  });

  final File? photo;
  final ItemCategory category;
  final void Function(ImageSource) onPick;
  final VoidCallback onClear;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (photo != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: Radii.md,
            child: Image.file(photo!, height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.sm),
            child: IconButton.filled(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Remove photo',
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: Radii.md,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 34)),
          Gap.h8,
          Text(hint, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          Gap.h12,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
              Gap.w12,
              TextButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
