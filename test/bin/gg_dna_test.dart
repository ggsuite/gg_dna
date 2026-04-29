// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:test/test.dart';

import '../../bin/gg_dna.dart';

void main() {
  group('run(args, log)', () {
    test('runs install-skills against an empty source folder', () async {
      final tmp = await Directory.systemTemp.createTemp('gg_dna_bin_test_');
      try {
        final messages = <String>[];
        await run(
          args: ['install-skills', '--source', tmp.path, '--all'],
          ggLog: messages.add,
        );

        expect(
          messages.any((m) => m.contains('No skills found')),
          isTrue,
          reason: 'messages: $messages',
        );
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
