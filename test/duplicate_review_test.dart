import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/presentation/providers/scan_provider.dart';
import 'package:snapsweep/presentation/screens/preview/duplicate_preview_screen.dart';

class ReviewFixture extends ScanProvider {
  ReviewFixture()
    : super(
        getDirectory: () async =>
            throw const FileSystemException('No saved fixture'),
      );
  List<List<AssetEntity>> exact = [];
  List<List<AssetEntity>> similar = [];
  @override
  List<List<AssetEntity>> get duplicateGroups => exact;
  @override
  List<List<AssetEntity>> get similarGroups => similar;
  @override
  Map<String, int> get assetSizes => {
    for (final group in [...exact, ...similar])
      for (final asset in group) asset.id: 100,
  };
  void publish({
    required List<List<AssetEntity>> duplicates,
    required List<List<AssetEntity>> matches,
  }) {
    exact = duplicates;
    similar = matches;
    notifyListeners();
  }
}

List<AssetEntity> group(String prefix) => [
  for (var i = 1; i <= 2; i++)
    AssetEntity(id: '$prefix$i', typeInt: 1, width: 100, height: 100),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReviewFixture provider;
  setUpAll(() async {
    // Supply deterministic test fonts without Google Fonts network requests.
    final font = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    final assets = {
      for (final family in ['BricolageGrotesque', 'DMSans'])
        for (var weight = 100; weight <= 900; weight += 100)
          '$family-$weight.ttf': [
            {'asset': '$family-$weight.ttf'},
          ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (data) async {
          final key = utf8.decode(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          return key == 'AssetManifest.bin'
              ? const StandardMessageCodec().encodeMessage(assets)
              : font;
        });
    GoogleFonts.config.allowRuntimeFetching = false;
    final bytes = img.encodePng(img.Image(width: 4, height: 4));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.fluttercandies/photo_manager'),
          (call) async => call.method == 'getThumb' ? bytes : null,
        );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = ReviewFixture();
  });
  tearDown(() => provider.dispose());
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.fluttercandies/photo_manager'),
          null,
        );
  });
  Widget page({bool isSimilar = false}) =>
      ChangeNotifierProvider<ScanProvider>.value(
        value: provider,
        child: MaterialApp(home: DuplicatePreviewScreen(isSimilar: isSimilar)),
      );

  testWidgets('dashboard entry shows every counted exact and similar group', (
    tester,
  ) async {
    provider.publish(duplicates: [group('e')], matches: [group('s')]);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('All ${provider.reviewGroupCount}'), findsOneWidget);
    expect(find.textContaining('EXACT GROUP'), findsOneWidget);
    expect(find.textContaining('SIMILAR GROUP'), findsOneWidget);
    expect(
      find.text('1 selected'),
      findsWidgets,
      reason: 'Only exact copies are preselected',
    );
    expect(find.textContaining('No matching'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'results switching from similar-only to exact-only cannot leave an empty review',
    (tester) async {
      provider.publish(duplicates: [], matches: [group('s')]);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.textContaining('SIMILAR GROUP'), findsOneWidget);
      provider.publish(duplicates: [group('e')], matches: []);
      await tester.pumpAndSettle();
      expect(find.textContaining('EXACT GROUP'), findsOneWidget);
      expect(find.textContaining('No matching'), findsNothing);
      expect(find.text('All 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty explicit filter offers existing matches without rescanning',
    (tester) async {
      provider.publish(duplicates: [group('e')], matches: []);
      await tester.pumpWidget(page(isSimilar: true));
      await tester.pumpAndSettle();
      expect(find.text('No similar photos in this view.'), findsOneWidget);
      expect(find.text('Recheck matches'), findsNothing);
      await tester.ensureVisible(find.text('Show all matches'));
      await tester.tap(find.text('Show all matches'));
      await tester.pumpAndSettle();
      expect(find.textContaining('EXACT GROUP'), findsOneWidget);
      expect(find.text('No similar photos in this view.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
