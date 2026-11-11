// Picked up by `flutter test` for the test files under test/a11y/runtime/
// only (the nearest flutter_test_config.dart wins).  It calls through to the
// repository's test/flutter_test_config.dart, which configures the findings
// sink, and adds what this audit needs: the per-screen log and real fonts.
//
// Tests outside this directory never see this file.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../flutter_test_config.dart' as app;
import 'support/harness.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return app.testExecutable(() async {
    tearDownAll(ScreenLog.flush);

    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();

    await testMain();
  });
}
