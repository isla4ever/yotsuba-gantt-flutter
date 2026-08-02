import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'theme.dart';

const _dayMs = Duration.millisecondsPerDay;

/// A native, virtualized Flutter Gantt chart.
class YotsubaGantt extends StatefulWidget {
  /// Creates a Gantt chart.
  const YotsubaGantt({
    super.key,
    required this.tasks,
    this.controller,
    this.rangeStart,
    this.rangeEnd,
    this.viewMode = YgViewMode.week,
    this.onViewModeChanged,
    this.theme,
    this.height = 520,
    this.sidebarWidth = 280,
    this.minSidebarWidth = 180,
    this.maxSidebarWidth = 480,
    this.sidebarResizeStep = 8,
    this.resizableSidebar = true,
    this.autoFocus = YgAutoFocus.dense,
    this.denseWindow = const Duration(days: 14),
    this.showDependencies = true,
    this.showProgress = true,
    this.showOffscreenIndicators = true,
    this.linkGroup,
    this.syncMode = YgSyncMode.none,
    this.interactive = true,
    this.selectedTaskId,
    this.entryTransition = YgEntryTransition.fadeSlide,
    this.entryDuration = const Duration(milliseconds: 180),
    this.taskBarBuilder,
    this.rowHeaderBuilder,
    this.entryTransitionBuilder,
    this.edgeIndicatorBuilder,
    this.onTaskTap,
    this.onTaskDoubleTap,
    this.onTaskChanged,
    this.onVisibleRangeChanged,
  })  : assert(height >= 240),
        assert(sidebarWidth > 0),
        assert(minSidebarWidth > 0),
        assert(maxSidebarWidth >= minSidebarWidth),
        assert(sidebarResizeStep > 0);

  /// Ordered task rows. Only visible rows are built.
  final List<YgTask> tasks;

  /// Optional imperative controller.
  final YgGanttController? controller;

  /// Timeline range start. Defaults to seven days before the earliest task.
  final DateTime? rangeStart;

  /// Timeline range end. Defaults to seven days after the latest task.
  final DateTime? rangeEnd;

  /// Initial or externally controlled zoom level.
  final YgViewMode viewMode;

  /// Called after the built-in zoom level changes.
  final ValueChanged<YgViewMode>? onViewModeChanged;

  /// Optional component theme.
  final YgGanttThemeData? theme;

  /// Stable component height.
  final double height;

  /// Initial task-list width.
  final double sidebarWidth;

  /// Minimum task-list width.
  final double minSidebarWidth;

  /// Maximum task-list width.
  final double maxSidebarWidth;

  /// Width snapping interval while dragging the divider.
  final double sidebarResizeStep;

  /// Whether the task-list divider can be dragged.
  final bool resizableSidebar;

  /// Initial focus algorithm.
  final YgAutoFocus autoFocus;

  /// Density bucket duration used by [YgAutoFocus.dense].
  final Duration denseWindow;

  /// Whether dependency paths are visible.
  final bool showDependencies;

  /// Whether built-in bars render progress.
  final bool showProgress;

  /// Whether each visible row exposes left/right task navigation markers.
  final bool showOffscreenIndicators;

  /// Optional in-memory group used to link multiple chart instances.
  final YgGanttLinkGroup? linkGroup;

  /// Features synchronized through [linkGroup].
  final YgSyncMode syncMode;

  /// Enables built-in drag and resize interactions when callbacks are present.
  final bool interactive;

  /// Optional host-controlled selected task ID.
  final String? selectedTaskId;

  /// Built-in transition for rows entering a virtualized viewport.
  final YgEntryTransition entryTransition;

  /// Viewport entry transition duration.
  final Duration entryDuration;

  /// Replaces the built-in task bar interior.
  final YgTaskBarBuilder? taskBarBuilder;

  /// Replaces the fixed task-list row.
  final YgRowHeaderBuilder? rowHeaderBuilder;

  /// Replaces the built-in viewport entry transition.
  final YgEntryTransitionBuilder? entryTransitionBuilder;

  /// Replaces row-level left and right offscreen task indicators.
  final YgEdgeIndicatorBuilder? edgeIndicatorBuilder;

  /// Called when a task is tapped.
  final ValueChanged<YgTask>? onTaskTap;

  /// Called when a task is double tapped.
  final ValueChanged<YgTask>? onTaskDoubleTap;

  /// Emits an immutable replacement after move or resize.
  final ValueChanged<YgTaskChange>? onTaskChanged;

  /// Called at most once per frame when visible dates or rows change.
  final ValueChanged<YgVisibleRange>? onVisibleRangeChanged;

  @override
  State<YotsubaGantt> createState() => _YotsubaGanttState();
}

class _YotsubaGanttState extends State<YotsubaGantt> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _timelineVertical = ScrollController();
  final ScrollController _sidebarVertical = ScrollController();
  final Object _linkSource = Object();
  late final YgControllerDelegate _delegate;
  late YgViewMode _viewMode;
  late double _sidebarWidth;
  bool _syncingVertical = false;
  bool _visibleRangeScheduled = false;
  bool _applyingLinkedUpdate = false;
  double _timelineViewportWidth = 1;
  late Map<String, int> _taskIndexById;

  YgGanttThemeData get _theme => widget.theme ?? YgGanttThemeData.light();

  double get _rowHeight => _theme.rowHeight;

  DateTime get _rangeStart {
    if (widget.rangeStart != null) return widget.rangeStart!;
    if (widget.tasks.isEmpty) {
      return DateTime.now().subtract(const Duration(days: 30));
    }
    final earliest = widget.tasks
        .map((task) => task.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return earliest.subtract(const Duration(days: 7));
  }

  DateTime get _rangeEnd {
    if (widget.rangeEnd != null) return widget.rangeEnd!;
    if (widget.tasks.isEmpty) {
      return DateTime.now().add(const Duration(days: 90));
    }
    final latest = widget.tasks
        .map((task) => task.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return latest.add(const Duration(days: 7));
  }

  double get _rangeDays =>
      math.max(1, _rangeEnd.difference(_rangeStart).inMinutes / 1440);

  double get _pixelsPerDay => _timelineWidth / _rangeDays;

  double get _timelineWidth {
    return math.max(
      _timelineViewportWidth,
      _rangeDays * _viewMode.pixelsPerDay,
    );
  }

  @override
  void initState() {
    super.initState();
    _viewMode = widget.viewMode;
    _taskIndexById = _indexTasks(widget.tasks);
    _sidebarWidth = widget.sidebarWidth
        .clamp(widget.minSidebarWidth, widget.maxSidebarWidth)
        .toDouble();
    _delegate = YgControllerDelegate(
      scrollToDate: _scrollToDate,
      scrollTaskIntoView: _scrollTaskIntoView,
      scrollToRow: _scrollToRow,
      setView: _setView,
      fitToTasks: _fitToTasks,
    );
    widget.controller?.attach(_delegate);
    _timelineVertical.addListener(_syncSidebar);
    _sidebarVertical.addListener(_syncTimeline);
    _horizontal.addListener(_handleHorizontalScroll);
    _timelineVertical.addListener(_scheduleVisibleRange);
    widget.linkGroup?.addListener(_handleLinkedUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAutoFocus());
  }

  @override
  void didUpdateWidget(covariant YotsubaGantt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_delegate);
      widget.controller?.attach(_delegate);
    }
    if (oldWidget.linkGroup != widget.linkGroup) {
      oldWidget.linkGroup?.removeListener(_handleLinkedUpdate);
      widget.linkGroup?.addListener(_handleLinkedUpdate);
    }
    if (oldWidget.viewMode != widget.viewMode && widget.viewMode != _viewMode) {
      _setView(widget.viewMode, notify: false);
    }
    if (oldWidget.tasks != widget.tasks ||
        oldWidget.rangeStart != widget.rangeStart ||
        oldWidget.rangeEnd != widget.rangeEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyAutoFocus());
    }
    if (oldWidget.tasks != widget.tasks) {
      _taskIndexById = _indexTasks(widget.tasks);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(_delegate);
    widget.linkGroup?.removeListener(_handleLinkedUpdate);
    _timelineVertical
      ..removeListener(_syncSidebar)
      ..removeListener(_scheduleVisibleRange)
      ..dispose();
    _sidebarVertical
      ..removeListener(_syncTimeline)
      ..dispose();
    _horizontal
      ..removeListener(_handleHorizontalScroll)
      ..dispose();
    super.dispose();
  }

  Map<String, int> _indexTasks(List<YgTask> tasks) => <String, int>{
        for (var index = 0; index < tasks.length; index++)
          tasks[index].id: index,
      };

  bool get _syncsScroll =>
      widget.syncMode == YgSyncMode.scroll || widget.syncMode == YgSyncMode.all;

  bool get _syncsView =>
      widget.syncMode == YgSyncMode.view || widget.syncMode == YgSyncMode.all;

  void _handleHorizontalScroll() {
    _scheduleVisibleRange();
    if (_applyingLinkedUpdate || !_syncsScroll || !_horizontal.hasClients) {
      return;
    }
    widget.linkGroup?.publishScroll(
      _linkSource,
      _xToDate(_horizontal.offset + _timelineViewportWidth / 2),
    );
  }

  void _handleLinkedUpdate() {
    final group = widget.linkGroup;
    if (group == null || identical(group.source, _linkSource)) return;
    if (group.isScrollUpdate && _syncsScroll && group.anchor != null) {
      _applyingLinkedUpdate = true;
      _scrollToDate(group.anchor!, Duration.zero).whenComplete(() {
        _applyingLinkedUpdate = false;
      });
      return;
    }
    if (!group.isScrollUpdate && _syncsView && group.viewMode != null) {
      _setView(group.viewMode!, publish: false);
    }
  }

  double _dateToX(DateTime value) {
    return value.difference(_rangeStart).inMilliseconds /
        _dayMs *
        _pixelsPerDay;
  }

  DateTime _xToDate(double x) {
    return _rangeStart.add(
      Duration(milliseconds: (x / _pixelsPerDay * _dayMs).round()),
    );
  }

  void _syncSidebar() {
    if (_syncingVertical || !_sidebarVertical.hasClients) return;
    _syncingVertical = true;
    _sidebarVertical.jumpTo(
      _timelineVertical.offset
          .clamp(0, _sidebarVertical.position.maxScrollExtent)
          .toDouble(),
    );
    _syncingVertical = false;
  }

  void _syncTimeline() {
    if (_syncingVertical || !_timelineVertical.hasClients) return;
    _syncingVertical = true;
    _timelineVertical.jumpTo(
      _sidebarVertical.offset
          .clamp(0, _timelineVertical.position.maxScrollExtent)
          .toDouble(),
    );
    _syncingVertical = false;
  }

  void _scheduleVisibleRange() {
    if (_visibleRangeScheduled || widget.onVisibleRangeChanged == null) return;
    _visibleRangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleRangeScheduled = false;
      if (!mounted) return;
      final horizontalOffset =
          _horizontal.hasClients ? _horizontal.offset : 0.0;
      final verticalOffset =
          _timelineVertical.hasClients ? _timelineVertical.offset : 0.0;
      widget.onVisibleRangeChanged?.call(
        YgVisibleRange(
          start: _xToDate(horizontalOffset),
          end: _xToDate(horizontalOffset + _timelineViewportWidth),
          firstRow: (verticalOffset / _rowHeight).floor().clamp(
                0,
                math.max(0, widget.tasks.length - 1),
              ),
          lastRow: ((verticalOffset + widget.height) / _rowHeight).ceil().clamp(
                0,
                math.max(0, widget.tasks.length - 1),
              ),
        ),
      );
    });
  }

  Future<void> _applyAutoFocus() async {
    if (!mounted || !_horizontal.hasClients || widget.tasks.isEmpty) return;
    final target = switch (widget.autoFocus) {
      YgAutoFocus.none => null,
      YgAutoFocus.today => DateTime.now(),
      YgAutoFocus.earliest => widget.tasks
          .map((task) => task.start)
          .reduce((a, b) => a.isBefore(b) ? a : b),
      YgAutoFocus.dense => _denseDate(),
    };
    if (target != null) {
      await _scrollToDate(target, const Duration(milliseconds: 360));
    }
  }

  DateTime _denseDate() {
    final bucketMs = math.max(1, widget.denseWindow.inMilliseconds);
    final buckets = <int, int>{};
    for (final task in widget.tasks) {
      final midpoint = task.start.millisecondsSinceEpoch +
          task.end.difference(task.start).inMilliseconds ~/ 2;
      final bucket = midpoint ~/ bucketMs;
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    final best =
        buckets.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return DateTime.fromMillisecondsSinceEpoch(best * bucketMs + bucketMs ~/ 2);
  }

  Future<void> _scrollToDate(DateTime date, Duration duration) async {
    if (!_horizontal.hasClients) return;
    final target = (_dateToX(date) - _timelineViewportWidth / 2)
        .clamp(0, _horizontal.position.maxScrollExtent)
        .toDouble();
    if (duration == Duration.zero) {
      _horizontal.jumpTo(target);
    } else {
      await _horizontal.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _scrollTaskIntoView(String taskId, Duration duration) async {
    final row = widget.tasks.indexWhere((task) => task.id == taskId);
    if (row < 0) return;
    final task = widget.tasks[row];
    await Future.wait(<Future<void>>[
      _scrollToDate(
        task.start.add(
          Duration(
            milliseconds: task.end.difference(task.start).inMilliseconds ~/ 2,
          ),
        ),
        duration,
      ),
      _scrollToRow(row, duration),
    ]);
  }

  Future<void> _scrollToRow(int rowIndex, Duration duration) async {
    if (!_timelineVertical.hasClients || widget.tasks.isEmpty) return;
    final safeIndex = rowIndex.clamp(0, widget.tasks.length - 1);
    final bodyHeight = math.max(1, widget.height - 64);
    final target = (safeIndex * _rowHeight - bodyHeight / 2 + _rowHeight / 2)
        .clamp(0, _timelineVertical.position.maxScrollExtent)
        .toDouble();
    if (duration == Duration.zero) {
      _timelineVertical.jumpTo(target);
    } else {
      await _timelineVertical.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _setView(
    YgViewMode mode, {
    bool notify = true,
    bool publish = true,
  }) {
    if (mode == _viewMode) return;
    final center = _xToDate(
      (_horizontal.hasClients ? _horizontal.offset : 0) +
          _timelineViewportWidth / 2,
    );
    setState(() => _viewMode = mode);
    if (notify) widget.onViewModeChanged?.call(mode);
    if (publish && _syncsView) {
      widget.linkGroup?.publishView(_linkSource, mode);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToDate(center, const Duration(milliseconds: 360));
    });
  }

  Future<void> _fitToTasks() async {
    if (widget.tasks.isEmpty) return;
    final earliest = widget.tasks
        .map((task) => task.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = widget.tasks
        .map((task) => task.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final spanDays = math.max(1, latest.difference(earliest).inHours / 24);
    final candidates = YgViewMode.values.where(
      (mode) => spanDays * mode.pixelsPerDay <= _timelineViewportWidth * 0.82,
    );
    _setView(candidates.isEmpty ? YgViewMode.year : candidates.last);
    await _scrollToDate(
      earliest.add(
        Duration(milliseconds: latest.difference(earliest).inMilliseconds ~/ 2),
      ),
      const Duration(milliseconds: 360),
    );
  }

  void _resizeSidebar(double delta) {
    final raw = (_sidebarWidth + delta)
        .clamp(
          widget.minSidebarWidth,
          math.min(
            widget.maxSidebarWidth,
            MediaQuery.sizeOf(context).width * 0.7,
          ),
        )
        .toDouble();
    final snapped =
        (raw / widget.sidebarResizeStep).round() * widget.sidebarResizeStep;
    setState(() => _sidebarWidth = snapped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safeSidebar = _sidebarWidth
              .clamp(
                widget.minSidebarWidth,
                math.min(widget.maxSidebarWidth, constraints.maxWidth * 0.7),
              )
              .toDouble();
          _timelineViewportWidth = math.max(
            1,
            constraints.maxWidth - safeSidebar - 6,
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              border: Border.all(color: theme.gridColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Column(
                children: <Widget>[
                  _buildHeader(safeSidebar, theme),
                  Expanded(child: _buildBody(safeSidebar, theme)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(double sidebarWidth, YgGanttThemeData theme) {
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          Container(
            width: sidebarWidth,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            color: theme.headerColor,
            child: Text(
              '任务 / 负责人',
              style: theme.headerTextStyle.copyWith(color: theme.textColor),
            ),
          ),
          _buildDivider(theme),
          Expanded(
            child: ColoredBox(
              color: theme.headerColor,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _horizontal,
                  builder: (context, child) {
                    final offset =
                        _horizontal.hasClients ? _horizontal.offset : 0.0;
                    return Transform.translate(
                      offset: Offset(-offset, 0),
                      child: SizedBox(
                        width: _timelineWidth,
                        child: CustomPaint(
                          painter: _TimelineHeaderPainter(
                            start: _rangeStart,
                            end: _rangeEnd,
                            mode: _viewMode,
                            width: _timelineWidth,
                            theme: theme,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(YgGanttThemeData theme) {
    return MouseRegion(
      cursor: widget.resizableSidebar
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: widget.resizableSidebar
            ? (event) => _resizeSidebar(event.delta.dx)
            : null,
        child: Container(
          width: 6,
          color: theme.headerColor,
          alignment: Alignment.center,
          child: Container(width: 1, color: theme.gridColor),
        ),
      ),
    );
  }

  Widget _buildBody(double sidebarWidth, YgGanttThemeData theme) {
    if (widget.tasks.isEmpty) {
      return Center(
        child: Text('暂无任务', style: TextStyle(color: theme.mutedTextColor)),
      );
    }
    return Row(
      children: <Widget>[
        SizedBox(
          width: sidebarWidth,
          child: ColoredBox(
            color: theme.sidebarColor,
            child: ListView.builder(
              controller: _sidebarVertical,
              itemExtent: _rowHeight,
              itemCount: widget.tasks.length,
              itemBuilder: (context, index) => _ViewportEntry(
                key: ValueKey<String>('sidebar-${widget.tasks[index].id}'),
                transition: widget.entryTransition,
                duration: widget.entryDuration,
                builder: widget.entryTransitionBuilder,
                child: _buildSidebarRow(
                  context,
                  widget.tasks[index],
                  index,
                  theme,
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 6,
          color: theme.backgroundColor,
          child: Center(child: Container(width: 1, color: theme.gridColor)),
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 0,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _timelineWidth,
                    child: ListView.builder(
                      controller: _timelineVertical,
                      itemExtent: _rowHeight,
                      itemCount: widget.tasks.length,
                      itemBuilder: (context, index) => _ViewportEntry(
                        key: ValueKey<String>(
                          'timeline-${widget.tasks[index].id}',
                        ),
                        transition: widget.entryTransition,
                        duration: widget.entryDuration,
                        builder: widget.entryTransitionBuilder,
                        child: _buildTimelineRow(
                          context,
                          widget.tasks[index],
                          index,
                          theme,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showDependencies)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        _horizontal,
                        _timelineVertical,
                      ]),
                      builder: (context, child) => CustomPaint(
                        painter: _DependencyPainter(
                          tasks: widget.tasks,
                          taskIndexById: _taskIndexById,
                          start: _rangeStart,
                          pixelsPerDay: _pixelsPerDay,
                          horizontalOffset:
                              _horizontal.hasClients ? _horizontal.offset : 0,
                          verticalOffset: _timelineVertical.hasClients
                              ? _timelineVertical.offset
                              : 0,
                          rowHeight: _rowHeight,
                          viewportWidth: _timelineViewportWidth,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarRow(
    BuildContext context,
    YgTask task,
    int index,
    YgGanttThemeData theme,
  ) {
    if (widget.rowHeaderBuilder != null) {
      return widget.rowHeaderBuilder!(context, task, index);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.selectedTaskId == task.id
            ? theme.primaryColor.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: theme.gridColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: TextStyle(color: theme.mutedTextColor, fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 13,
                  fontWeight: task.kind == YgTaskKind.project
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            if (task.owner != null)
              Text(
                task.owner!,
                style: TextStyle(color: theme.mutedTextColor, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(
    BuildContext context,
    YgTask task,
    int index,
    YgGanttThemeData theme,
  ) {
    final left = _dateToX(task.start);
    final rawWidth = math.max(0, _dateToX(task.end) - left);
    final width = task.kind == YgTaskKind.milestone
        ? 20.0
        : math.max(18, rawWidth).toDouble();
    final taskHeight = task.kind == YgTaskKind.project
        ? math.min(_rowHeight - 12, theme.taskHeight + 4)
        : theme.taskHeight;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.gridColor)),
      ),
      child: CustomPaint(
        painter: _GridPainter(
          start: _rangeStart,
          end: _rangeEnd,
          mode: _viewMode,
          width: _timelineWidth,
          theme: theme,
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: left,
              top: (_rowHeight - taskHeight) / 2,
              width: width,
              height: taskHeight,
              child: _InteractiveTaskBar(
                task: task,
                rowIndex: index,
                width: width,
                height: taskHeight,
                selected: widget.selectedTaskId == task.id,
                theme: theme,
                showProgress: widget.showProgress,
                interactive: widget.interactive,
                pixelsPerDay: _pixelsPerDay,
                snapDuration: _viewMode.snapDuration,
                builder: widget.taskBarBuilder,
                onTap: widget.onTaskTap,
                onDoubleTap: widget.onTaskDoubleTap,
                onChanged: widget.onTaskChanged,
              ),
            ),
            if (widget.showOffscreenIndicators)
              AnimatedBuilder(
                animation: _horizontal,
                builder: (context, child) {
                  final offset =
                      _horizontal.hasClients ? _horizontal.offset : 0.0;
                  final isLeft = left + width < offset;
                  final isRight = left > offset + _timelineViewportWidth;
                  if (!isLeft && !isRight) return const SizedBox.shrink();
                  return Positioned(
                    left: isLeft
                        ? offset + 2
                        : offset + _timelineViewportWidth - 24,
                    top: (_rowHeight - 24) / 2,
                    child: widget.edgeIndicatorBuilder?.call(
                          context,
                          YgEdgeIndicatorDetails(
                            task: task,
                            rowIndex: index,
                            side: isLeft ? YgEdgeSide.left : YgEdgeSide.right,
                            jump: () => _scrollTaskIntoView(
                              task.id,
                              const Duration(milliseconds: 320),
                            ),
                          ),
                        ) ??
                        Tooltip(
                          message: isLeft ? '跳到左侧任务' : '跳到右侧任务',
                          child: Material(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(isRight ? 12 : 3),
                              right: Radius.circular(isLeft ? 12 : 3),
                            ),
                            child: InkWell(
                              onTap: () => _scrollTaskIntoView(
                                task.id,
                                const Duration(milliseconds: 320),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 22,
                                height: 24,
                                child: Icon(
                                  isLeft
                                      ? Icons.chevron_left
                                      : Icons.chevron_right,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveTaskBar extends StatefulWidget {
  const _InteractiveTaskBar({
    required this.task,
    required this.rowIndex,
    required this.width,
    required this.height,
    required this.selected,
    required this.theme,
    required this.showProgress,
    required this.interactive,
    required this.pixelsPerDay,
    required this.snapDuration,
    required this.builder,
    required this.onTap,
    required this.onDoubleTap,
    required this.onChanged,
  });

  final YgTask task;
  final int rowIndex;
  final double width;
  final double height;
  final bool selected;
  final YgGanttThemeData theme;
  final bool showProgress;
  final bool interactive;
  final double pixelsPerDay;
  final Duration snapDuration;
  final YgTaskBarBuilder? builder;
  final ValueChanged<YgTask>? onTap;
  final ValueChanged<YgTask>? onDoubleTap;
  final ValueChanged<YgTaskChange>? onChanged;

  @override
  State<_InteractiveTaskBar> createState() => _InteractiveTaskBarState();
}

class _InteractiveTaskBarState extends State<_InteractiveTaskBar> {
  double _previewDx = 0;

  Duration _durationForDelta(double delta) {
    final rawMs = delta / widget.pixelsPerDay * _dayMs;
    final snapMs = widget.snapDuration.inMilliseconds;
    return Duration(milliseconds: (rawMs / snapMs).round() * snapMs);
  }

  void _finish(YgTaskChangeKind kind) {
    final shift = _durationForDelta(_previewDx);
    if (shift == Duration.zero) {
      setState(() => _previewDx = 0);
      return;
    }
    final previous = widget.task;
    final next = switch (kind) {
      YgTaskChangeKind.move => previous.copyWith(
          start: previous.start.add(shift),
          end: previous.end.add(shift),
        ),
      YgTaskChangeKind.resizeStart => previous.copyWith(
          start: previous.start.add(shift).isAfter(previous.end)
              ? previous.end
              : previous.start.add(shift),
        ),
      YgTaskChangeKind.resizeEnd => previous.copyWith(
          end: previous.end.add(shift).isBefore(previous.start)
              ? previous.start
              : previous.end.add(shift),
        ),
    };
    setState(() => _previewDx = 0);
    widget.onChanged?.call(
      YgTaskChange(previous: previous, task: next, kind: kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final color = task.color ?? widget.theme.primaryColor;
    final child = widget.builder?.call(
          context,
          YgTaskBarDetails(
            task: task,
            rowIndex: widget.rowIndex,
            isSelected: widget.selected,
            width: widget.width,
            height: widget.height,
          ),
        ) ??
        _DefaultTaskBar(
          task: task,
          color: color,
          theme: widget.theme,
          showProgress: widget.showProgress,
        );
    final bar = Transform.translate(
      offset: Offset(_previewDx, 0),
      child: Transform.rotate(
        angle: task.kind == YgTaskKind.milestone ? math.pi / 4 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              task.kind == YgTaskKind.milestone ? 3 : widget.theme.taskRadius,
            ),
            boxShadow: widget.selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.theme.taskRadius),
            child: task.kind == YgTaskKind.milestone
                ? ColoredBox(color: color)
                : child,
          ),
        ),
      ),
    );
    return MouseRegion(
      cursor: widget.interactive && widget.onChanged != null
          ? SystemMouseCursors.grab
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap?.call(task),
        onDoubleTap: () => widget.onDoubleTap?.call(task),
        onHorizontalDragUpdate: widget.interactive && widget.onChanged != null
            ? (event) => setState(() => _previewDx += event.delta.dx)
            : null,
        onHorizontalDragEnd: widget.interactive && widget.onChanged != null
            ? (_) => _finish(YgTaskChangeKind.move)
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: bar),
            if (widget.interactive &&
                widget.onChanged != null &&
                task.kind != YgTaskKind.milestone) ...<Widget>[
              _ResizeHandle(
                alignment: Alignment.centerLeft,
                onUpdate: (delta) => setState(() => _previewDx += delta),
                onEnd: () => _finish(YgTaskChangeKind.resizeStart),
              ),
              _ResizeHandle(
                alignment: Alignment.centerRight,
                onUpdate: (delta) => setState(() => _previewDx += delta),
                onEnd: () => _finish(YgTaskChangeKind.resizeEnd),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.alignment,
    required this.onUpdate,
    required this.onEnd,
  });

  final Alignment alignment;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (event) => onUpdate(event.delta.dx),
          onHorizontalDragEnd: (_) => onEnd(),
          child: const SizedBox(width: 8, height: double.infinity),
        ),
      ),
    );
  }
}

class _DefaultTaskBar extends StatelessWidget {
  const _DefaultTaskBar({
    required this.task,
    required this.color,
    required this.theme,
    required this.showProgress,
  });

  final YgTask task;
  final Color color;
  final YgGanttThemeData theme;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final background = switch (task.barStyle) {
      YgBarStyle.outline => Colors.transparent,
      YgBarStyle.soft => color.withValues(alpha: 0.18),
      YgBarStyle.solid || YgBarStyle.progress => color,
    };
    final foreground =
        task.barStyle == YgBarStyle.soft || task.barStyle == YgBarStyle.outline
            ? color
            : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: task.barStyle == YgBarStyle.outline
            ? Border.all(color: color, width: 1.5)
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (showProgress && task.progress > 0)
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: task.progress,
              child: ColoredBox(
                color: task.barStyle == YgBarStyle.soft ||
                        task.barStyle == YgBarStyle.outline
                    ? color.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.taskTextStyle.copyWith(color: foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewportEntry extends StatefulWidget {
  const _ViewportEntry({
    super.key,
    required this.child,
    required this.transition,
    required this.duration,
    required this.builder,
  });

  final Widget child;
  final YgEntryTransition transition;
  final Duration duration;
  final YgEntryTransitionBuilder? builder;

  @override
  State<_ViewportEntry> createState() => _ViewportEntryState();
}

class _ViewportEntryState extends State<_ViewportEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transition == YgEntryTransition.none && widget.builder == null) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        if (widget.builder != null) {
          return widget.builder!(context, child!, _animation);
        }
        return switch (widget.transition) {
          YgEntryTransition.none => child!,
          YgEntryTransition.fade => Opacity(
              opacity: _animation.value,
              child: child,
            ),
          YgEntryTransition.fadeSlide => Transform.translate(
              offset: Offset(0, (1 - _animation.value) * 6),
              child: Opacity(opacity: _animation.value, child: child),
            ),
          YgEntryTransition.scaleFade => Transform.scale(
              scale: 0.985 + _animation.value * 0.015,
              child: Opacity(opacity: _animation.value, child: child),
            ),
        };
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.start,
    required this.end,
    required this.mode,
    required this.width,
    required this.theme,
  });

  final DateTime start;
  final DateTime end;
  final YgViewMode mode;
  final double width;
  final YgGanttThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = theme.gridColor.withValues(alpha: 0.72);
    for (final marker in _markers(start, end, mode)) {
      final x = marker.date.difference(start).inMilliseconds /
          math.max(1, end.difference(start).inMilliseconds) *
          width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final todayX = DateTime.now().difference(start).inMilliseconds /
        math.max(1, end.difference(start).inMilliseconds) *
        width;
    if (todayX >= 0 && todayX <= width) {
      canvas.drawLine(
        Offset(todayX, 0),
        Offset(todayX, size.height),
        Paint()
          ..color = theme.todayColor.withValues(alpha: 0.72)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.mode != mode ||
        oldDelegate.width != width ||
        oldDelegate.theme != theme;
  }
}

class _TimelineHeaderPainter extends CustomPainter {
  _TimelineHeaderPainter({
    required this.start,
    required this.end,
    required this.mode,
    required this.width,
    required this.theme,
  });

  final DateTime start;
  final DateTime end;
  final YgViewMode mode;
  final double width;
  final YgGanttThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = theme.gridColor;
    final markers = _markers(start, end, mode);
    for (final marker in markers) {
      final x = marker.date.difference(start).inMilliseconds /
          math.max(1, end.difference(start).inMilliseconds) *
          width;
      canvas.drawLine(Offset(x, 30), Offset(x, size.height), linePaint);
      _paintText(
        canvas,
        marker.label,
        Offset(x + 5, 40),
        theme.headerTextStyle,
      );
    }
    final groups = _groupMarkers(start, end, mode);
    for (final marker in groups) {
      final x = marker.date.difference(start).inMilliseconds /
          math.max(1, end.difference(start).inMilliseconds) *
          width;
      canvas.drawLine(Offset(x, 0), Offset(x, 30), linePaint);
      _paintText(
        canvas,
        marker.label,
        Offset(x + 7, 9),
        theme.headerTextStyle.copyWith(
          color: theme.textColor,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    canvas.drawLine(Offset(0, 30), Offset(width, 30), linePaint);
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(width, size.height - 0.5),
      linePaint,
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 120);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TimelineHeaderPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.mode != mode ||
        oldDelegate.width != width ||
        oldDelegate.theme != theme;
  }
}

class _DependencyPainter extends CustomPainter {
  _DependencyPainter({
    required this.tasks,
    required this.taskIndexById,
    required this.start,
    required this.pixelsPerDay,
    required this.horizontalOffset,
    required this.verticalOffset,
    required this.rowHeight,
    required this.viewportWidth,
    required this.theme,
  });

  final List<YgTask> tasks;
  final Map<String, int> taskIndexById;
  final DateTime start;
  final double pixelsPerDay;
  final double horizontalOffset;
  final double verticalOffset;
  final double rowHeight;
  final double viewportWidth;
  final YgGanttThemeData theme;

  double _x(DateTime date) =>
      date.difference(start).inMilliseconds / _dayMs * pixelsPerDay -
      horizontalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final firstRow = math.max(0, (verticalOffset / rowHeight).floor() - 2);
    final lastRow = math.min(
      tasks.length - 1,
      ((verticalOffset + size.height) / rowHeight).ceil() + 2,
    );
    final paint = Paint()
      ..color = theme.dependencyColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final arrow = Paint()
      ..color = theme.dependencyColor.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    for (var targetIndex = firstRow; targetIndex <= lastRow; targetIndex++) {
      final target = tasks[targetIndex];
      for (final sourceId in target.dependencies) {
        final sourceIndex = taskIndexById[sourceId];
        if (sourceIndex == null) continue;
        final source = tasks[sourceIndex];
        final x1 = _x(source.end);
        final x2 = _x(target.start);
        if ((x1 < -80 && x2 < -80) ||
            (x1 > viewportWidth + 80 && x2 > viewportWidth + 80)) {
          continue;
        }
        final y1 = sourceIndex * rowHeight - verticalOffset + rowHeight / 2;
        final y2 = targetIndex * rowHeight - verticalOffset + rowHeight / 2;
        if ((y1 < -rowHeight && y2 < -rowHeight) ||
            (y1 > size.height + rowHeight && y2 > size.height + rowHeight)) {
          continue;
        }
        final bend = math.max(18, (x2 - x1).abs() * 0.35);
        final path = Path()
          ..moveTo(x1, y1)
          ..cubicTo(x1 + bend, y1, x2 - bend, y2, x2 - 5, y2);
        canvas.drawPath(path, paint);
        canvas.drawPath(
          Path()
            ..moveTo(x2, y2)
            ..lineTo(x2 - 7, y2 - 4)
            ..lineTo(x2 - 7, y2 + 4)
            ..close(),
          arrow,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DependencyPainter oldDelegate) => true;
}

class _Marker {
  const _Marker(this.date, this.label);

  final DateTime date;
  final String label;
}

List<_Marker> _markers(DateTime start, DateTime end, YgViewMode mode) {
  final result = <_Marker>[];
  if (mode == YgViewMode.year) {
    var month = DateTime(start.year, start.month);
    while (!month.isAfter(end) && result.length < 5000) {
      result.add(_Marker(month, '${month.month}月'));
      month = DateTime(month.year, month.month + 1);
    }
    return result;
  }
  late DateTime cursor;
  late Duration step;
  if (mode == YgViewMode.quarter || mode == YgViewMode.month) {
    final day = DateTime(start.year, start.month, start.day);
    cursor = day.subtract(Duration(days: day.weekday - 1));
    step = const Duration(days: 7);
  } else if (mode == YgViewMode.week) {
    cursor = DateTime(start.year, start.month, start.day);
    step = const Duration(days: 1);
  } else if (mode == YgViewMode.day) {
    cursor = DateTime(start.year, start.month, start.day);
    step = const Duration(hours: 6);
  } else {
    cursor = DateTime(start.year, start.month, start.day, start.hour);
    step = const Duration(hours: 1);
  }
  while (!cursor.isAfter(end) && result.length < 5000) {
    final label = switch (mode) {
      YgViewMode.quarter || YgViewMode.month => '${cursor.month}/${cursor.day}',
      YgViewMode.week => '${cursor.day}日',
      YgViewMode.day || YgViewMode.hour => '${cursor.hour}:00',
      YgViewMode.year => '',
    };
    result.add(_Marker(cursor, label));
    cursor = cursor.add(step);
  }
  return result;
}

List<_Marker> _groupMarkers(DateTime start, DateTime end, YgViewMode mode) {
  final result = <_Marker>[];
  DateTime cursor;
  if (mode == YgViewMode.year) {
    cursor = DateTime(start.year);
    while (!cursor.isAfter(end)) {
      result.add(_Marker(cursor, '${cursor.year}年'));
      cursor = DateTime(cursor.year + 1);
    }
    return result;
  }
  if (mode == YgViewMode.quarter ||
      mode == YgViewMode.month ||
      mode == YgViewMode.week) {
    cursor = DateTime(start.year, start.month);
    while (!cursor.isAfter(end)) {
      result.add(_Marker(cursor, '${cursor.year}年${cursor.month}月'));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return result;
  }
  cursor = DateTime(start.year, start.month, start.day);
  while (!cursor.isAfter(end)) {
    result.add(_Marker(cursor, '${cursor.month}月${cursor.day}日'));
    cursor = cursor.add(const Duration(days: 1));
  }
  return result;
}
