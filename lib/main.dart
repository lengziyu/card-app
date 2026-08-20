import 'dart:async';

import 'package:cardfi/app/card_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _proPreviewUnlocked = bool.fromEnvironment('PRO_PREVIEW_UNLOCKED');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _warmLaunchLogo();
  runApp(
    CardApp(
      enableRemoteData: true,
      proUnlocked: kDebugMode && _proPreviewUnlocked,
    ),
  );
}

Future<void> _warmLaunchLogo() async {
  const source = AssetImage('assets/branding/cardfi-launch-icon.png');
  final provider = ResizeImage.resizeIfNeeded(384, null, source);
  final stream = provider.resolve(ImageConfiguration.empty);
  final ready = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!ready.isCompleted) ready.complete();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!ready.isCompleted) ready.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  await ready.future.timeout(
    const Duration(milliseconds: 800),
    onTimeout: () => stream.removeListener(listener),
  );
}
