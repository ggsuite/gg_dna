// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:path/path.dart' as p;

/// Reads a single line of user input in response to [prompt].
///
/// Returns `null` if no input is available (e.g. closed stdin).
typedef PromptUser = String? Function(String prompt);

/// Returns the working directory the command should resolve its
/// `--source`/`--dest` defaults against.
typedef CwdResolver = String Function();

/// Installs Claude Code skills bundled in the consumer's `dna/` folder into
/// the consumer's project-level `.claude/skills/` directory.
///
/// Default source: `<cwd>/dna/claude/skills` — i.e. the output of
/// `gg_dna sync`. Default destination: `<cwd>/.claude/skills`.
///
/// For every skill found under `<source>/<name>/SKILL.md` the user is asked
/// for confirmation before it is copied. Existing skills with the same name
/// are overwritten when the user confirms. `--all` skips prompts; `--only`
/// restricts to a comma-separated subset (also non-interactive).
class InstallSkills extends Command<dynamic> {
  /// Constructor.
  ///
  /// [promptUser] and [cwdResolver] exist primarily to make the command
  /// testable; the defaults wire them to the real stdin / current directory.
  InstallSkills({
    required this.ggLog,
    PromptUser? promptUser,
    CwdResolver? cwdResolver,
  })  : _promptUser = promptUser ?? _defaultPrompt,
        _cwdResolver = cwdResolver ?? _defaultCwd {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'Folder containing the skills to install. Defaults to '
            '<cwd>/dna/claude/skills.',
      )
      ..addOption(
        'dest',
        abbr: 'd',
        help: 'Destination folder. Defaults to <cwd>/.claude/skills.',
      )
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Install every skill without asking.',
        negatable: false,
      )
      ..addMultiOption(
        'only',
        abbr: 'o',
        help: 'Install only the named skills (skill folder names). '
            'Repeat or comma-separate. Bypasses prompts.',
      );
  }

  /// The log function.
  final GgLog ggLog;

  final PromptUser _promptUser;
  final CwdResolver _cwdResolver;

  @override
  final name = 'install-skills';

  @override
  final description =
      'Install Claude Code skills from <cwd>/dna/claude/skills into the '
      "project's <cwd>/.claude/skills directory.";

  @override
  Future<void> run() async {
    final source = resolveSource(argResults!['source'] as String?);
    final dest = resolveDest(argResults!['dest'] as String?);
    final installAll = argResults!['all'] as bool;
    final only = (argResults!['only'] as List<String>)
        .where((s) => s.trim().isNotEmpty)
        .toSet();

    if (!source.existsSync()) {
      throw UsageException(
        'Source folder does not exist: ${source.path}',
        usage,
      );
    }

    var skills = discoverSkills(source);
    if (only.isNotEmpty) {
      skills = skills
          .where((d) => only.contains(p.basename(d.path)))
          .toList(growable: false);
    }
    if (skills.isEmpty) {
      ggLog('No skills found in ${source.path}.');
      return;
    }

    dest.createSync(recursive: true);

    final nonInteractive = installAll || only.isNotEmpty;
    var installed = 0;
    var skipped = 0;
    for (final skill in skills) {
      final skillName = p.basename(skill.path);
      final targetDir = Directory(p.join(dest.path, skillName));
      final exists = targetDir.existsSync();

      final shouldInstall = nonInteractive
          ? true
          : ask(
              exists
                  ? 'Skill "$skillName" already installed at '
                      '${targetDir.path}. Overwrite? (y/N): '
                  : 'Install skill "$skillName" to ${targetDir.path}? (y/N): ',
            );

      if (!shouldInstall) {
        ggLog('  - skipped $skillName');
        skipped++;
        continue;
      }

      if (exists) {
        targetDir.deleteSync(recursive: true);
      }
      copyDirectory(skill, targetDir);
      ggLog('  + installed $skillName -> ${targetDir.path}');
      installed++;
    }

    ggLog('Done. Installed $installed skill(s), skipped $skipped.');
  }

  // ---------------------------------------------------------------------------
  /// Resolves the `--source` option to a [Directory], falling back to
  /// `<cwd>/dna/claude/skills` when no value was given.
  Directory resolveSource(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    return Directory(p.join(_cwdResolver(), 'dna', 'claude', 'skills'));
  }

  /// Resolves the `--dest` option to a [Directory], falling back to
  /// `<cwd>/.claude/skills` when no value was given.
  Directory resolveDest(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    return Directory(p.join(_cwdResolver(), '.claude', 'skills'));
  }

  /// Lists all subdirectories of [source] that contain a `SKILL.md` file,
  /// sorted alphabetically by name.
  static List<Directory> discoverSkills(Directory source) {
    final result = <Directory>[];
    for (final entity in source.listSync()) {
      if (entity is Directory &&
          File(p.join(entity.path, 'SKILL.md')).existsSync()) {
        result.add(entity);
      }
    }
    result.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return result;
  }

  /// Asks the user [prompt] and returns `true` for affirmative answers
  /// (`y`, `yes`, `j`, `ja`; case-insensitive).
  bool ask(String prompt) {
    final line = _promptUser(prompt);
    if (line == null) return false;
    final answer = line.trim().toLowerCase();
    return answer == 'y' || answer == 'yes' || answer == 'j' || answer == 'ja';
  }

  /// Recursively copies the contents of [source] into [target], creating
  /// missing intermediate directories as needed.
  static void copyDirectory(Directory source, Directory target) {
    target.createSync(recursive: true);
    for (final entity in source.listSync(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(target.path, relative);
      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        Directory(p.dirname(targetPath)).createSync(recursive: true);
        entity.copySync(targetPath);
      }
    }
  }

  // coverage:ignore-start
  // ---------------------------------------------------------------------------
  static String? _defaultPrompt(String prompt) {
    stdout.write(prompt);
    return stdin.readLineSync();
  }

  static String _defaultCwd() => Directory.current.path;
  // coverage:ignore-end
}
