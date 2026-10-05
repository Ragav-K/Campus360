import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/claim.dart';
import '../../../models/enums/lost_found_enums.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/lost_found_providers.dart';
import '../widgets/found_item_card.dart';

/// Everything the student has reported, plus the claims they must act on.
///
/// Claims come first: a claim waiting on you is the only thing here that blocks
/// somebody else getting their belongings back.
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final claims = ref.watch(myClaimsProvider).valueOrNull ?? const [];
    final myLost = ref.watch(myLostItemsProvider).valueOrNull ?? const [];
    final myFound = ref.watch(myFoundItemsProvider).valueOrNull ?? const [];

    final needsMyDecision =
        claims.where((c) => c.finderId == uid && c.status == ClaimStatus.pending).toList();
    final mine = claims.where((c) => c.claimantId == uid && !c.isSettled).toList();
    final handovers = claims.where((c) => c.awaitingHandover).toList();

    final nothingAtAll =
        claims.isEmpty && myLost.isEmpty && myFound.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: nothingAtAll
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: "You haven't reported anything",
              message: 'Anything you report lost or found shows up here, '
                  'along with any claims.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
              children: [
                if (needsMyDecision.isNotEmpty) ...[
                  const _Header('Waiting for you', subtitle: 'Someone says one of your finds is theirs'),
                  Gap.h12,
                  for (final claim in needsMyDecision) ...[
                    _DecisionCard(claim: claim),
                    Gap.h12,
                  ],
                  Gap.h16,
                ],
                if (handovers.isNotEmpty) ...[
                  const _Header('Handover', subtitle: 'Both of you confirm once it changes hands'),
                  Gap.h12,
                  for (final claim in handovers) ...[
                    _HandoverCard(claim: claim, uid: uid ?? ''),
                    Gap.h12,
                  ],
                  Gap.h16,
                ],
                if (mine.isNotEmpty) ...[
                  const _Header('Your claims'),
                  Gap.h12,
                  for (final claim in mine) ...[
                    _ClaimStatusCard(claim: claim),
                    Gap.h12,
                  ],
                  Gap.h16,
                ],
                if (myLost.isNotEmpty) ...[
                  const _Header('Things you lost'),
                  Gap.h12,
                  for (final item in myLost)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(item.category.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(item.itemName),
                      subtitle: Text('${item.status.label} · ${Fmt.relative(item.createdAt)}'),
                      onTap: () => context.push(Routes.lostDetail(item.id)),
                    ),
                  Gap.h16,
                ],
                if (myFound.isNotEmpty) ...[
                  const _Header('Things you found'),
                  Gap.h12,
                  for (final item in myFound) ...[
                    FoundItemCard(
                      item: item,
                      onTap: () => context.push(Routes.foundDetail(item.id)),
                    ),
                    Gap.h12,
                  ],
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle != null)
          Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}

/// The finder judging a claim. Shows the claimant's proof — the only thing
/// separating a real owner from someone who liked the photo.
class _DecisionCard extends ConsumerStatefulWidget {
  const _DecisionCard({required this.claim});

  final Claim claim;

  @override
  ConsumerState<_DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends ConsumerState<_DecisionCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final messenger = ScaffoldMessenger.of(context);
    String? reason;

    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectDialog(),
      );
      if (reason == null) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(lostFoundRepositoryProvider).decideClaim(
            claimId: widget.claim.id,
            approve: approve,
            rejectionReason: reason,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve
              ? 'Approved. Arrange to hand it over, then both confirm.'
              : 'Claim declined.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final claim = widget.claim;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(claim.itemName, style: theme.textTheme.titleMedium),
            Text(
              '${claim.claimantName} says this is theirs',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            Gap.h12,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: Radii.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Their description',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                  Gap.h4,
                  Text(claim.proof, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Gap.h12,
            Text(
              'Does that match something only the owner would know?',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            Gap.h12,
            Row(
              children: [
                Expanded(
                  child: CButton(
                    label: 'Not a match',
                    variant: CButtonVariant.outlined,
                    onPressed: _busy ? null : () => _decide(false),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: CButton(
                    label: "That's them",
                    loading: _busy,
                    onPressed: () => _decide(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Decline this claim?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A short reason helps them understand — they may have '
                'described the wrong item.'),
            Gap.h12,
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: "The description doesn't match"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _controller.text.trim().isEmpty ? 'No reason given' : _controller.text.trim(),
            ),
            child: const Text('Decline'),
          ),
        ],
      );
}

/// Both sides confirm the item changed hands. See the note on
/// `LostFoundRepository.confirmHandover` for why this replaces a pickup OTP.
class _HandoverCard extends ConsumerWidget {
  const _HandoverCard({required this.claim, required this.uid});

  final Claim claim;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iConfirmed = claim.hasConfirmed(uid);
    final amClaimant = claim.claimantId == uid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(claim.itemName, style: theme.textTheme.titleMedium),
            Text(
              amClaimant ? 'The finder approved your claim' : 'You approved ${claim.claimantName}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            Gap.h12,
            if (iConfirmed)
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      'You confirmed. Waiting for the other person.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              )
            else
              CButton(
                label: amClaimant ? 'I collected it' : 'I handed it over',
                icon: Icons.handshake_outlined,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(lostFoundRepositoryProvider)
                        .confirmHandover(claim: claim, uid: uid);
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ClaimStatusCard extends StatelessWidget {
  const _ClaimStatusCard({required this.claim});

  final Claim claim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(claim.itemName),
        subtitle: Text(
          claim.status == ClaimStatus.rejected && claim.rejectionReason != null
              ? 'Declined — ${claim.rejectionReason}'
              : claim.status.label,
        ),
        trailing: Icon(
          switch (claim.status) {
            ClaimStatus.approved => Icons.check_circle_outline,
            ClaimStatus.rejected => Icons.cancel_outlined,
            _ => Icons.hourglass_top_outlined,
          },
          color: theme.hintColor,
        ),
      ),
    );
  }
}
