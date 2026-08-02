import 'package:flutter/material.dart';

/// Built-in timeline zoom levels.
enum YgViewMode {
  /// Year overview with month divisions.
  year,

  /// Quarter overview with week divisions.
  quarter,

  /// Month overview with week divisions.
  month,

  /// Week overview with day divisions.
  week,

  /// Day overview with six-hour divisions.
  day,

  /// Hour-level planning.
  hour,
}

/// Display helpers for [YgViewMode].
extension YgViewModeValues on YgViewMode {
  /// Human-readable Chinese label.
  String get label => switch (this) {
        YgViewMode.year => '年',
        YgViewMode.quarter => '季',
        YgViewMode.month => '月',
        YgViewMode.week => '周',
        YgViewMode.day => '日',
        YgViewMode.hour => '时',
      };

  /// Default timeline density in logical pixels per day.
  double get pixelsPerDay => switch (this) {
        YgViewMode.year => 0.9,
        YgViewMode.quarter => 2.2,
        YgViewMode.month => 5.2,
        YgViewMode.week => 18,
        YgViewMode.day => 72,
        YgViewMode.hour => 288,
      };

  /// Default drag snapping duration.
  Duration get snapDuration => switch (this) {
        YgViewMode.year => const Duration(days: 7),
        YgViewMode.quarter => const Duration(days: 1),
        YgViewMode.month => const Duration(days: 1),
        YgViewMode.week => const Duration(hours: 12),
        YgViewMode.day => const Duration(hours: 6),
        YgViewMode.hour => const Duration(hours: 1),
      };
}

/// Semantic task type.
enum YgTaskKind {
  /// A regular task.
  task,

  /// A summary or project row.
  project,

  /// A point-in-time milestone.
  milestone,
}

/// Built-in task bar presentation.
enum YgBarStyle {
  /// Filled task bar.
  solid,

  /// Bordered task bar with a transparent interior.
  outline,

  /// Low-contrast filled task bar.
  soft,

  /// Filled task bar with an explicit progress layer.
  progress,
}

/// Initial automatic positioning strategy.
enum YgAutoFocus {
  /// Keep the current scroll position.
  none,

  /// Focus the time window containing the most task midpoints.
  dense,

  /// Focus the earliest task.
  earliest,

  /// Focus today.
  today,
}

/// Viewport entry transition preset.
enum YgEntryTransition {
  /// No transition.
  none,

  /// Opacity only.
  fade,

  /// Subtle opacity and vertical translation.
  fadeSlide,

  /// Subtle opacity and scale.
  scaleFade,
}

/// Side of the viewport containing an offscreen task.
enum YgEdgeSide {
  /// The task is before the visible time range.
  left,

  /// The task is after the visible time range.
  right,
}

/// The reason a task changed through direct manipulation.
enum YgTaskChangeKind {
  /// The entire task moved.
  move,

  /// The start edge changed.
  resizeStart,

  /// The end edge changed.
  resizeEnd,
}

/// Immutable task model used by the native widget.
@immutable
class YgTask {
  /// Creates a task.
  const YgTask({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.progress = 0,
    this.kind = YgTaskKind.task,
    this.barStyle = YgBarStyle.solid,
    this.color,
    this.parentId,
    this.owner,
    this.dependencies = const <String>[],
    this.metadata = const <String, Object?>{},
  }) : assert(progress >= 0 && progress <= 1);

  /// Stable task identifier.
  final String id;

  /// Visible task title.
  final String title;

  /// Task start, including time-of-day where relevant.
  final DateTime start;

  /// Task end, including time-of-day where relevant.
  final DateTime end;

  /// Completion ratio from 0 to 1.
  final double progress;

  /// Semantic task kind.
  final YgTaskKind kind;

  /// Built-in visual template.
  final YgBarStyle barStyle;

  /// Optional task-specific color.
  final Color? color;

  /// Optional parent identifier for host-managed task trees.
  final String? parentId;

  /// Optional owner label.
  final String? owner;

  /// IDs of predecessor tasks.
  final List<String> dependencies;

  /// Host-owned custom data.
  final Map<String, Object?> metadata;

  /// Returns a changed task while preserving unspecified values.
  YgTask copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    double? progress,
    YgTaskKind? kind,
    YgBarStyle? barStyle,
    Color? color,
    String? parentId,
    String? owner,
    List<String>? dependencies,
    Map<String, Object?>? metadata,
  }) {
    return YgTask(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      progress: progress ?? this.progress,
      kind: kind ?? this.kind,
      barStyle: barStyle ?? this.barStyle,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      owner: owner ?? this.owner,
      dependencies: dependencies ?? this.dependencies,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Payload emitted after direct task manipulation.
@immutable
class YgTaskChange {
  /// Creates a task change.
  const YgTaskChange({
    required this.previous,
    required this.task,
    required this.kind,
  });

  /// Task before interaction.
  final YgTask previous;

  /// Proposed immutable replacement.
  final YgTask task;

  /// Interaction type.
  final YgTaskChangeKind kind;
}

/// Visible timeline and row window.
@immutable
class YgVisibleRange {
  /// Creates a visible range payload.
  const YgVisibleRange({
    required this.start,
    required this.end,
    required this.firstRow,
    required this.lastRow,
  });

  /// First visible date.
  final DateTime start;

  /// Last visible date.
  final DateTime end;

  /// First visible row index.
  final int firstRow;

  /// Last visible row index.
  final int lastRow;
}

/// Geometry and state passed to a custom task bar builder.
@immutable
class YgTaskBarDetails {
  /// Creates task bar details.
  const YgTaskBarDetails({
    required this.task,
    required this.rowIndex,
    required this.isSelected,
    required this.width,
    required this.height,
  });

  /// Current task.
  final YgTask task;

  /// Task row index.
  final int rowIndex;

  /// Whether the host selected this task.
  final bool isSelected;

  /// Resolved task width.
  final double width;

  /// Resolved task height.
  final double height;
}

/// Builds a complete task bar interior.
typedef YgTaskBarBuilder = Widget Function(
    BuildContext context, YgTaskBarDetails details);

/// Builds a fixed task-list row.
typedef YgRowHeaderBuilder = Widget Function(
    BuildContext context, YgTask task, int rowIndex);

/// Wraps content in a host-defined viewport entry transition.
typedef YgEntryTransitionBuilder = Widget Function(
  BuildContext context,
  Widget child,
  Animation<double> animation,
);

/// Geometry and actions passed to a custom offscreen indicator.
@immutable
class YgEdgeIndicatorDetails {
  /// Creates indicator details.
  const YgEdgeIndicatorDetails({
    required this.task,
    required this.rowIndex,
    required this.side,
    required this.jump,
  });

  /// Task outside the current horizontal viewport.
  final YgTask task;

  /// Task row index.
  final int rowIndex;

  /// Side where the task can be found.
  final YgEdgeSide side;

  /// Scrolls the corresponding task into view.
  final VoidCallback jump;
}

/// Builds a row-level offscreen task indicator.
typedef YgEdgeIndicatorBuilder = Widget Function(
  BuildContext context,
  YgEdgeIndicatorDetails details,
);
