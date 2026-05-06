// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_dna/src/commands/install_skills.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late List<String> messages;
  late List<String> prompts;
  late List<String> answers;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('install_skills_test_');
    messages = <String>[];
    prompts = <String>[];
    answers = <String>[];
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  String? prompter(String prompt) {
    prompts.add(prompt);
    if (answers.isEmpty) return null;
    return answers.removeAt(0);
  }

  Directory makeSkill(Directory parent, String name, {String? body}) {
    final dir = Directory(p.join(parent.path, name))..createSync();
    File(p.join(dir.path, 'SKILL.md')).writeAsStringSync(body ?? '# $name');
    return dir;
  }

  CommandRunner<dynamic> makeRunner(InstallSkills cmd) {
    return CommandRunner<dynamic>('test', 'test')..addCommand(cmd);
  }

  // ===========================================================================
  group('InstallSkills', () {
    // -------------------------------------------------------------------------
    group('run()', () {
      test('throws UsageException when source does not exist', () async {
        final cmd = InstallSkills(ggLog: messages.add);
        final runner = makeRunner(cmd);
        await expectLater(
          runner.run([
            'install-skills',
            '--source',
            p.join(tmp.path, 'missing'),
            '--all',
          ]),
          throwsA(isA<UsageException>()),
        );
      });

      test('logs "No skills found" for an empty source folder', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        final cmd = InstallSkills(ggLog: messages.add);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          p.join(tmp.path, 'dest'),
          '--all',
        ]);
        expect(messages.any((m) => m.contains('No skills found')), isTrue);
      });

      test('skips non-skill subdirectories', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        Directory(p.join(src.path, 'not_a_skill')).createSync();
        final cmd = InstallSkills(ggLog: messages.add);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          p.join(tmp.path, 'dest'),
          '--all',
        ]);
        expect(messages.any((m) => m.contains('No skills found')), isTrue);
      });

      test(
        'installs every skill when --all is given (no prompts asked)',
        () async {
          final src = Directory(p.join(tmp.path, 'src'))..createSync();
          makeSkill(src, 'alpha');
          makeSkill(src, 'beta');
          final dest = Directory(p.join(tmp.path, 'dest'));

          final cmd = InstallSkills(ggLog: messages.add, promptUser: prompter);
          final runner = makeRunner(cmd);
          await runner.run([
            'install-skills',
            '--source',
            src.path,
            '--dest',
            dest.path,
            '--all',
          ]);

          expect(prompts, isEmpty);
          expect(
            File(p.join(dest.path, 'alpha', 'SKILL.md')).existsSync(),
            isTrue,
          );
          expect(
            File(p.join(dest.path, 'beta', 'SKILL.md')).existsSync(),
            isTrue,
          );
          expect(messages.last, contains('Installed 2 skill(s)'));
        },
      );

      test('--only restricts installs to the named skills', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        makeSkill(src, 'alpha');
        makeSkill(src, 'beta');
        makeSkill(src, 'gamma');
        final dest = Directory(p.join(tmp.path, 'dest'));

        final cmd = InstallSkills(ggLog: messages.add, promptUser: prompter);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          dest.path,
          '--only',
          'alpha,gamma',
        ]);

        expect(prompts, isEmpty);
        expect(
          File(p.join(dest.path, 'alpha', 'SKILL.md')).existsSync(),
          isTrue,
        );
        expect(Directory(p.join(dest.path, 'beta')).existsSync(), isFalse);
        expect(
          File(p.join(dest.path, 'gamma', 'SKILL.md')).existsSync(),
          isTrue,
        );
      });

      test('--only with no matches reports nothing to install', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        makeSkill(src, 'alpha');
        final dest = Directory(p.join(tmp.path, 'dest'));

        final cmd = InstallSkills(ggLog: messages.add);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          dest.path,
          '--only',
          'missing',
        ]);

        expect(messages.any((m) => m.contains('No skills found')), isTrue);
      });

      test('prompts and installs when answer is "y"', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        makeSkill(src, 'alpha');
        final dest = Directory(p.join(tmp.path, 'dest'));
        answers.addAll(['y']);

        final cmd = InstallSkills(ggLog: messages.add, promptUser: prompter);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          dest.path,
        ]);

        expect(prompts, hasLength(1));
        expect(prompts.single, contains('Install skill "alpha"'));
        expect(
          File(p.join(dest.path, 'alpha', 'SKILL.md')).existsSync(),
          isTrue,
        );
        expect(messages.last, contains('Installed 1 skill(s), skipped 0'));
      });

      test('skips when answer is "n"', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        makeSkill(src, 'alpha');
        final dest = Directory(p.join(tmp.path, 'dest'));
        answers.addAll(['n']);

        final cmd = InstallSkills(ggLog: messages.add, promptUser: prompter);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          dest.path,
        ]);

        expect(Directory(p.join(dest.path, 'alpha')).existsSync(), isFalse);
        expect(messages.any((m) => m.contains('skipped alpha')), isTrue);
        expect(messages.last, contains('Installed 0 skill(s), skipped 1'));
      });

      test('skips when prompt returns null (closed stdin)', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        makeSkill(src, 'alpha');
        final dest = Directory(p.join(tmp.path, 'dest'));

        final cmd = InstallSkills(
          ggLog: messages.add,
          promptUser: (_) => null,
        );
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          dest.path,
        ]);

        expect(messages.any((m) => m.contains('skipped alpha')), isTrue);
      });

      test(
        'overwrites an existing target skill when the user confirms',
        () async {
          final src = Directory(p.join(tmp.path, 'src'))..createSync();
          makeSkill(src, 'alpha', body: '# new content');
          final dest = Directory(p.join(tmp.path, 'dest'))..createSync();
          // Pre-existing target with stale content.
          final existing = Directory(p.join(dest.path, 'alpha'))..createSync();
          File(p.join(existing.path, 'old.md')).writeAsStringSync('stale');
          answers.addAll(['yes']);

          final cmd = InstallSkills(ggLog: messages.add, promptUser: prompter);
          final runner = makeRunner(cmd);
          await runner.run([
            'install-skills',
            '--source',
            src.path,
            '--dest',
            dest.path,
          ]);

          expect(prompts.single, contains('already installed'));
          expect(prompts.single, contains('Overwrite?'));
          expect(
            File(p.join(dest.path, 'alpha', 'old.md')).existsSync(),
            isFalse,
          );
          final installed = File(
            p.join(dest.path, 'alpha', 'SKILL.md'),
          ).readAsStringSync();
          expect(installed, '# new content');
        },
      );

      test('copies nested directories and files when installing', () async {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        final skill = makeSkill(src, 'alpha');
        final nested = Directory(p.join(skill.path, 'docs'))..createSync();
        File(p.join(nested.path, 'note.md')).writeAsStringSync('nested');
        final dest = Directory(p.join(tmp.path, 'dest'));

        final cmd = InstallSkills(ggLog: messages.add);
        final runner = makeRunner(cmd);
        await runner.run([
          'install-skills',
          '--source',
          src.path,
          '--dest',
          dest.path,
          '--all',
        ]);

        final copied = File(p.join(dest.path, 'alpha', 'docs', 'note.md'));
        expect(copied.existsSync(), isTrue);
        expect(copied.readAsStringSync(), 'nested');
      });
    });

    // -------------------------------------------------------------------------
    group('resolveSource()', () {
      test('returns the explicit folder when --source is given', () {
        final cmd = InstallSkills(
          ggLog: messages.add,
          cwdResolver: () => 'unused',
        );
        final dir = cmd.resolveSource('/explicit/path');
        expect(dir.path, '/explicit/path');
      });

      test(
        'falls back to <cwd>/dna/claude/skills when --source is omitted',
        () {
          final cmd = InstallSkills(
            ggLog: messages.add,
            cwdResolver: () => '/repo',
          );
          final dir = cmd.resolveSource(null);
          expect(dir.path, p.join('/repo', 'dna', 'claude', 'skills'));
        },
      );

      test('treats an empty --source value as missing', () {
        final cmd = InstallSkills(
          ggLog: messages.add,
          cwdResolver: () => '/repo',
        );
        final dir = cmd.resolveSource('');
        expect(dir.path, p.join('/repo', 'dna', 'claude', 'skills'));
      });
    });

    // -------------------------------------------------------------------------
    group('resolveDest()', () {
      test('returns the explicit folder when --dest is given', () {
        final cmd = InstallSkills(
          ggLog: messages.add,
          cwdResolver: () => '/repo',
        );
        expect(cmd.resolveDest('/explicit').path, '/explicit');
      });

      test(
        'falls back to <cwd>/.claude/skills when --dest is omitted',
        () {
          final cmd = InstallSkills(
            ggLog: messages.add,
            cwdResolver: () => '/repo',
          );
          expect(
            cmd.resolveDest(null).path,
            p.join('/repo', '.claude', 'skills'),
          );
        },
      );

      test('uses the real working directory when no override is provided', () {
        final cmd = InstallSkills(ggLog: messages.add);
        final dest = cmd.resolveDest(null).path;
        expect(dest, contains('.claude'));
        expect(dest, endsWith('skills'));
      });

      test('treats an empty --dest value as missing', () {
        final cmd = InstallSkills(
          ggLog: messages.add,
          cwdResolver: () => '/repo',
        );
        expect(
          cmd.resolveDest('').path,
          p.join('/repo', '.claude', 'skills'),
        );
      });
    });

    // -------------------------------------------------------------------------
    group('discoverSkills()', () {
      test('returns skills sorted alphabetically and ignores non-skills', () {
        final src = Directory(p.join(tmp.path, 'src'))..createSync();
        makeSkill(src, 'gamma');
        makeSkill(src, 'alpha');
        // A directory without SKILL.md must be ignored.
        Directory(p.join(src.path, 'not_a_skill')).createSync();
        // A loose file at the top level must be ignored.
        File(p.join(src.path, 'loose.md')).writeAsStringSync('x');

        final found = InstallSkills.discoverSkills(src);
        expect(
          found.map((d) => p.basename(d.path)).toList(),
          ['alpha', 'gamma'],
        );
      });
    });

    // -------------------------------------------------------------------------
    group('ask()', () {
      InstallSkills withAnswer(String? answer) => InstallSkills(
            ggLog: messages.add,
            promptUser: (prompt) {
              prompts.add(prompt);
              return answer;
            },
          );

      test('returns true for affirmative answers', () {
        for (final answer in ['y', 'Y', 'yes', 'YES', 'j', 'J', 'ja', ' Ja ']) {
          final cmd = withAnswer(answer);
          expect(cmd.ask('?'), isTrue, reason: 'answer="$answer"');
        }
      });

      test('returns false for negative or unrecognised answers', () {
        for (final answer in ['n', 'no', '', 'maybe']) {
          final cmd = withAnswer(answer);
          expect(cmd.ask('?'), isFalse, reason: 'answer="$answer"');
        }
      });

      test('returns false when prompt yields null', () {
        final cmd = withAnswer(null);
        expect(cmd.ask('?'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    group('copyDirectory()', () {
      test(
        'recursively copies files and creates intermediate directories',
        () {
          final source = Directory(p.join(tmp.path, 'a'))..createSync();
          File(p.join(source.path, 'top.txt')).writeAsStringSync('top');
          final nested = Directory(p.join(source.path, 'sub', 'deep'))
            ..createSync(recursive: true);
          File(p.join(nested.path, 'leaf.txt')).writeAsStringSync('leaf');
          final target = Directory(p.join(tmp.path, 'b'));

          InstallSkills.copyDirectory(source, target);

          expect(
            File(p.join(target.path, 'top.txt')).readAsStringSync(),
            'top',
          );
          expect(
            File(
              p.join(target.path, 'sub', 'deep', 'leaf.txt'),
            ).readAsStringSync(),
            'leaf',
          );
        },
      );
    });
  });
}
