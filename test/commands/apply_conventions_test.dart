// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_dna/src/commands/apply_conventions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Directory target;
  late Directory source;
  late List<String> messages;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('apply_conventions_test_');
    target = Directory(p.join(tmp.path, 'target'))..createSync();
    // Default source lives under <target>/dna/agents/conventions.
    source = Directory(p.join(target.path, 'dna', 'agents', 'conventions'))
      ..createSync(recursive: true);
    messages = <String>[];
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  void writeDoc(String name, String body) {
    File(p.join(source.path, name)).writeAsStringSync(body);
  }

  ApplyConventions makeCmd() => ApplyConventions(ggLog: messages.add);

  CommandRunner<dynamic> makeRunner(ApplyConventions cmd) {
    return CommandRunner<dynamic>('test', 'test')..addCommand(cmd);
  }

  // ===========================================================================
  group('ApplyConventions', () {
    // -------------------------------------------------------------------------
    group('run()', () {
      test('throws when the source folder is missing', () async {
        source.deleteSync(recursive: true);
        await expectLater(
          makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]),
          throwsA(isA<UsageException>()),
        );
      });

      test('throws when no markdown files are present in source', () async {
        await expectLater(
          makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]),
          throwsA(isA<UsageException>()),
        );
      });

      test(
        'copies docs and creates CLAUDE.md with managed block',
        () async {
          writeDoc('code-conventions.md', '# code');
          writeDoc('test-conventions.md', '# test');

          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]);

          final destDir =
              Directory(p.join(target.path, '.claude', 'conventions'));
          expect(
            File(p.join(destDir.path, 'code-conventions.md'))
                .readAsStringSync(),
            '# code',
          );
          expect(
            File(p.join(destDir.path, 'test-conventions.md'))
                .readAsStringSync(),
            '# test',
          );

          final claudeMd =
              File(p.join(target.path, 'CLAUDE.md')).readAsStringSync();
          expect(
            claudeMd,
            contains('@.claude/conventions/code-conventions.md'),
          );
          expect(
            claudeMd,
            contains('@.claude/conventions/test-conventions.md'),
          );
          expect(claudeMd, contains(ApplyConventions.startMarker));
          expect(claudeMd, contains(ApplyConventions.endMarker));
        },
      );

      test('--only restricts the applied conventions', () async {
        writeDoc('code-conventions.md', '# code');
        writeDoc('test-conventions.md', '# test');

        await makeRunner(makeCmd()).run([
          'apply-conventions',
          '--target',
          target.path,
          '--only',
          'code-conventions.md',
        ]);

        final destDir =
            Directory(p.join(target.path, '.claude', 'conventions'));
        expect(
          File(p.join(destDir.path, 'code-conventions.md')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(destDir.path, 'test-conventions.md')).existsSync(),
          isFalse,
        );

        final claudeMd =
            File(p.join(target.path, 'CLAUDE.md')).readAsStringSync();
        expect(claudeMd, contains('@.claude/conventions/code-conventions.md'));
        expect(
          claudeMd.contains('@.claude/conventions/test-conventions.md'),
          isFalse,
        );
      });

      test(
        'preserves existing CLAUDE.md content outside the managed block',
        () async {
          writeDoc('code-conventions.md', '# code');
          File(p.join(target.path, 'CLAUDE.md')).writeAsStringSync(
            '# Project notes\n\nProject-specific guidance here.\n',
          );

          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]);

          final claudeMd =
              File(p.join(target.path, 'CLAUDE.md')).readAsStringSync();
          expect(claudeMd, contains('# Project notes'));
          expect(claudeMd, contains('Project-specific guidance here.'));
          expect(
            claudeMd,
            contains('@.claude/conventions/code-conventions.md'),
          );
        },
      );

      test(
        'replaces an existing managed block instead of duplicating it',
        () async {
          writeDoc('code-conventions.md', '# code');
          File(p.join(target.path, 'CLAUDE.md')).writeAsStringSync(
            '# Project\n\n'
            '${ApplyConventions.startMarker} v=2024-01-01 -->\n'
            '@.claude/conventions/old.md\n'
            '${ApplyConventions.endMarker}\n'
            '\nFooter\n',
          );

          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]);

          final claudeMd =
              File(p.join(target.path, 'CLAUDE.md')).readAsStringSync();
          expect(claudeMd, contains('# Project'));
          expect(claudeMd, contains('Footer'));
          expect(
            claudeMd.indexOf('@.claude/conventions/code-conventions.md') > 0,
            isTrue,
          );
          expect(
            claudeMd.contains('@.claude/conventions/old.md'),
            isFalse,
          );
          // Only one start marker should remain.
          final firstStart = claudeMd.indexOf(ApplyConventions.startMarker);
          final lastStart = claudeMd.lastIndexOf(ApplyConventions.startMarker);
          expect(firstStart, equals(lastStart));
        },
      );

      test(
        'is idempotent — second run reports CLAUDE.md unchanged',
        () async {
          writeDoc('code-conventions.md', '# code');

          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]);
          messages.clear();
          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]);

          expect(
            messages.last,
            contains('CLAUDE.md unchanged'),
          );
        },
      );

      test(
        'targets the workspace root when run from a Kidney workspace ticket',
        () async {
          // Build a fake workspace at <tmp>/workspace with a ticket folder
          // that contains its own dna/ source for conventions.
          final workspace = Directory(p.join(tmp.path, 'workspace'))
            ..createSync();
          Directory(p.join(workspace.path, '.master')).createSync();
          // Place dna/agents/conventions under the workspace (target).
          final wsSource = Directory(
            p.join(workspace.path, 'dna', 'agents', 'conventions'),
          )..createSync(recursive: true);
          File(p.join(wsSource.path, 'code-conventions.md'))
              .writeAsStringSync('# code');
          final ticket = Directory(
            p.join(workspace.path, 'tickets', 'ticket-1'),
          )..createSync(recursive: true);

          // Explicit --target: the ticket gets the conventions when its own
          // dna/ exists. Add one for that scenario:
          final ticketSource = Directory(
            p.join(ticket.path, 'dna', 'agents', 'conventions'),
          )..createSync(recursive: true);
          File(p.join(ticketSource.path, 'code-conventions.md'))
              .writeAsStringSync('# code');

          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            ticket.path,
          ]);
          expect(
            File(p.join(ticket.path, 'CLAUDE.md')).existsSync(),
            isTrue,
          );

          // Now omit --target by switching the working directory.
          final originalCwd = Directory.current;
          try {
            Directory.current = ticket;
            await makeRunner(makeCmd()).run(['apply-conventions']);
          } finally {
            Directory.current = originalCwd;
          }

          // Workspace-level CLAUDE.md must exist now.
          expect(
            File(p.join(workspace.path, 'CLAUDE.md')).existsSync(),
            isTrue,
          );
          expect(
            File(
              p.join(
                workspace.path,
                '.claude',
                'conventions',
                'code-conventions.md',
              ),
            ).existsSync(),
            isTrue,
          );
        },
      );

      test(
        'falls back to the current directory when no workspace is found',
        () async {
          final standalone = Directory(p.join(tmp.path, 'plain'))..createSync();
          // Place dna/ source under the standalone target.
          final standaloneSource = Directory(
            p.join(standalone.path, 'dna', 'agents', 'conventions'),
          )..createSync(recursive: true);
          File(p.join(standaloneSource.path, 'code-conventions.md'))
              .writeAsStringSync('# code');

          final originalCwd = Directory.current;
          try {
            Directory.current = standalone;
            await makeRunner(makeCmd()).run(['apply-conventions']);
          } finally {
            Directory.current = originalCwd;
          }
          expect(
            File(p.join(standalone.path, 'CLAUDE.md')).existsSync(),
            isTrue,
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    group('--source', () {
      test('uses the explicit source folder when --source is given', () async {
        final altSource = Directory(p.join(tmp.path, 'alt'))..createSync();
        File(p.join(altSource.path, 'extra.md')).writeAsStringSync('# extra');

        await makeRunner(makeCmd()).run([
          'apply-conventions',
          '--source',
          altSource.path,
          '--target',
          target.path,
        ]);

        expect(
          File(
            p.join(target.path, '.claude', 'conventions', 'extra.md'),
          ).readAsStringSync(),
          '# extra',
        );
      });
    });

    // -------------------------------------------------------------------------
    group('--check', () {
      test('passes silently when target is up to date', () async {
        writeDoc('code-conventions.md', '# code');
        await makeRunner(makeCmd()).run([
          'apply-conventions',
          '--target',
          target.path,
        ]);
        messages.clear();
        await makeRunner(makeCmd()).run([
          'apply-conventions',
          '--target',
          target.path,
          '--check',
        ]);
        expect(messages.last, contains('up to date'));
      });

      test('throws when CLAUDE.md is missing', () async {
        writeDoc('code-conventions.md', '# code');
        await expectLater(
          makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
            '--check',
          ]),
          throwsA(anything),
        );
      });

      test('throws when a copied doc is out of date', () async {
        writeDoc('code-conventions.md', '# old');
        await makeRunner(makeCmd()).run([
          'apply-conventions',
          '--target',
          target.path,
        ]);
        // Now bump the source.
        writeDoc('code-conventions.md', '# new');
        await expectLater(
          makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
            '--check',
          ]),
          throwsA(anything),
        );
      });

      test(
        'throws when CLAUDE.md block is missing despite copies existing',
        () async {
          writeDoc('code-conventions.md', '# code');
          await makeRunner(makeCmd()).run([
            'apply-conventions',
            '--target',
            target.path,
          ]);
          // Wipe CLAUDE.md but keep .claude/conventions copies.
          File(p.join(target.path, 'CLAUDE.md')).writeAsStringSync('');
          await expectLater(
            makeRunner(makeCmd()).run([
              'apply-conventions',
              '--target',
              target.path,
              '--check',
            ]),
            throwsA(anything),
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    group('findKidneyWorkspaceRoot()', () {
      test('walks up to a directory containing .master', () {
        final ws = Directory(p.join(tmp.path, 'ws'))..createSync();
        Directory(p.join(ws.path, '.master')).createSync();
        final nested = Directory(p.join(ws.path, 'a', 'b', 'c'))
          ..createSync(recursive: true);

        final found = ApplyConventions.findKidneyWorkspaceRoot(nested);
        expect(found, isNotNull);
        expect(p.canonicalize(found!.path), p.canonicalize(ws.path));
      });

      test('does not return a path inside the start directory', () {
        final isolated = Directory(p.join(tmp.path, 'isolated', 'deep'))
          ..createSync(recursive: true);
        final found = ApplyConventions.findKidneyWorkspaceRoot(isolated);
        if (found != null) {
          expect(
            p.canonicalize(found.path).startsWith(p.canonicalize(tmp.path)),
            isFalse,
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    group('discoverConventions()', () {
      test('returns only .md files, sorted alphabetically', () {
        File(p.join(source.path, 'b.md')).writeAsStringSync('b');
        File(p.join(source.path, 'a.md')).writeAsStringSync('a');
        File(p.join(source.path, 'c.txt')).writeAsStringSync('ignored');
        Directory(p.join(source.path, 'sub')).createSync();

        final found = ApplyConventions.discoverConventions(source);
        expect(found.map((f) => p.basename(f.path)).toList(), ['a.md', 'b.md']);
      });
    });

    // -------------------------------------------------------------------------
    group('buildBlock()', () {
      test('produces a marker-bracketed block of @-imports', () {
        final block = ApplyConventions.buildBlock(
          ['code-conventions.md', 'test-conventions.md'],
          '2026-04-29',
        );
        expect(
          block,
          equals(
            '${ApplyConventions.startMarker} v=2026-04-29 -->\n'
            '@.claude/conventions/code-conventions.md\n'
            '@.claude/conventions/test-conventions.md\n'
            '${ApplyConventions.endMarker}',
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    group('upsertBlock()', () {
      const block = '<!-- gg_dna:conventions:start v=2026 -->\n'
          '@.claude/conventions/foo.md\n'
          '<!-- gg_dna:conventions:end -->';

      test('appends the block to non-empty content', () {
        expect(
          ApplyConventions.upsertBlock('# Title\n', block),
          '# Title\n\n$block\n',
        );
      });

      test('writes only the block when the input is empty', () {
        expect(ApplyConventions.upsertBlock('', block), '$block\n');
      });

      test('replaces an existing block in place', () {
        const initial = '# A\n\n'
            '<!-- gg_dna:conventions:start v=old -->\n'
            'old line\n'
            '<!-- gg_dna:conventions:end -->\n'
            '# B\n';
        final result = ApplyConventions.upsertBlock(initial, block);
        expect(result, contains('# A'));
        expect(result, contains('# B'));
        expect(result, contains('@.claude/conventions/foo.md'));
        expect(result, isNot(contains('old line')));
      });

      test(
        'throws when a start marker has no matching end marker',
        () {
          const corrupt = '# A\n<!-- gg_dna:conventions:start v=1 -->\n# B\n';
          expect(
            () => ApplyConventions.upsertBlock(corrupt, block),
            throwsA(isA<StateError>()),
          );
        },
      );
    });
  });
}
