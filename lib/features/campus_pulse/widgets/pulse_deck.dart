import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/pulse_update.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../providers/pulse_providers.dart';

/// The Campus Pulse card deck.
///
/// Built to the sketched design: one large card filling the main body, with the
/// remaining cards stacked just behind its right edge so it reads as a deck.
/// Swiping left throws the top card away and reveals the next one.
///
/// A [Stack] rather than a `PageView` — a PageView slides pages in from the
/// side and cannot show the layered edges that make this look like a deck.
class PulseDeck extends ConsumerStatefulWidget {
  const PulseDeck({super.key, this.height = 320});

  final double height;

  @override
  ConsumerState<PulseDeck> createState() => _PulseDeckState();
}

class _PulseDeckState extends ConsumerState<PulseDeck> with SingleTickerProviderStateMixin {
  static const _visibleBehind = 2; // how many cards peek out at the right

  /// How far each card behind pokes out past the one in front.
  ///
  /// Achieved by insetting the *front* card from the right and un-insetting the
  /// ones behind — not by scaling. Scaling shrinks a card about its centre,
  /// which pulls it back in from the right and cancels the very offset that
  /// makes this read as a deck.
  static const _edge = 13.0;

  /// Vertical inset per card behind, so the stack has visible depth.
  static const _vertical = 8.0;

  int _index = 0;
  double _drag = 0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<double>? _animation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target, {VoidCallback? then}) {
    _animation = Tween<double>(begin: _drag, end: target)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic))
      ..addListener(() => setState(() => _drag = _animation!.value));

    _controller
      ..reset()
      ..forward().then((_) {
        then?.call();
      });
  }

  void _onDragEnd(DragEndDescription details, int total) {
    final width = MediaQuery.of(context).size.width;
    final velocity = details.velocity;

    final flungLeft = velocity < -600 || _drag < -width * 0.28;
    final flungRight = velocity > 600 || _drag > width * 0.28;

    if (flungLeft && _index < total - 1) {
      _animateTo(-width, then: () {
        setState(() {
          _index++;
          _drag = 0;
        });
      });
      return;
    }

    if (flungRight && _index > 0) {
      _animateTo(width, then: () {
        setState(() {
          _index--;
          _drag = 0;
        });
      });
      return;
    }

    // Not far enough, or nothing to move to — spring back.
    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final highlights = ref.watch(homePulseHighlightsProvider);
    ref.watch(clockTickProvider); // keeps "17 min ago" honest

    return highlights.when(
      loading: () => SizedBox(
        height: widget.height,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: Gap.lg),
          child: SkeletonCard(lines: 3),
        ),
      ),
      // The feed below reports the error; don't say it twice.
      error: (_, __) => const SizedBox.shrink(),
      data: (updates) {
        if (updates.isEmpty) return const _EmptyDeck();

        // Clamp after the list shrinks (an update expiring mid-session).
        final index = _index.clamp(0, updates.length - 1);
        if (index != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = index);
          });
        }

        return Column(
          children: [
            SizedBox(
              height: widget.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: _buildStack(updates, index),
              ),
            ),
            if (updates.length > 1) ...[
              Gap.h12,
              _Dots(count: updates.length, active: index),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStack(List<PulseUpdate> updates, int index) {
    final width = MediaQuery.of(context).size.width;

    // Dragging right means "go back". The previous card slides in from the
    // left, over the top of everything — the current card stays put.
    //
    // Sliding the *current* card off to the right instead would uncover the
    // stacked next card behind it, which is the wrong card entirely, and the
    // real previous card would only appear once the animation finished.
    final goingBack = _drag > 0 && index > 0;

    final children = <Widget>[];

    // Farthest card first so the nearest ends up on top of the Stack.
    // Each card behind sits `_edge` px further right and `_vertical` px inset
    // top and bottom, leaving a visible sliver of every card in the deck.
    for (var depth = _visibleBehind; depth >= 1; depth--) {
      final cardIndex = index + depth;
      if (cardIndex >= updates.length) continue;

      children.add(
        Positioned(
          left: _edge * depth,
          right: _edge * (_visibleBehind - depth),
          top: _vertical * depth,
          bottom: _vertical * depth,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Opacity(
                opacity: depth == 1 ? 0.9 : 0.65,
                child: _DeckCard(update: updates[cardIndex], dimmed: true),
              ),
            ),
          ),
        ),
      );
    }

    // The current card. It only follows the finger when moving forward; going
    // back it holds still while the previous card comes in over it.
    final top = updates[index];
    children.add(
      Positioned(
        left: 0,
        right: _edge * _visibleBehind,
        top: 0,
        bottom: 0,
        child: Transform.translate(
          offset: Offset(goingBack ? 0 : _drag, 0),
          child: Transform.rotate(
            // A slight tilt as it's thrown, so the gesture feels physical.
            angle: goingBack ? 0 : _drag / 2600,
            child: _DeckCard(update: top),
          ),
        ),
      ),
    );

    // The previous card, entering from off-screen left as the drag grows.
    if (goingBack) {
      children.add(
        Positioned(
          left: 0,
          right: _edge * _visibleBehind,
          top: 0,
          bottom: 0,
          child: Transform.translate(
            offset: Offset(_drag - width, 0),
            child: _DeckCard(update: updates[index - 1]),
          ),
        ),
      );
    }

    // One detector over the whole deck, so a drag that begins on a stacked
    // edge works too.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => _onDragUpdate(d.delta.dx, index, updates.length),
      onHorizontalDragEnd: (d) =>
          _onDragEnd(DragEndDescription(d.velocity.pixelsPerSecond.dx), updates.length),
      onTap: () => context.push(Routes.pulseDetail(top.id)),
      child: Stack(children: children),
    );
  }

  /// Applies a drag delta, with resistance at the two ends of the deck so it
  /// feels bounded rather than broken.
  void _onDragUpdate(double delta, int index, int total) {
    final next = _drag + delta;
    final atStart = index == 0 && next > 0;
    final atEnd = index == total - 1 && next < 0;

    setState(() => _drag = (atStart || atEnd) ? _drag + delta * 0.3 : next);
  }
}

/// Small holder so the drag-end logic stays testable and readable.
class DragEndDescription {
  const DragEndDescription(this.velocity);
  final double velocity;
}

/// One card in the deck.
class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.update, this.dimmed = false});

  final PulseUpdate update;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = update.tone;
    final accent = StatusPalette.colorOf(tone);
    final remaining = update.timeRemaining;
    final occupancy = update.occupancyLabel;

    return Semantics(
      button: !dimmed,
      label: '${update.locationName ?? update.title}. ${update.status.label}.'
          '${occupancy == null ? '' : ' $occupancy.'}',
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: Radii.lg,
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: dimmed
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Status wash, large enough to set the card's mood at a glance.
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          update.category.label,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(Fmt.relative(update.createdAt), style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const Spacer(),

                  // The place, as the card's headline — this is what a student
                  // is scanning for.
                  Text(
                    update.locationName ?? update.title,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap.h12,
                  Row(
                    children: [
                      StatusChip.pulse(update.status),
                      if (occupancy != null) ...[
                        Gap.w12,
                        Flexible(
                          child: Text(
                            occupancy,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (update.description.isNotEmpty) ...[
                    Gap.h12,
                    Text(
                      update.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      if (remaining != null)
                        Text(
                          Fmt.expiresIn(remaining),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: remaining.inMinutes < 30 ? accent : null,
                            fontWeight: remaining.inMinutes < 30 ? FontWeight.w600 : null,
                          ),
                        ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.lg,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Campus is quiet',
        message: 'Live updates appear here as soon as something changes.',
        compact: true,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: i == active ? 20 : 6,
              decoration: BoxDecoration(
                color: i == active ? scheme.primary : scheme.outline,
                borderRadius: Radii.pill,
              ),
            ),
        ],
      ),
    );
  }
}
