import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snapsweep/data/services/categorization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.yousful.snapsweep/classifier');
  test(
    'one native batch assigns one category per image, with no Dart image/file round trip',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return [
              {
                'id': '1',
                'ok': true,
                'labels': {'Receipt': 0.97},
                'text': 'Grand total Rs 500',
              },
              {
                'id': '2',
                'ok': true,
                'labels': {'Dog': 0.96, 'Sky': 0.94},
                'text': '',
              },
              {'id': '3', 'ok': true, 'labels': {}, 'text': ''},
              {'id': '4', 'ok': false},
            ];
          });
      final service = CategorizationService();
      AssetEntity asset(String id, String path) => AssetEntity(
        id: id,
        typeInt: 1,
        width: 100,
        height: 100,
        relativePath: path,
      );
      final results = await service.categorizeBatch([
        asset('1', 'Pictures/Screenshots/'),
        asset('2', 'WhatsApp/Media/WhatsApp Images/'),
        asset('3', 'Download/'),
        asset('4', 'DCIM/Camera/'),
      ]);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'analyzeBatch');
      expect(results, {
        '1': 'Bills & Finance',
        '2': 'Pets & Animals',
        '3': 'Downloads',
      });
      final items = calls.single.arguments['items'] as List;
      expect(
        items.first['readText'],
        false,
        reason: 'Screenshots alone must not force expensive OCR',
      );
      expect(
        results.containsKey('4'),
        false,
        reason:
            'Unavailable assets must not be cached as successfully categorized',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
