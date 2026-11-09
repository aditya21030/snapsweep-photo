import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsweep/presentation/common/operation_result.dart';

void main() {
  testWidgets(
    'cleanup result completes directly without continue dialog',
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
      await tester.pump();
      expect(completed, true);
      expect(find.text('Completed'), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Removed 3 items.'), findsOneWidget);
    },
  );
}
