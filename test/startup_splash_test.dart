import 'dart:io';

import 'package:cardfi/app/startup_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool hasPngAlpha(File file) {
    final bytes = file.readAsBytesSync();
    if (bytes.length < 26) return false;
    final colorType = bytes[25];
    return colorType == 4 || colorType == 6;
  }

  testWidgets(
    'startup transition pauses in background and only finishes once',
    (tester) async {
      var finishedCount = 0;
      Widget app() => MaterialApp(
        home: CardFiStartupTransition(
          onFinished: () => finishedCount += 1,
          child: const ColoredBox(
            key: Key('startup-home'),
            color: Colors.white,
          ),
        ),
      );

      await tester.pumpWidget(app());
      expect(find.byKey(const Key('startup-splash')), findsOneWidget);
      expect(find.byKey(const Key('startup-home')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('startup-splash')), findsOneWidget);
      expect(finishedCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-splash')), findsNothing);
      expect(finishedCount, 1);
      expect(tester.hasRunningAnimations, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.byKey(const Key('startup-splash')), findsNothing);
      expect(finishedCount, 1);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('startup transition honors reduced motion', (tester) async {
    var finishedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CardFiStartupTransition(
            onFinished: () => finishedCount += 1,
            child: const SizedBox(key: Key('reduced-motion-home')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.byKey(const Key('reduced-motion-home')), findsOneWidget);
    expect(finishedCount, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('native launch screens share the CardFi background and logo', () {
    final root = Directory.current.path;
    final iosStoryboard = File(
      '$root/ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(iosStoryboard, contains('red="0.0196078431"'));
    expect(iosStoryboard, contains('green="0.0627450980"'));
    expect(iosStoryboard, contains('blue="0.1490196078"'));
    expect(
      iosStoryboard,
      contains('<image name="LaunchImage" width="160" height="160"/>'),
    );

    for (final scale in ['', '@2x', '@3x']) {
      final logo = File(
        '$root/ios/Runner/Assets.xcassets/LaunchImage.imageset/'
        'LaunchImage$scale.png',
      );
      expect(logo.existsSync(), isTrue);
      expect(logo.lengthSync(), greaterThan(1000));
      expect(hasPngAlpha(logo), isTrue, reason: logo.path);
    }

    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final logo = File(
        '$root/android/app/src/main/res/drawable-$density/'
        'cardfi_splash_logo.png',
      );
      expect(logo.existsSync(), isTrue);
      expect(logo.lengthSync(), greaterThan(1000));
      expect(hasPngAlpha(logo), isTrue, reason: logo.path);
    }

    final flutterLogo = File('$root/assets/branding/cardfi-launch-icon.png');
    expect(hasPngAlpha(flutterLogo), isTrue, reason: flutterLogo.path);

    final androidLaunch = File(
      '$root/android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    expect(androidLaunch, contains('@color/cardfi_launch_background'));
    expect(androidLaunch, contains('@drawable/cardfi_splash_logo'));

    final android31 = File(
      '$root/android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    expect(android31, contains('android:windowSplashScreenBackground'));
    expect(android31, contains('android:windowSplashScreenAnimatedIcon'));
  });
}
