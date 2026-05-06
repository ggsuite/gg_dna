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
  late Directory target;
  late List<String> messages;
  late List<String> selectorPrompts;
  late Map<String, bool> selectorAnswers;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sync_test_');
    pkgRoot = Directory(p.join(tmp.path, 'pkg'))..createSync();
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

  Sync makeCmd() => Sync(
        ggLog: messages.add,
        packageRootResolver: () async => pkgRoot.path,
        selector: selector,
      );

  CommandRunner<dynamic> makeRunner(Sync cmd) =>
      CommandRunner<dynamic>('test', 'test')..addCommand(cmd);

  void writeSkillIn(Directory parent, String name) {
    final dir = Directory(p.join(parent.path, name))..createSync();
    File(p.join(dir.path, 'SKILL.md')).writeAsStringSync('# $name');
  }

  // ===========================================================================
  group('Sync', () {
    test('throws when --source does not exist', () async {
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

    test('throws when none of the includes are present in source', () async {
      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--no-install',
        ]),
        throwsA(isA<UsageException>()),
      );
    });

    test('reports skipped includes that are absent in source', () async {
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A');
      // 'scripts' and 'claude' are missing in pkgRoot.

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--no-install',
      ]);

      expect(
        messages.any((m) => m.contains('skipped (not in source)')),
        isTrue,
      );
    });

    test('copies default folders into <target>/dna and skips install',
        () async {
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A');
      writeFile(p.join(pkgRoot.path, 'scripts', 'run.sh'), 'echo hi');
      writeFile(p.join(pkgRoot.path, 'claude', 'sub', 'b.md'), 'B');

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
        File(p.join(target.path, 'dna', 'claude', 'sub', 'b.md'))
            .readAsStringSync(),
        'B',
      );
      expect(
        messages.any((m) => m.contains('Synced 3 folder(s)')),
        isTrue,
      );
      expect(selectorPrompts, isEmpty);
    });

    test('replaces stale files in an existing dna subfolder', () async {
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A-new');
      writeFile(p.join(target.path, 'dna', 'guides', 'a.md'), 'A-old');
      writeFile(p.join(target.path, 'dna', 'guides', 'gone.md'), 'gone');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--include',
        'guides',
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
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A');
      // First do a real sync.
      await makeRunner(makeCmd()).run([
        'sync',
        '--target',
        target.path,
        '--include',
        'guides',
        '--no-install',
      ]);
      messages.clear();

      // Now check.
      await makeRunner(makeCmd()).run([
        'sync',
        '--target',
        target.path,
        '--include',
        'guides',
        '--check',
      ]);
      expect(messages.last, contains('up to date'));
    });

    test('--check throws when target/dna subfolder is missing', () async {
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--include',
          'guides',
          '--check',
        ]),
        throwsA(isA<Exception>()),
      );
      expect(messages.any((m) => m.contains('missing')), isTrue);
    });

    test('--check throws when the dest file set differs from source', () async {
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A');
      writeFile(p.join(pkgRoot.path, 'guides', 'b.md'), 'B');
      writeFile(p.join(target.path, 'dna', 'guides', 'a.md'), 'A');
      // 'b.md' is missing from the dest, so the file set differs.

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--include',
          'guides',
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
      writeFile(p.join(pkgRoot.path, 'guides', 'a.md'), 'A-new');
      writeFile(p.join(target.path, 'dna', 'guides', 'a.md'), 'A-old');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await expectLater(
        runner.run([
          'sync',
          '--target',
          target.path,
          '--include',
          'guides',
          '--check',
        ]),
        throwsA(isA<Exception>()),
      );
      expect(messages.any((m) => m.contains('out of date')), isTrue);
    });

    test('prompts per skill and installs only the selected ones', () async {
      // Bundled skills under <pkg>/claude/skills.
      final skillsSrc = Directory(p.join(pkgRoot.path, 'claude', 'skills'))
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
        '--include',
        'claude',
      ]);

      // dna/ populated
      expect(
        Directory(p.join(target.path, 'dna', 'claude', 'skills', 'new-project'))
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
        p.join(pkgRoot.path, 'claude', 'conventions'),
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
        '--include',
        'claude',
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
      final skillsSrc = Directory(p.join(pkgRoot.path, 'claude', 'skills'))
        ..createSync(recursive: true);
      writeSkillIn(skillsSrc, 'alpha');
      // Default selector returns false for everything (no answers configured).

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--include',
        'claude',
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
      final convSrc = Directory(p.join(pkgRoot.path, 'claude', 'conventions'))
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
        '--include',
        'claude',
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
      final skillsSrc = Directory(p.join(pkgRoot.path, 'claude', 'skills'))
        ..createSync(recursive: true);
      writeSkillIn(skillsSrc, 'alpha');
      final convSrc = Directory(p.join(pkgRoot.path, 'claude', 'conventions'))
        ..createSync(recursive: true);
      File(p.join(convSrc.path, 'code-conventions.md'))
          .writeAsStringSync('# code');

      final cmd = makeCmd();
      final runner = makeRunner(cmd);
      await runner.run([
        'sync',
        '--target',
        target.path,
        '--include',
        'claude',
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
  });
}
