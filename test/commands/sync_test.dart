// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_dna/src/commands/apply_conventions.dart';
import 'package:gg_dna/src/commands/sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Directory pkgRoot;
  late Directory pkgDna;
  late Directory target;
  late List<String> messages;
  late List<String> selectorPrompts;
  late Map<String, bool> selectorAnswers;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sync_test_');
    pkgRoot = Directory(p.join(tmp.path, 'pkg'))..createSync();
    pkgDna = Directory(p.join(pkgRoot.path, 'dna'))..createSync();
    target = Directory(p.join(tmp.path, 'target'))..createSync();
    messages = <String>[];
    selectorPrompts = <String>[];
    selectorAnswers = <String, bool>{};
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  void writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  bool selector(String prompt) {
    selectorPrompts.add(prompt);
    for (final entry in selectorAnswers.entries) {
      if (prompt.contains(entry.key)) return entry.value;
    }
    return false;
  }

  Sync makeCmd({GitCloner? gitCloner}) => Sync(
        ggLog: messages.add,
        packageRootResolver: () async => pkgRoot.path,
        selector: selector,
        gitCloner: gitCloner,
      );

  CommandRunner<dynamic> makeRunner(Sync cmd) =>
      CommandRunner<dynamic>('test', 'test')..addCommand(cmd);

  void writeSkillIn(Directory parent, String name) {
    final dir = Directory(p.join(parent.path, name))..createSync();
    File(p.join(dir.path, 'SKILL.md')).writeAsStringSync('# $name');
  }

  // ===========================================================================
  group('Sync', () {
    test('throws when source dna folder does not exist', () async {
      // pkgRoot exists, but a custom --source pointing at a path without dna/.
      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--source',
          p.join(tmp.path, 'missing'),
          '--target',
          target.path,
          '--no-install',
        ]),
        throwsA(isA<UsageException>()),
      );
    });

    test('mirrors source dna/ into <target>/dna and skips install', () async {
      writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');
      writeFile(p.join(pkgDna.path, 'scripts', 'run.sh'), 'echo hi');
      writeFile(p.join(pkgDna.path, 'agents', 'sub', 'b.md'), 'B');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--no-install',
      ]);

      expect(
        File(p.join(target.path, 'dna', 'guides', 'a.md')).readAsStringSync(),
        'A',
      );
      expect(
        File(p.join(target.path, 'dna', 'scripts', 'run.sh'))
            .readAsStringSync(),
        'echo hi',
      );
      expect(
        File(p.join(target.path, 'dna', 'agents', 'sub', 'b.md'))
            .readAsStringSync(),
        'B',
      );
      expect(messages.any((m) => m.contains('Synced')), isTrue);
      expect(selectorPrompts, isEmpty);
    });

    test('replaces stale files in an existing target dna/', () async {
      writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A-new');
      writeFile(p.join(target.path, 'dna', 'guides', 'a.md'), 'A-old');
      writeFile(p.join(target.path, 'dna', 'guides', 'gone.md'), 'gone');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--no-install',
      ]);

      expect(
        File(p.join(target.path, 'dna', 'guides', 'a.md')).readAsStringSync(),
        'A-new',
      );
      expect(
        File(p.join(target.path, 'dna', 'guides', 'gone.md')).existsSync(),
        isFalse,
      );
    });

    test('--check passes when target/dna matches source', () async {
      writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');
      // First do a real sync.
      await makeRunner(makeCmd()).run([
        'sync',
        '--target',
        target.path,
        '--no-install',
      ]);
      messages.clear();

      // Now check.
      await makeRunner(makeCmd()).run([
        'sync',
        '--target',
        target.path,
        '--check',
      ]);
      expect(messages.last, contains('up to date'));
    });

    test('--check throws when target/dna is missing', () async {
      writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--check',
        ]),
        throwsA(isA<Exception>()),
      );
      expect(messages.any((m) => m.contains('missing')), isTrue);
    });

    test('--check throws when the dest file set differs from source', () async {
      writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');
      writeFile(p.join(pkgDna.path, 'guides', 'b.md'), 'B');
      writeFile(p.join(target.path, 'dna', 'guides', 'a.md'), 'A');
      // 'b.md' is missing from the dest, so the file set differs.

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--check',
        ]),
        throwsA(isA<Exception>()),
      );
      expect(
        messages.any((m) => m.contains('file set differs')),
        isTrue,
      );
    });

    test('--check throws on out-of-date file content', () async {
      writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A-new');
      writeFile(p.join(target.path, 'dna', 'guides', 'a.md'), 'A-old');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--check',
        ]),
        throwsA(isA<Exception>()),
      );
      expect(messages.any((m) => m.contains('out of date')), isTrue);
    });

    test('prompts per skill and installs only the selected ones', () async {
      // Bundled skills under <pkg>/dna/agents/skills.
      final skillsSrc = Directory(p.join(pkgDna.path, 'agents', 'skills'))
        ..createSync(recursive: true);
      writeSkillIn(skillsSrc, 'new-project');
      writeSkillIn(skillsSrc, 'new-ticket');
      writeSkillIn(skillsSrc, 'simplify');

      // Selector says yes to new-project + simplify only.
      selectorAnswers['/new-project?'] = true;
      selectorAnswers['/new-ticket?'] = false;
      selectorAnswers['/simplify?'] = true;

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
      ]);

      // dna/ populated
      expect(
        Directory(p.join(target.path, 'dna', 'agents', 'skills', 'new-project'))
            .existsSync(),
        isTrue,
      );

      // .claude/skills/ has only the two selected skills.
      final claudeSkills = Directory(p.join(target.path, '.claude', 'skills'));
      expect(
        File(p.join(claudeSkills.path, 'new-project', 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(claudeSkills.path, 'simplify', 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(claudeSkills.path, 'new-ticket')).existsSync(),
        isFalse,
      );

      // Each skill produced exactly one prompt.
      expect(
        selectorPrompts.where((p) => p.contains('/new-project?')).length,
        1,
      );
      expect(
        selectorPrompts.where((p) => p.contains('/new-ticket?')).length,
        1,
      );
      expect(
        selectorPrompts.where((p) => p.contains('/simplify?')).length,
        1,
      );
    });

    test('prompts per convention and applies only the selected ones', () async {
      final convSrc = Directory(
        p.join(pkgDna.path, 'agents', 'conventions'),
      )..createSync(recursive: true);
      File(p.join(convSrc.path, 'code-conventions.md'))
          .writeAsStringSync('# code');
      File(p.join(convSrc.path, 'test-conventions.md'))
          .writeAsStringSync('# test');

      selectorAnswers['code-conventions.md'] = true;
      selectorAnswers['test-conventions.md'] = false;

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
      ]);

      final destDir = Directory(p.join(target.path, '.claude', 'conventions'));
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
      expect(
        claudeMd,
        contains('@.claude/conventions/code-conventions.md'),
      );
      expect(
        claudeMd.contains('@.claude/conventions/test-conventions.md'),
        isFalse,
      );
      expect(claudeMd, contains(ApplyConventions.startMarker));
    });

    test('logs "no skills selected" when user says no to every prompt',
        () async {
      final skillsSrc = Directory(p.join(pkgDna.path, 'agents', 'skills'))
        ..createSync(recursive: true);
      writeSkillIn(skillsSrc, 'alpha');
      // Default selector returns false for everything (no answers configured).

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
      ]);

      expect(
        messages.any((m) => m.contains('no skills selected')),
        isTrue,
      );
      expect(
        Directory(p.join(target.path, '.claude', 'skills')).existsSync(),
        isFalse,
      );
    });

    test('logs "no conventions selected" when user says no to every prompt',
        () async {
      final convSrc = Directory(p.join(pkgDna.path, 'agents', 'conventions'))
        ..createSync(recursive: true);
      File(p.join(convSrc.path, 'code-conventions.md'))
          .writeAsStringSync('# code');
      // Default selector returns false for everything.

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
      ]);

      expect(
        messages.any((m) => m.contains('no conventions selected')),
        isTrue,
      );
      expect(
        File(p.join(target.path, 'CLAUDE.md')).existsSync(),
        isFalse,
      );
    });

    test('--no-install skips both prompt phases', () async {
      final skillsSrc = Directory(p.join(pkgDna.path, 'agents', 'skills'))
        ..createSync(recursive: true);
      writeSkillIn(skillsSrc, 'alpha');
      final convSrc = Directory(p.join(pkgDna.path, 'agents', 'conventions'))
        ..createSync(recursive: true);
      File(p.join(convSrc.path, 'code-conventions.md'))
          .writeAsStringSync('# code');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--no-install',
      ]);

      expect(selectorPrompts, isEmpty);
      expect(
        Directory(p.join(target.path, '.claude', 'skills')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(target.path, 'CLAUDE.md')).existsSync(),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    group('overlay', () {
      test('merges a local overlay over the base — overlay wins on collisions',
          () async {
        // Base: claude-code.md + a second base-only file.
        writeFile(p.join(pkgDna.path, 'guides', 'claude-code.md'), 'BASE');
        writeFile(p.join(pkgDna.path, 'guides', 'other.md'), 'BASE');

        // Overlay: same path for claude-code.md (must win) +
        // a new file only the overlay has.
        final overlay = Directory(p.join(tmp.path, 'overlay'))..createSync();
        writeFile(
          p.join(overlay.path, 'dna', 'guides', 'claude-code.md'),
          'OVERLAY',
        );
        writeFile(
          p.join(overlay.path, 'dna', 'agents', 'extra.md'),
          'EXTRA',
        );

        final cmd = makeCmd();
        final runner = makeRunner(cmd);
        await runner.run([
          'sync',
          '--target',
          target.path,
          '--no-install',
          overlay.path,
        ]);

        // Collision: overlay content wins.
        expect(
          File(p.join(target.path, 'dna', 'guides', 'claude-code.md'))
              .readAsStringSync(),
          'OVERLAY',
        );
        // Untouched by overlay: stays from base.
        expect(
          File(p.join(target.path, 'dna', 'guides', 'other.md'))
              .readAsStringSync(),
          'BASE',
        );
        // Only in overlay: appears in target.
        expect(
          File(p.join(target.path, 'dna', 'agents', 'extra.md'))
              .readAsStringSync(),
          'EXTRA',
        );

        expect(messages.any((m) => m.contains('Overlayed')), isTrue);
      });

      test('clones an overlay specified as a git URL via the injected cloner',
          () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'BASE');

        const url = 'https://example.com/gg_dna_ggsuite.git';
        String? clonedUrl;
        Directory? clonedDest;
        Future<void> cloner(String u, Directory dest) async {
          clonedUrl = u;
          clonedDest = dest;
          // Simulate the clone result.
          writeFile(p.join(dest.path, 'dna', 'guides', 'a.md'), 'FROM_REMOTE');
        }

        final cmd = makeCmd(gitCloner: cloner);
        final runner = makeRunner(cmd);
        await runner.run([
          'sync',
          '--target',
          target.path,
          '--no-install',
          url,
        ]);

        expect(clonedUrl, url);
        expect(clonedDest, isNotNull);
        expect(
          File(p.join(target.path, 'dna', 'guides', 'a.md')).readAsStringSync(),
          'FROM_REMOTE',
        );
        // Temp clone directory was cleaned up.
        expect(clonedDest!.existsSync(), isFalse);
      });

      test('expands a "gg_*" shorthand to a ggsuite github URL and clones',
          () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'BASE');

        String? clonedUrl;
        Future<void> cloner(String u, Directory dest) async {
          clonedUrl = u;
          writeFile(p.join(dest.path, 'dna', 'guides', 'a.md'), 'FROM_REMOTE');
        }

        final cmd = makeCmd(gitCloner: cloner);
        final runner = makeRunner(cmd);
        await runner.run([
          'sync',
          '--target',
          target.path,
          '--no-install',
          'gg_dna_ggsuite',
        ]);

        expect(
          clonedUrl,
          'https://github.com/ggsuite/gg_dna_ggsuite.git',
        );
        expect(
          File(p.join(target.path, 'dna', 'guides', 'a.md')).readAsStringSync(),
          'FROM_REMOTE',
        );
        expect(
          messages.any(
            (m) => m.contains('Resolved shorthand "gg_dna_ggsuite"'),
          ),
          isTrue,
        );
      });

      test('shorthand also accepts a trailing .git', () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'BASE');

        String? clonedUrl;
        Future<void> cloner(String u, Directory dest) async {
          clonedUrl = u;
          writeFile(p.join(dest.path, 'dna', 'guides', 'a.md'), 'FROM_REMOTE');
        }

        final cmd = makeCmd(gitCloner: cloner);
        final runner = makeRunner(cmd);
        await runner.run([
          'sync',
          '--target',
          target.path,
          '--no-install',
          'gg_dna_ggsuite.git',
        ]);

        // Same URL as the bare-name form.
        expect(
          clonedUrl,
          'https://github.com/ggsuite/gg_dna_ggsuite.git',
        );
      });

      test(
        'shorthand wins over local folder with the same name',
        () async {
          writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'BASE');

          // A local folder with the same name as the shorthand sits next to
          // the target. Because the shorthand is resolution-order #1, we
          // expect the remote (cloner) to be used, not the local folder.
          final local = Directory(p.join(tmp.path, 'gg_foo'))..createSync();
          writeFile(p.join(local.path, 'dna', 'guides', 'a.md'), 'LOCAL');

          // The cwd inside which `Directory('gg_foo')` would resolve must
          // contain the folder for the local branch to even be a candidate.
          // We force that condition by running the test from `tmp`.
          final originalCwd = Directory.current;
          Directory.current = tmp;

          String? clonedUrl;
          Future<void> cloner(String u, Directory dest) async {
            clonedUrl = u;
            writeFile(
              p.join(dest.path, 'dna', 'guides', 'a.md'),
              'FROM_REMOTE',
            );
          }

          try {
            final cmd = makeCmd(gitCloner: cloner);
            final runner = makeRunner(cmd);
            await runner.run([
              'sync',
              '--target',
              target.path,
              '--no-install',
              'gg_foo',
            ]);
          } finally {
            Directory.current = originalCwd;
          }

          expect(clonedUrl, 'https://github.com/ggsuite/gg_foo.git');
          expect(
            File(p.join(target.path, 'dna', 'guides', 'a.md'))
                .readAsStringSync(),
            'FROM_REMOTE',
          );
        },
      );

      test('throws when overlay is neither an existing path nor a git URL',
          () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');

        final cmd = makeCmd();
        final runner = makeRunner(cmd);
        await expectLater(
          runner.run([
            'sync',
            '--target',
            target.path,
            '--no-install',
            '/does/not/exist/and/no/url',
          ]),
          throwsA(isA<UsageException>()),
        );
      });

      test('throws when overlay path has no dna/ subfolder', () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');
        // Overlay dir exists but contains no dna/.
        final overlay = Directory(p.join(tmp.path, 'overlay-no-dna'))
          ..createSync();
        File(p.join(overlay.path, 'README.md')).writeAsStringSync('# hi');

        final cmd = makeCmd();
        final runner = makeRunner(cmd);
        await expectLater(
          runner.run([
            'sync',
            '--target',
            target.path,
            '--no-install',
            overlay.path,
          ]),
          throwsA(isA<UsageException>()),
        );
      });

      test('--check cannot be combined with an overlay argument', () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');
        final overlay = Directory(p.join(tmp.path, 'overlay'))..createSync();
        writeFile(p.join(overlay.path, 'dna', 'guides', 'a.md'), 'A');

        final cmd = makeCmd();
        final runner = makeRunner(cmd);
        await expectLater(
          runner.run([
            'sync',
            '--target',
            target.path,
            '--check',
            overlay.path,
          ]),
          throwsA(isA<UsageException>()),
        );
      });

      test('rejects more than one positional overlay argument', () async {
        writeFile(p.join(pkgDna.path, 'guides', 'a.md'), 'A');
        final cmd = makeCmd();
        final runner = makeRunner(cmd);
        await expectLater(
          runner.run([
            'sync',
            '--target',
            target.path,
            '--no-install',
            '/a',
            '/b',
          ]),
          throwsA(isA<UsageException>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    group('looksLikeGitUrl', () {
      test('recognises common git URL shapes', () {
        expect(Sync.looksLikeGitUrl('https://example.com/repo.git'), isTrue);
        expect(Sync.looksLikeGitUrl('http://example.com/repo'), isTrue);
        expect(Sync.looksLikeGitUrl('ssh://git@example.com/repo.git'), isTrue);
        expect(Sync.looksLikeGitUrl('git@github.com:owner/repo.git'), isTrue);
        expect(Sync.looksLikeGitUrl('owner/repo.git'), isTrue);
      });

      test('rejects plain paths', () {
        expect(Sync.looksLikeGitUrl('../foo'), isFalse);
        expect(Sync.looksLikeGitUrl('/tmp/x'), isFalse);
        expect(Sync.looksLikeGitUrl('C:\\Users\\x'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('expandShorthand', () {
      test('expands bare gg_* names to ggsuite github URLs', () {
        expect(
          Sync.expandShorthand('gg_dna_ggsuite'),
          'https://github.com/ggsuite/gg_dna_ggsuite.git',
        );
        expect(
          Sync.expandShorthand('gg_foo'),
          'https://github.com/ggsuite/gg_foo.git',
        );
        expect(
          Sync.expandShorthand('gg_a-b.c'),
          'https://github.com/ggsuite/gg_a-b.c.git',
        );
      });

      test('strips a trailing .git before building the URL', () {
        expect(
          Sync.expandShorthand('gg_dna_ggsuite.git'),
          'https://github.com/ggsuite/gg_dna_ggsuite.git',
        );
      });

      test('rejects anything that is not a bare gg_* name', () {
        // Wrong prefix.
        expect(Sync.expandShorthand('kidney_core'), isNull);
        expect(Sync.expandShorthand('ds_thing'), isNull);
        expect(Sync.expandShorthand('foo'), isNull);
        // Prefix only.
        expect(Sync.expandShorthand('gg_'), isNull);
        // Contains path separators or URL chars — must not be misclassified.
        expect(Sync.expandShorthand('owner/gg_foo'), isNull);
        expect(Sync.expandShorthand('./gg_foo'), isNull);
        expect(Sync.expandShorthand('gg_foo/sub'), isNull);
        expect(Sync.expandShorthand('git@github.com:ggsuite/gg_foo.git'), isNull);
        expect(Sync.expandShorthand('https://x/gg_foo.git'), isNull);
        expect(Sync.expandShorthand('C:\\gg_foo'), isNull);
        // Whitespace.
        expect(Sync.expandShorthand(' gg_foo'), isNull);
        expect(Sync.expandShorthand('gg_foo '), isNull);
      });
    });
  });
}
