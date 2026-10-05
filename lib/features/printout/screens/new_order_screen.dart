import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/enums/print_enums.dart';
import '../../../models/print_shop.dart';
import '../../../repositories/print_repository.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/print_providers.dart';
import '../widgets/deadline_picker.dart';

/// Place a print order: file, settings, deadline, shop, done.
///
/// One screen rather than a four-step wizard — §35 asks for speed, and paging
/// through four screens to print lecture notes is slower than scrolling one.
class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  bool _placing = false;

  Future<void> _pickFile() async {
    final maxBytes = ref.read(remoteConfigValueProvider).maxDocumentBytes;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Static in file_picker 11; `FilePicker.platform` was the v8 API.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return; // cancelled

      final picked = result.files.first;
      final path = picked.path;
      if (path == null) return;

      final failure = PrintRepository.validateDocument(
        fileName: picked.name,
        sizeBytes: picked.size,
        maxBytes: maxBytes,
      );
      if (failure != null) {
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
        return;
      }

      ref.read(orderDraftProvider.notifier).setFile(
            file: File(path),
            name: picked.name,
            sizeBytes: picked.size,
            // Page count needs a PDF parser; until then the cost estimate
            // honestly reports "not known" rather than guessing.
            pageCount: null,
          );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    }
  }

  Future<void> _place() async {
    final draft = ref.read(orderDraftProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (!draft.isReadyToPlace || user == null) return;

    setState(() => _placing = true);
    ref.read(uploadProgressProvider.notifier).state = 0;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final id = await ref.read(printRepositoryProvider).placeOrder(
            studentId: user.uid,
            studentName: user.displayName.isEmpty ? user.email : user.displayName,
            studentPhone: user.phone,
            shop: draft.shop!,
            file: draft.file!,
            fileName: draft.fileName!,
            mimeType: PrintRepository.mimeTypeFor(draft.fileName!),
            pageCount: draft.pageCount,
            settings: draft.settings,
            neededBy: draft.neededBy,
            onUploadProgress: (p) => ref.read(uploadProgressProvider.notifier).state = p,
          );

      ref.read(orderDraftProvider.notifier).reset();
      if (mounted) context.pushReplacement(Routes.printOrder(id));
    } catch (e) {
      if (mounted) {
        setState(() => _placing = false);
        messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
      }
    } finally {
      ref.read(uploadProgressProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(orderDraftProvider);
    final shops = ref.watch(printShopsProvider);
    final progress = ref.watch(uploadProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New print order')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 120),
        children: [
          const _StepLabel('1. Document'),
          _FileCard(draft: draft, onPick: _pickFile),

          Gap.h24,
          const _StepLabel('2. How to print it'),
          _SettingsCard(draft: draft),

          Gap.h24,
          const _StepLabel('3. When do you need it?'),
          DeadlinePicker(
            value: draft.neededBy,
            onChanged: (when) => ref.read(orderDraftProvider.notifier).setNeededBy(when),
          ),

          Gap.h24,
          const _StepLabel('4. Which shop'),
          _ShopPicker(shops: shops, selected: draft.shop),

          if (draft.estimatedCost != null) ...[
            Gap.h24,
            _CostCard(draft: draft),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress != null) ...[
                LinearProgressIndicator(value: progress),
                Gap.h8,
                Text('Uploading ${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall),
                Gap.h8,
              ],
              CButton(
                label: 'Place order',
                icon: Icons.send_rounded,
                loading: _placing,
                onPressed: draft.isReadyToPlace ? _place : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: Radii.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.all(Gap.lg),
          child: child,
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.draft, required this.onPick});
  final OrderDraft draft;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Card(
      onTap: onPick,
      child: Row(
        children: [
          Icon(
            draft.hasFile ? Icons.description_rounded : Icons.upload_file_rounded,
            size: 28,
            color: theme.colorScheme.primary,
          ),
          Gap.w16,
          Expanded(
            child: draft.hasFile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.fileName!,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(Fmt.fileSize(draft.sizeBytes ?? 0), style: theme.textTheme.bodySmall),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose a file', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      Text('PDF, JPG or PNG', style: theme.textTheme.bodySmall),
                    ],
                  ),
          ),
          if (draft.hasFile) const Icon(Icons.edit_outlined, size: 19),
        ],
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.draft});
  final OrderDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = draft.settings;
    final shop = draft.shop;
    final controller = ref.read(orderDraftProvider.notifier);

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Copies')),
              IconButton.filledTonal(
                onPressed: settings.copies > 1
                    ? () => controller.setSettings(settings.copyWith(copies: settings.copies - 1))
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${settings.copies}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                onPressed: settings.copies < 50
                    ? () => controller.setSettings(settings.copyWith(copies: settings.copies + 1))
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const Divider(height: Gap.xl),
          _Choice<PrintColour>(
            label: 'Colour',
            value: settings.colour,
            options: {
              PrintColour.bw: 'B&W',
              // Hidden entirely when the shop can't do it, rather than offered
              // and then rejected.
              if (shop?.supportsColour ?? true) PrintColour.colour: 'Colour',
            },
            onChanged: (v) => controller.setSettings(settings.copyWith(colour: v)),
          ),
          Gap.h12,
          _Choice<PrintSides>(
            label: 'Sides',
            value: settings.sides,
            options: {
              PrintSides.single: '1-sided',
              if (shop?.supportsDuplex ?? true) PrintSides.double: '2-sided',
            },
            onChanged: (v) => controller.setSettings(settings.copyWith(sides: v)),
          ),
        ],
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        SegmentedButton<T>(
          segments: [
            for (final entry in options.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

class _ShopPicker extends ConsumerWidget {
  const _ShopPicker({required this.shops, required this.selected});

  final AsyncValue<List<PrintShop>> shops;
  final PrintShop? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return shops.when(
      loading: () => const SkeletonCard(lines: 1),
      error: (_, __) => const EmptyState(
        icon: Icons.print_disabled_rounded,
        title: 'Couldn\'t load print shops',
        message: 'Check your connection and try again.',
        compact: true,
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.print_disabled_rounded,
            title: 'No print shops yet',
            message: 'None have been set up for this campus.',
            compact: true,
          );
        }
        return Column(
          children: [
            for (final shop in list) ...[
              _ShopTile(
                shop: shop,
                selected: shop.id == selected?.id,
                onTap: shop.isOpen ? () => ref.read(orderDraftProvider.notifier).setShop(shop) : null,
              ),
              Gap.h8,
            ],
          ],
        );
      },
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop, required this.selected, this.onTap});

  final PrintShop shop;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      borderRadius: Radii.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
          ),
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        shop.locationName,
                        shop.statusLabel,
                        if (shop.estimatedWaitMinutes != null)
                          '~${shop.estimatedWaitMinutes} min wait',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!shop.isOpen)
                Text('Closed', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({required this.draft});
  final OrderDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimated cost', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                // Named an estimate because the page count and the shop's
                // final pricing can both differ.
                Text('The shop confirms the final price', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${draft.shop?.currency ?? '₹'}${draft.estimatedCost!.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
