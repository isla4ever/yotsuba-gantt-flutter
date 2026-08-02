import 'package:flutter/foundation.dart';

import 'models.dart';

/// Synchronization features shared by charts in a [YgGanttLinkGroup].
enum YgSyncMode {
  /// Charts operate independently.
  none,

  /// Synchronize the horizontal time anchor.
  scroll,

  /// Synchronize the selected time scale.
  view,

  /// Synchronize both the time anchor and scale.
  all,
}

/// A lightweight in-memory bus for linking multiple Gantt widgets.
class YgGanttLinkGroup extends ChangeNotifier {
  Object? _source;
  DateTime? _anchor;
  YgViewMode? _viewMode;
  bool _isScrollUpdate = false;

  /// Source token for the latest update.
  Object? get source => _source;

  /// Center date from the latest scroll update.
  DateTime? get anchor => _anchor;

  /// View mode from the latest scale update.
  YgViewMode? get viewMode => _viewMode;

  /// Whether the latest update is a scroll update.
  bool get isScrollUpdate => _isScrollUpdate;

  /// Publishes a center date to linked charts.
  void publishScroll(Object source, DateTime anchor) {
    _source = source;
    _anchor = anchor;
    _isScrollUpdate = true;
    notifyListeners();
  }

  /// Publishes a time scale to linked charts.
  void publishView(Object source, YgViewMode viewMode) {
    _source = source;
    _viewMode = viewMode;
    _isScrollUpdate = false;
    notifyListeners();
  }
}

/// Imperative controls for a [YotsubaGantt] instance.
class YgGanttController {
  YgControllerDelegate? _delegate;

  /// Whether the controller is attached to a mounted chart.
  bool get isAttached => _delegate != null;

  /// Scrolls a date to the timeline viewport center.
  Future<void> scrollToDate(
    DateTime date, {
    Duration duration = const Duration(milliseconds: 320),
  }) async {
    await _delegate?.scrollToDate(date, duration);
  }

  /// Scrolls a task row and date span into view.
  Future<void> scrollTaskIntoView(
    String taskId, {
    Duration duration = const Duration(milliseconds: 320),
  }) async {
    await _delegate?.scrollTaskIntoView(taskId, duration);
  }

  /// Scrolls a row into the vertical viewport.
  Future<void> scrollToRow(
    int rowIndex, {
    Duration duration = const Duration(milliseconds: 260),
  }) async {
    await _delegate?.scrollToRow(rowIndex, duration);
  }

  /// Selects a zoom level while preserving the center date.
  void setView(YgViewMode mode) => _delegate?.setView(mode);

  /// Chooses a useful zoom and focuses the task range.
  Future<void> fitToTasks() async => _delegate?.fitToTasks();

  /// Attaches internal widget operations.
  void attach(YgControllerDelegate delegate) => _delegate = delegate;

  /// Detaches internal widget operations.
  void detach(YgControllerDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }
}

/// Internal operations bound by a chart state.
class YgControllerDelegate {
  /// Creates a delegate.
  const YgControllerDelegate({
    required this.scrollToDate,
    required this.scrollTaskIntoView,
    required this.scrollToRow,
    required this.setView,
    required this.fitToTasks,
  });

  /// Date navigation implementation.
  final Future<void> Function(DateTime, Duration) scrollToDate;

  /// Task navigation implementation.
  final Future<void> Function(String, Duration) scrollTaskIntoView;

  /// Row navigation implementation.
  final Future<void> Function(int, Duration) scrollToRow;

  /// View change implementation.
  final void Function(YgViewMode) setView;

  /// Fit implementation.
  final Future<void> Function() fitToTasks;
}
