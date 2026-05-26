// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_dna/gg_dna.dart';
import 'package:test/test.dart';
import 'package:gg_args/gg_args.dart';

import 'helpers/capture_print.dart';

void main() {
  final messages = <String>[];

  setUp(() {
    messages.clear();
  });

  group('GgDna()', () {
    // #########################################################################
    group('GgDna', () {
      final ggDna = GgDna(ggLog: messages.add);

      final CommandRunner<void> runner = CommandRunner<void>(
        'ggDna',
        'Description goes here.',
      )..addCommand(ggDna);

      test('should allow to run a subcommand from the command line', () async {
        final tmp = await Directory.systemTemp.createTemp('gg_dna_test_');
        try {
          await capturePrint(
            ggLog: messages.add,
            code: () async => await runner.run([
              'ggDna',
              'install-skills',
              '--source',
              tmp.path,
              '--all',
            ]),
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

      // .......................................................................
      test('should show all sub commands', () async {
        final (subCommands, errorMessage) = await missingSubCommands(
          directory: Directory('lib/src/commands'),
          command: ggDna,
        );

        expect(subCommands, isEmpty, reason: errorMessage);
      });
    });
  });
}
