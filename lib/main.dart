import 'package:card_app/app/card_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _proPreviewUnlocked = bool.fromEnvironment('PRO_PREVIEW_UNLOCKED');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CardApp(
      enableRemoteData: true,
      // This flag is intentionally ignored in profile/release builds.
      proUnlocked: kDebugMode && _proPreviewUnlocked,
    ),
  );
}
