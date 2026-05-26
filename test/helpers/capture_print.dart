// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

/// Runs [code] in a zone that forwards every `print(...)` call to [ggLog]
/// instead of writing to stdout. Used by tests to capture log output without
/// polluting test runner output.
Future<void> capturePrint({
  required void Function(String msg) ggLog,
  required Future<void> Function() code,
}) async {
  final spec = ZoneSpecification(
    print: (self, parent, zone, line) => ggLog(line),
  );
  await runZoned<Future<void>>(code, zoneSpecification: spec);
}
