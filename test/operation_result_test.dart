import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsweep/presentation/common/operation_result.dart';

void main() {
  testWidgets(
    'cleanup result completes after Continue even when no ad is ready',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showOperationResult(
                    context,
                    message: 'Removed 3 items.',
                  );
                  completed = true;
                },
                child: const Text('Finish'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Removed 3 items.'), findsOneWidget);
      expect(completed, false);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(find.text('Completed'), findsNothing);
    },
  );
}
