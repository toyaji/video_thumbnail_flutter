import 'package:flutter_test/flutter_test.dart';

import 'package:video_thumbnail_flutter_example/main.dart';

void main() {
  testWidgets('샘플 영상 URL과 생성 버튼을 보여준다', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text(sampleVideoUrl), findsOneWidget);
    expect(find.text('Generate thumbnail'), findsOneWidget);
  });
}
