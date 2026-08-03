import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yotsuba_gantt/yotsuba_gantt.dart';

void main() => runApp(const GanttExampleApp());

/// Runnable Material example for Yotsuba Gantt.
class GanttExampleApp extends StatelessWidget {
  /// Creates the example application.
  const GanttExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yotsuba Gantt Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff218c61)),
        scaffoldBackgroundColor: const Color(0xfff5f7f6),
        useMaterial3: true,
      ),
      home: const GanttExamplePage(),
    );
  }
}

/// Demonstrates date ranges, zoom controls and 10,000 virtualized rows.
class GanttExamplePage extends StatefulWidget {
  /// Creates the example page.
  const GanttExamplePage({super.key});

  @override
  State<GanttExamplePage> createState() => _GanttExamplePageState();
}

class _GanttExamplePageState extends State<GanttExamplePage> {
  final _controller = YgGanttController();
  final List<YgTask> _tasks = _seedTasks();
  var _viewMode = YgViewMode.week;
  var _range = DateTimeRange(
    start: DateTime(2026, 7, 20),
    end: DateTime(2026, 10, 10),
  );
  String? _selectedId;
  var _landscapeLocked = false;

  static List<YgTask> _seedTasks() {
    const colors = <Color>[
      Color(0xff218c61),
      Color(0xff356fe5),
      Color(0xff8b62c9),
      Color(0xffdb7a41),
    ];
    final tasks = <YgTask>[
      YgTask(
        id: 'planning',
        title: '产品规划',
        owner: '小叶',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 28),
        progress: .48,
        kind: YgTaskKind.project,
        barStyle: YgBarStyle.progress,
      ),
      YgTask(
        id: 'research',
        title: '用户调研',
        owner: '林一',
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 9),
        progress: .85,
        barStyle: YgBarStyle.soft,
      ),
      YgTask(
        id: 'interaction',
        title: '交互设计',
        owner: '安然',
        start: DateTime(2026, 8, 8),
        end: DateTime(2026, 8, 17),
        progress: .62,
        color: colors[1],
        dependencies: const ['research'],
      ),
      YgTask(
        id: 'flutter',
        title: 'Flutter 组件',
        owner: '江东',
        start: DateTime(2026, 8, 15),
        end: DateTime(2026, 9, 2),
        progress: .36,
        color: colors[2],
        barStyle: YgBarStyle.progress,
        dependencies: const ['interaction'],
      ),
      YgTask(
        id: 'alpha',
        title: 'Alpha 发布',
        start: DateTime(2026, 9, 4),
        end: DateTime(2026, 9, 4),
        color: colors[3],
        kind: YgTaskKind.milestone,
        dependencies: const ['flutter'],
      ),
    ];
    for (var index = 0; index < 9995; index++) {
      final start = DateTime(2026, 8, 1).add(Duration(days: index % 48));
      tasks.add(
        YgTask(
          id: 'virtual-$index',
          title: '虚拟化任务 ${index + 1}',
          owner: '团队 ${(index % 8) + 1}',
          start: start,
          end: start.add(Duration(days: 2 + index % 9)),
          progress: (index % 10) / 10,
          color: colors[index % colors.length],
          barStyle: YgBarStyle.values[index % YgBarStyle.values.length],
        ),
      );
    }
    return tasks;
  }

  Future<void> _pickRange() async {
    final next = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      initialDateRange: _range,
      helpText: '选择甘特图时间范围',
      saveText: '应用',
    );
    if (next != null) setState(() => _range = next);
  }

  void _applyTaskChange(YgTaskChange change) {
    setState(() {
      final index = _tasks.indexWhere((task) => task.id == change.task.id);
      if (index >= 0) _tasks[index] = change.task;
    });
  }

  Future<void> _setLandscape(bool enabled) async {
    if (enabled) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() => _landscapeLocked = enabled);
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations(<DeviceOrientation>[]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yotsuba Gantt'),
        actions: <Widget>[
          IconButton(
            tooltip: '选择日期范围',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: '定位到今天',
            onPressed: () => _controller.scrollToDate(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: '适应任务范围',
            onPressed: _controller.fitToTasks,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
          IconButton(
            tooltip: _landscapeLocked ? '退出横屏沉浸模式' : '进入横屏沉浸模式',
            onPressed: () => _setLandscape(!_landscapeLocked),
            icon: Icon(
              _landscapeLocked
                  ? Icons.fullscreen_exit_outlined
                  : Icons.screen_rotation_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) => LayoutBuilder(
          builder: (context, pageConstraints) {
            final compact = pageConstraints.maxWidth < 720;
            return Padding(
              padding: EdgeInsets.all(compact ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (compact)
                        SizedBox(
                          width: 150,
                          height: 48,
                          child: DropdownButtonFormField<YgViewMode>(
                            initialValue: _viewMode,
                            decoration: const InputDecoration(
                              labelText: '时间维度',
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: YgViewMode.values
                                .map(
                                  (mode) => DropdownMenuItem<YgViewMode>(
                                    value: mode,
                                    child: Text(mode.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (mode) {
                              if (mode != null) {
                                setState(() => _viewMode = mode);
                              }
                            },
                          ),
                        )
                      else
                        SegmentedButton<YgViewMode>(
                          segments: YgViewMode.values
                              .map(
                                (mode) => ButtonSegment<YgViewMode>(
                                  value: mode,
                                  label: Text(mode.label),
                                ),
                              )
                              .toList(),
                          selected: <YgViewMode>{_viewMode},
                          onSelectionChanged: (value) {
                            setState(() => _viewMode = value.single);
                          },
                        ),
                      Text(
                        '${_range.start.month}/${_range.start.day} - ${_range.end.month}/${_range.end.day}',
                      ),
                      Text(
                        orientation == Orientation.landscape
                            ? '10,000 条任务 · 原生行虚拟化 · 双指切换维度'
                            : '10,000 条任务 · 原生行虚拟化',
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _selectedId == null
                        ? const SizedBox(height: 8)
                        : Container(
                            key: ValueKey<String>(_selectedId!),
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffeaf6f0),
                              border:
                                  Border.all(color: const Color(0xffb9dfcd)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.task_alt_outlined,
                                  size: 16,
                                  color: Color(0xff218c61),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _tasks
                                        .firstWhere(
                                          (task) => task.id == _selectedId,
                                        )
                                        .title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!compact)
                                  const Text(
                                    '双击查看详情',
                                    style: TextStyle(
                                      color: Color(0xff64736b),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => YotsubaGantt(
                        controller: _controller,
                        tasks: _tasks,
                        rangeStart: _range.start,
                        rangeEnd: _range.end.add(const Duration(days: 1)),
                        viewMode: _viewMode,
                        onViewModeChanged: (mode) =>
                            setState(() => _viewMode = mode),
                        selectedTaskId: _selectedId,
                        autoFocus: YgAutoFocus.dense,
                        enableScaleGesture: true,
                        sidebarWidth: compact ? 180 : 280,
                        minSidebarWidth: compact ? 140 : 180,
                        maxSidebarWidth: compact ? 300 : 480,
                        height: constraints.maxHeight,
                        onTaskTap: (task) =>
                            setState(() => _selectedId = task.id),
                        onTaskDoubleTap: (task) {
                          showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(task.title),
                              content: Text(
                                '负责人：${task.owner ?? '未分配'}\n进度：${(task.progress * 100).round()}%',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('关闭'),
                                ),
                              ],
                            ),
                          );
                        },
                        onTaskChanged: _applyTaskChange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
