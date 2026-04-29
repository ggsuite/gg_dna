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

/// Returns the directory the package is installed in.
///
/// Used to locate the bundled `claude/skills/` folder when no explicit
/// `--source` is given.
typedef PackageRootResolver = String Function();

/// Installs all Claude Code skills shipped with this repository into the
/// user's local Claude environment (`~/.claude/skills/<name>`).
///
/// For every skill found under `<source>/<name>/SKILL.md` the user is asked
/// for confirmation before it is copied. Existing skills with the same name
/// are overwritten when the user confirms.
class InstallSkills extends Command<dynamic> {
  /// Constructor.
  ///
  /// [promptUser], [homeOverride] and [packageRootResolver] exist primarily
  /// to make the command testable; the defaults wire them to the real
  /// stdin/environment/script-path.
  InstallSkills({
    required this.ggLog,
    PromptUser? promptUser,
    String? homeOverride,
    PackageRootResolver? packageRootResolver,
  })  : _promptUser = promptUser ?? _defaultPrompt,
        _homeOverride = homeOverride,
        _packageRootResolver = packageRootResolver ?? _defaultPackageRoot {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'Folder containing the skills to install. Defaults to '
            '<package-root>/claude/skills.',
      )
      ..addOption(
        'dest',
        abbr: 'd',
        help: 'Destination folder. Defaults to ~/.claude/skills on the current '
            'user.',
      )
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Install every skill without asking.',
        negatable: false,
      );
  }

  /// The log function.
  final GgLog ggLog;

  final PromptUser _promptUser;
  final String? _homeOverride;
  final PackageRootResolver _packageRootResolver;

  @override
  final name = 'install-skills';

  @override
  final description =
      'Install Claude Code skills bundled with gg_dna into the local Claude '
      'environment (~/.claude/skills).';

  @override
  Future<void> run() async {
    final source = resolveSource(argResults!['source'] as String?);
    final dest = resolveDest(argResults!['dest'] as String?);
    final installAll = argResults!['all'] as bool;

    if (!source.existsSync()) {
      throw UsageException(
        'Source folder does not exist: ${source.path}',
        usage,
      );
    }

    final skills = discoverSkills(source);
    if (skills.isEmpty) {
      ggLog('No skills found in ${source.path}.');
      return;
    }

    dest.createSync(recursive: true);

    var installed = 0;
    var skipped = 0;
    for (final skill in skills) {
      final skillName = p.basename(skill.path);
      final targetDir = Directory(p.join(dest.path, skillName));
      final exists = targetDir.existsSync();

      final shouldInstall = installAll
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
  /// Resolves the `--source` option to a [Directory], falling back to the
  /// package's bundled `claude/skills/` folder when no value was given.
  Directory resolveSource(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    return Directory(p.join(_packageRootResolver(), 'claude', 'skills'));
  }

  /// Resolves the `--dest` option to a [Directory], falling back to
  /// `<home>/.claude/skills` when no value was given.
  Directory resolveDest(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    return Directory(p.join(_homeOverride ?? homeDir(), '.claude', 'skills'));
  }

  /// Returns the user's home directory based on `HOME` (Unix) or
  /// `USERPROFILE` (Windows).
  ///
  /// Throws a [StateError] when neither variable is set.
  static String homeDir() {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home == null || home.isEmpty) {
      // coverage:ignore-start
      throw StateError(
        'Cannot determine home directory: neither HOME nor USERPROFILE is set.',
      );
      // coverage:ignore-end
    }
    return home;
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

  static String _defaultPackageRoot() {
    // When run via `dart run` or `dart pub global run`, the script lives at
    // <package-root>/bin/gg_dna.dart. Walk up to find a folder containing
    // pubspec.yaml.
    var dir = File.fromUri(Platform.script).parent;
    for (var i = 0; i < 5; i++) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return Directory.current.path;
  }
  // coverage:ignore-end
}
