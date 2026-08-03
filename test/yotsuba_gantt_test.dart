import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yotsuba_gantt/yotsuba_gantt.dart';

void main() {
  test('task copyWith keeps host metadata and changes dates', () {
    final original = YgTask(
      id: 'design',
      title: '设计',
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 8),
      metadata: const <String, Object?>{'ticket': 'YG-1'},
    );
    final changed = original.copyWith(start: DateTime(2026, 8, 2));
    expect(changed.start, DateTime(2026, 8, 2));
    expect(changed.end, original.end);
    expect(changed.metadata['ticket'], 'YG-1');
  });

  test('view presets move from overview to detailed scales', () {
    final densities =
        YgViewMode.values.map((mode) => mode.pixelsPerDay).toList();
    expect(densities, orderedEquals(densities.toList()..sort()));
    expect(YgViewMode.hour.snapDuration, const Duration(hours: 1));
    expect(YgViewMode.year.snapDuration, const Duration(days: 7));
  });

  testWidgets(
    'virtualized chart builds visible rows and controller navigates',
    (tester) async {
      final controller = YgGanttController();
      final tasks = List<YgTask>.generate(10000, (index) {
        final start = DateTime(2026, 8, 1).add(Duration(days: index % 40));
        return YgTask(
          id: 'task-$index',
          title: '任务 $index',
          start: start,
          end: start.add(const Duration(days: 3)),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YotsubaGantt(
              controller: controller,
              tasks: tasks,
              rangeStart: DateTime(2026, 7, 20),
              rangeEnd: DateTime(2026, 10, 1),
              height: 460,
              entryTransition: YgEntryTransition.none,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.isAttached, isTrue);
      expect(find.text('任务 0'), findsWidgets);
      expect(find.text('任务 9999'), findsNothing);
      expect(find.byType(ListView), findsNWidgets(2));

      await controller.scrollToRow(9999, duration: Duration.zero);
      await tester.pump();
      expect(find.text('任务 9999'), findsWidgets);
    },
  );

  testWidgets('double tap and custom builders are exposed', (tester) async {
    var doubleTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YotsubaGantt(
            tasks: <YgTask>[
              YgTask(
                id: 'release',
                title: '发布',
                start: DateTime(2026, 8, 1),
                end: DateTime(2026, 8, 10),
              ),
            ],
            rangeStart: DateTime(2026, 7, 20),
            rangeEnd: DateTime(2026, 8, 20),
            height: 320,
            autoFocus: YgAutoFocus.none,
            taskBarBuilder: (context, details) =>
                Text('自定义 ${details.task.title}'),
            onTaskDoubleTap: (_) => doubleTapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('自定义 发布'), findsOneWidget);
    await tester.tap(find.text('自定义 发布'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('自定义 发布'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(doubleTapped, isTrue);
  });

  testWidgets('linked charts synchronize view changes', (tester) async {
    final group = YgGanttLinkGroup();
    final source = YgGanttController();
    YgViewMode? linkedView;
    final tasks = <YgTask>[
      YgTask(
        id: 'linked',
        title: '联动任务',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: <Widget>[
            YotsubaGantt(
              controller: source,
              tasks: tasks,
              height: 260,
              autoFocus: YgAutoFocus.none,
              linkGroup: group,
              syncMode: YgSyncMode.all,
            ),
            YotsubaGantt(
              tasks: tasks,
              height: 260,
              autoFocus: YgAutoFocus.none,
              linkGroup: group,
              syncMode: YgSyncMode.all,
              onViewModeChanged: (view) => linkedView = view,
            ),
          ],
        ),
      ),
    );
    source.setView(YgViewMode.day);
    await tester.pump();
    expect(linkedView, YgViewMode.day);
    expect(group.viewMode, YgViewMode.day);
  });

  testWidgets('two-finger scale changes one adjacent view mode',
      (tester) async {
    YgViewMode? changedView;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YotsubaGantt(
            tasks: <YgTask>[
              YgTask(
                id: 'touch',
                title: '触控任务',
                start: DateTime(2026, 8, 1),
                end: DateTime(2026, 8, 10),
              ),
            ],
            height: 320,
            viewMode: YgViewMode.week,
            autoFocus: YgAutoFocus.none,
            onViewModeChanged: (view) => changedView = view,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(YotsubaGantt));
    final first = TestPointer(1, PointerDeviceKind.touch);
    final second = TestPointer(2, PointerDeviceKind.touch);
    final firstPosition = Offset(rect.right - 300, rect.center.dy);
    final secondPosition = Offset(rect.right - 100, rect.center.dy);
    await tester.sendEventToBinding(first.down(firstPosition));
    await tester.sendEventToBinding(second.down(secondPosition));
    await tester.sendEventToBinding(
      second.move(secondPosition + const Offset(50, 0)),
    );
    await tester.pump();
    expect(changedView, YgViewMode.day);
    await tester.sendEventToBinding(first.cancel());
    await tester.sendEventToBinding(second.cancel());
  });

  testWidgets('offscreen indicator builder receives a working jump action',
      (tester) async {
    final controller = YgGanttController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YotsubaGantt(
            controller: controller,
            tasks: <YgTask>[
              YgTask(
                id: 'early',
                title: '早期任务',
                start: DateTime(2026, 1, 2),
                end: DateTime(2026, 1, 5),
              ),
              YgTask(
                id: 'late',
                title: '后期任务',
                start: DateTime(2026, 11, 2),
                end: DateTime(2026, 11, 8),
              ),
            ],
            rangeStart: DateTime(2026, 1, 1),
            rangeEnd: DateTime(2026, 12, 31),
            viewMode: YgViewMode.week,
            height: 340,
            autoFocus: YgAutoFocus.none,
            edgeIndicatorBuilder: (context, details) => TextButton(
              onPressed: details.jump,
              child: Text('边界-${details.side.name}'),
            ),
          ),
        ),
      ),
    );
    await controller.scrollToDate(DateTime(2026, 6, 1),
        duration: Duration.zero);
    await tester.pump();
    expect(find.textContaining('边界-'), findsWidgets);
    await tester.tap(find.textContaining('边界-').first);
    await tester.pumpAndSettle();
  });
}
