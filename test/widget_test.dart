import 'package:flutter_test/flutter_test.dart';
import 'package:edugram/resources/firebase_utils.dart';

void main() {
  test('dataWithDate keeps DateTime values unchanged', () {
    final publishedAt = DateTime(2026, 4, 20, 8);

    final result = dataWithDate({
      'postId': 'post-1',
      'datePublished': publishedAt,
    });

    expect(result['datePublished'], publishedAt);
  });

  test('dataWithDate fills missing dates with a DateTime', () {
    final result = dataWithDate({'postId': 'post-1'});

    expect(result['datePublished'], isA<DateTime>());
  });
}

