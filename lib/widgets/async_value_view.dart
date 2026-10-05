import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import 'state_views.dart';

/// Renders loading / error / empty / data for an [AsyncValue] in one place.
///
/// This is the mechanism that makes §31–33 structural rather than per-screen
/// discipline: if a screen uses this widget, it cannot forget a state.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.skeleton,
    this.empty,
    this.isEmpty,
    this.onRetry,
    this.compact = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Shown while loading. Prefer a skeleton that mirrors the loaded layout.
  final Widget Function()? skeleton;

  /// Shown when [isEmpty] returns true.
  final Widget Function(T data)? empty;
  final bool Function(T data)? isEmpty;

  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => skeleton?.call() ?? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, s) => ErrorStateView(
        failure: e is AppFailure ? e : FailureMapper.map(e, s),
        onRetry: onRetry,
        compact: compact,
      ),
      data: (d) {
        final treatAsEmpty = isEmpty?.call(d) ?? (d is Iterable && d.isEmpty);
        if (treatAsEmpty && empty != null) return empty!(d);
        return data(d);
      },
    );
  }
}
