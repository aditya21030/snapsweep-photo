import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snapsweep/data/services/categorization_service.dart';

void main() {
  final service = CategorizationService();
  AssetEntity image(String title, {String? path}) => AssetEntity(
    id: title,
    typeInt: 1,
    width: 1080,
    height: 2400,
    title: title,
    relativePath: path,
  );

  test('tall photos and wallpaper names are not screenshots or WhatsApp', () {
    expect(
      service.quickCategorize(image('wallpaper.png'), albumName: 'Pictures'),
      isNull,
    );
    expect(
      service.quickCategorize(image('IMG_20260101.jpg'), albumName: 'Pictures'),
      isNull,
    );
  });

  test('screenshots take priority over social app names', () {
    expect(
      service.quickCategorize(
        image('Screenshot_WhatsApp.png'),
        albumName: 'Screenshots',
      ),
      'Screenshots',
    );
    expect(
      service.quickCategorize(image('IMG-20260101-WA0001.jpg')),
      'Social & WhatsApp',
    );
    expect(
      service.quickCategorize(image('photo.jpg', path: 'Pictures/Telegram/')),
      'Social & WhatsApp',
    );
  });

  test('finance folders and screen recordings use specific evidence', () {
    expect(
      service.quickCategorize(image('receipt.jpg'), albumName: 'Receipts'),
      'Bills & Finance',
    );
    AssetEntity video(String name) => AssetEntity(
      id: name,
      typeInt: 2,
      width: 1080,
      height: 1920,
      title: name,
    );
    expect(
      service.quickCategorize(video('VID-20260101-WA0001.mp4')),
      'Social & WhatsApp',
    );
    expect(
      service.quickCategorize(video('clip.mp4'), albumName: 'Instagram'),
      'Social & WhatsApp',
    );
    expect(
      service.quickCategorize(video('screen_recording_001.mp4')),
      'Screen Recordings',
    );
    expect(
      service.quickCategorize(video('concert.mp4'), albumName: 'Recordings'),
      'Videos',
    );
  });
  test(
    'specific content categories replace Others without inventing a match',
    () {
      expect(
        CategorizationService.availableCategories,
        isNot(contains('Others')),
      );
      expect(CategorizationService.categoryForLabel('Dog'), 'Pets & Animals');
      expect(
        CategorizationService.categoryForLabel('Mountain'),
        'Nature & Landscapes',
      );
      expect(CategorizationService.categoryForLabel('Car'), 'Vehicles');
      expect(
        CategorizationService.categoryForLabel('Castle'),
        'Travel & Places',
      );
      expect(
        CategorizationService.categoryForLabel('Basketball'),
        'Sports & Fitness',
      );
      expect(CategorizationService.categoryForLabel('unknown label'), isNull);
      expect(
        CategorizationService.fallbackCategory(image('unrecognized.jpg')),
        'Photo Library',
      );
      expect(
        service.quickCategorize(image('photo.jpg'), albumName: 'Pets'),
        'Pets & Animals',
      );
    },
  );
  test('specific subject wins over a generic sky background', () {
    expect(
      CategorizationService.classifyEvidence({
        'Dog': 0.92,
        'Sky': 0.97,
        'Nature': 0.9,
      }),
      'Pets & Animals',
    );
    expect(
      CategorizationService.classifyEvidence({'Car': 0.94, 'Sky': 0.91}),
      'Vehicles',
    );
  });
  test('ordinary objects and artwork do not become portraits or memes', () {
    expect(
      CategorizationService.classifyEvidence({
        'Sunglasses': 0.99,
        'Standing': 0.95,
      }),
      'Photo Library',
    );
    expect(
      CategorizationService.classifyEvidence({'Art': 0.95, 'Drawing': 0.91}),
      'Art & Design',
    );
    expect(
      CategorizationService.classifyEvidence(
        {'Person': 0.9},
        text: 'lol this is my friend',
        hasFace: true,
      ),
      'Personal & Portraits',
    );
  });
  test('OCR distinguishes a menu price from a payment and an ID', () {
    expect(
      CategorizationService.classifyEvidence({
        'Menu': 0.95,
      }, text: 'Lunch special Rs 250'),
      'Food & Dining',
    );
    expect(
      CategorizationService.classifyEvidence({
        'Receipt': 0.95,
      }, text: 'Grand total Rs 250'),
      'Bills & Finance',
    );
    expect(
      CategorizationService.classifyEvidence(
        {'Person': 0.95, 'Paper': 0.9},
        text: 'Government of India Aadhaar',
        hasFace: true,
      ),
      'Documents & IDs',
    );
  });
  test(
    'actual model labels cover breeds, foods, landmarks and celebrations',
    () {
      expect(
        CategorizationService.classifyEvidence({'Shetland sheepdog': 0.93}),
        'Pets & Animals',
      );
      expect(
        CategorizationService.classifyEvidence({'Bento': 0.95}),
        'Food & Dining',
      );
      expect(
        CategorizationService.classifyEvidence({'Cathedral': 0.95}),
        'Travel & Places',
      );
      expect(
        CategorizationService.classifyEvidence({
          'Marriage': 0.95,
          'Person': 0.94,
        }, hasFace: true),
        'Events & Celebrations',
      );
    },
  );
  test('uncertain evidence does not force a semantic category', () {
    expect(
      CategorizationService.classifyEvidence({'Dog': 0.3}),
      'Photo Library',
    );
    expect(
      CategorizationService.classifyEvidence({'Dog': 0.9, 'Car': 0.9}),
      'Photo Library',
    );
    expect(CategorizationService.classifyEvidence({}), 'Photo Library');
  });
  test('downloads are source metadata rather than a meme verdict', () {
    expect(
      service.quickCategorize(image('photo.jpg'), albumName: 'Download'),
      'Downloads',
    );
    expect(CategorizationService.sourceCategories, contains('Downloads'));
    expect(
      CategorizationService.classifyEvidence({'Person': 0.95}, hasFace: true),
      'Personal & Portraits',
    );
  });
}
