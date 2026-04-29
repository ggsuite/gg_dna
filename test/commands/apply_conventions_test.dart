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
  late Directory pkgRoot;
  late Directory source;
  late Directory target;
  late List<String> messages;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('apply_conventions_test_');
    pkgRoot = Directory(p.join(tmp.path, 'pkg'))..createSync();
    source = Directory(p.join(pkgRoot.path, 'claude', 'conventions'))
      ..createSync(recursive: true);
    target = Directory(p.join(tmp.path, 'target'))..createSync();
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

  ApplyConventions makeCmd() {
    return ApplyConventions(
      ggLog: messages.add,
      packageRootResolver: () => pkgRoot.path,
    );
  }

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
        // Empty source folder — no .md files.
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

          final destDir = Directory(p.join(target.path, '.gg', 'claude'));
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
          expect(claudeMd, contains('@.gg/claude/code-conventions.md'));
          expect(claudeMd, contains('@.gg/claude/test-conventions.md'));
          expect(claudeMd, contains(ApplyConventions.startMarker));
          expect(claudeMd, contains(ApplyConventions.endMarker));
        },
      );

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
          expect(claudeMd, contains('@.gg/claude/code-conventions.md'));
        },
      );

      test(
        'replaces an existing managed block instead of duplicating it',
        () async {
          writeDoc('code-conventions.md', '# code');
          File(p.join(target.path, 'CLAUDE.md')).writeAsStringSync(
            '# Project\n\n'
            '${ApplyConventions.startMarker} v=2024-01-01 -->\n'
            '@.gg/claude/old.md\n'
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
            claudeMd.indexOf('@.gg/claude/code-conventions.md') > 0,
            isTrue,
          );
          expect(claudeMd.contains('@.gg/claude/old.md'), isFalse);
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
          writeDoc('code-conventions.md', '# code');
          // Build a fake workspace at <tmp>/workspace with a ticket folder.
          final workspace = Directory(p.join(tmp.path, 'workspace'))
            ..createSync();
          Directory(p.join(workspace.path, '.master')).createSync();
          final ticket = Directory(
            p.join(workspace.path, 'tickets', 'ticket-1'),
          )..createSync(recursive: true);

          await makeRunner(makeCmd()).run([
            'apply-conventions',
            // Pretend we are inside the ticket folder by passing it as
            // --target. The Kidney detection runs against --target only when
            // it is omitted; this test exercises the explicit target path.
            '--target',
            ticket.path,
          ]);

          // Explicit --target wins: the ticket gets the conventions, not the
          // workspace.
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
              p.join(workspace.path, '.gg', 'claude', 'code-conventions.md'),
            ).existsSync(),
            isTrue,
          );
        },
      );

      test(
        'falls back to the current directory when no workspace is found',
        () async {
          writeDoc('code-conventions.md', '# code');
          final standalone = Directory(p.join(tmp.path, 'plain'))..createSync();
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
            p.join(target.path, '.gg', 'claude', 'extra.md'),
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
          // Wipe CLAUDE.md but keep .gg/claude copies.
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
        // Construct an isolated chain under tmp without any `.master/` in
        // tmp itself or its descendants. The function may walk up to a real
        // ancestor of tmp (e.g. the developer's machine) and may find a
        // workspace there, but it must never report a directory inside our
        // synthetic chain.
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
            '@.gg/claude/code-conventions.md\n'
            '@.gg/claude/test-conventions.md\n'
            '${ApplyConventions.endMarker}',
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    group('upsertBlock()', () {
      const block = '<!-- gg_dna:conventions:start v=2026 -->\n'
          '@.gg/claude/foo.md\n'
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
        expect(result, contains('@.gg/claude/foo.md'));
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
