import 'package:flutter_test/flutter_test.dart';
import 'package:yotsuba_gantt_example/main.dart';

void main() {
  testWidgets('renders the 10K Gantt product demo', (tester) async {
    await tester.pumpWidget(const GanttExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Yotsuba Gantt'), findsOneWidget);
    expect(find.textContaining('10,000 条任务'), findsOneWidget);
    expect(find.text('产品规划'), findsWidgets);
  });
}
