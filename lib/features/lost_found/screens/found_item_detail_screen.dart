import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/enums/lost_found_enums.dart';
import '../../../models/found_item.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/c_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/lost_found_providers.dart';

class FoundItemDetailScreen extends ConsumerWidget {
  const FoundItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(foundItemProvider(itemId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final claims = ref.watch(myClaimsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Found item')),
      body: AsyncValueView<FoundItem?>(
        value: item,
        onRetry: () => ref.invalidate(foundItemProvider(itemId)),
        data: (found) {
          if (found == null) {
            return const Center(child: Text('This report is no longer available.'));
          }

          final isMine = found.finderId == uid;
          final alreadyClaimed = claims.any(
            (c) => c.foundItemId == found.id && !c.isSettled,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              if (found.photoUrl != null && found.photoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: Radii.md,
                  child: Image.network(
                    found.photoUrl!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Gap.h16,
              Text(found.itemName, style: Theme.of(context).textTheme.headlineSmall),
              Gap.h8,
              Text(
                '${found.category.emoji} ${found.category.label}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Gap.h16,
              if (found.description.isNotEmpty) ...[
                Text(found.description),
                Gap.h16,
              ],
              _Fact(
                icon: Icons.place_outlined,
                label: 'Found at',
                value: found.locationName.isEmpty ? 'Not specified' : found.locationName,
              ),
              if (found.foundAt != null)
                _Fact(
                  icon: Icons.event_outlined,
                  label: 'Found on',
                  value: Fmt.relative(found.foundAt!),
                ),
              if (found.handoverNote.isNotEmpty)
                _Fact(
                  icon: Icons.inventory_2_outlined,
                  label: 'Where it is now',
                  value: found.handoverNote,
                ),
              _Fact(
                icon: Icons.person_outline,
                label: 'Reported by',
                value: found.finderName,
              ),
              Gap.h32,
              if (isMine)
                const _Notice(
                  icon: Icons.info_outline,
                  text: 'You reported this. Claims from other students will appear '
                      'in "My reports".',
                )
              else if (found.status == FoundItemStatus.returned)
                const _Notice(
                  icon: Icons.check_circle_outline,
                  text: 'This has already gone back to its owner.',
                )
              else if (alreadyClaimed)
                const _Notice(
                  icon: Icons.hourglass_top_outlined,
                  text: "You've claimed this. The finder will review it.",
                )
              else
                CButton(
                  label: 'This might be mine',
                  icon: Icons.pan_tool_alt_outlined,
                  onPressed: () => _startClaim(context, ref, found),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startClaim(BuildContext context, WidgetRef ref, FoundItem found) async {
    final proof = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClaimSheet(itemName: found.itemName),
    );
    if (proof == null || !context.mounted) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lostFoundRepositoryProvider).claimFoundItem(
            foundItem: found,
            claimantId: user.uid,
            claimantName: user.displayName.isEmpty ? 'A student' : user.displayName,
            proof: proof,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Claim sent. The finder will check your description.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    }
  }
}

/// Asks for proof before a claim can be sent.
///
/// Deliberately not a plain "Claim" button: anyone can tap a button, so the
/// finder would have nothing to judge. Describing a detail that isn't in the
/// public photo is the only check available without a server.
class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet({required this.itemName});

  final String itemName;

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Give a specific detail — a few words is not enough.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        top: Gap.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prove it\'s yours', style: theme.textTheme.titleLarge),
          Gap.h8,
          Text(
            'Describe something about "${widget.itemName}" that is not in the photo. '
            'Only the finder sees this.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          Gap.h16,
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'There is a torn photo of a dog inside',
              errorText: _error,
            ),
          ),
          Gap.h16,
          CButton(label: 'Send claim', icon: Icons.send_rounded, onPressed: _submit),
          Gap.h8,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.hintColor),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.hintColor),
          Gap.w12,
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
