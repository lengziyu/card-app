import 'dart:ui' as ui;

import 'package:cardfi/features/home/widgets/home_card_scene_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'edge fade is transparent, contains overflow and keeps controls',
    (tester) async {
      tester.view
        ..physicalSize = const Size(200, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final background in [Colors.blue, Colors.black]) {
        final captureKey = GlobalKey();
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: captureKey,
              child: ColoredBox(
                color: background,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 40,
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: HomeCardSceneFade(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: const [
                            Positioned(
                              top: -80,
                              bottom: -80,
                              left: 0,
                              right: 0,
                              child: ColoredBox(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 45,
                      left: 6,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        key: const Key('floating-control'),
                        onTap: () => presses++,
                        child: const ColoredBox(color: Color(0xFF00FF00)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('floating-control')));
        expect(presses, 1);
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return bytes!;
        });
        int channel(int x, int y, int component) =>
            pixels!.getUint8((y * 200 + x) * 4 + component);

        // 越界卡面也必须消失；渐变不是用一层白色遮住背景。
        for (final y in [20, 620]) {
          expect(channel(100, y, 0), background.r * 255);
          expect(channel(100, y, 2), background.b * 255);
        }
        expect(channel(100, 320, 0), 244); // Colors.red 原始卡面颜色。
        for (final y in [42, 595]) {
          expect(channel(100, y, 0), lessThan(40));
        }
        expect(channel(20, 60, 1), 255);
        expect(channel(20, 60, 0), 0);
      }
    },
  );
}
