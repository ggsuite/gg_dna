// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:path/path.dart' as p;

/// Installs all Claude Code skills shipped with this repository into the
/// user's local Claude environment (`~/.claude/skills/<name>`).
///
/// For every skill found under `<source>/<name>/SKILL.md` the user is asked
/// for confirmation before it is copied. Existing skills with the same name
/// are overwritten when the user confirms.
class InstallSkills extends Command<dynamic> {
  /// Constructor.
  InstallSkills({
    required this.ggLog,
    Stdin? stdinOverride,
    String? homeOverride,
    String? packageRootOverride,
  })  : _stdin = stdinOverride ?? stdin,
        _homeOverride = homeOverride,
        _packageRootOverride = packageRootOverride {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help:
            'Folder containing the skills to install. Defaults to '
            '<package-root>/claude/skills.',
      )
      ..addOption(
        'dest',
        abbr: 'd',
        help:
            'Destination folder. Defaults to ~/.claude/skills on the current '
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

  final Stdin _stdin;
  final String? _homeOverride;
  final String? _packageRootOverride;

  @override
  final name = 'install-skills';

  @override
  final description =
      'Install Claude Code skills bundled with gg_dna into the local Claude '
      'environment (~/.claude/skills).';

  @override
  Future<void> run() async {
    final source = _resolveSource(argResults!['source'] as String?);
    final dest = _resolveDest(argResults!['dest'] as String?);
    final installAll = argResults!['all'] as bool;

    if (!source.existsSync()) {
      throw UsageException(
        'Source folder does not exist: ${source.path}',
        usage,
      );
    }

    final skills = _discoverSkills(source);
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
          : _ask(
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
      _copyDirectory(skill, targetDir);
      ggLog('  + installed $skillName -> ${targetDir.path}');
      installed++;
    }

    ggLog(
      'Done. Installed $installed skill(s), skipped $skipped.',
    );
  }

  // ---------------------------------------------------------------------------
  Directory _resolveSource(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    final root = _packageRootOverride ?? _packageRoot();
    return Directory(p.join(root, 'claude', 'skills'));
  }

  Directory _resolveDest(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    final home = _homeOverride ?? _homeDir();
    return Directory(p.join(home, '.claude', 'skills'));
  }

  String _homeDir() {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home == null || home.isEmpty) {
      throw StateError(
        'Cannot determine home directory: neither HOME nor USERPROFILE is set.',
      );
    }
    return home;
  }

  String _packageRoot() {
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

  List<Directory> _discoverSkills(Directory source) {
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

  bool _ask(String prompt) {
    stdout.write(prompt);
    final line = _stdin.readLineSync();
    if (line == null) return false;
    final answer = line.trim().toLowerCase();
    return answer == 'y' || answer == 'yes' || answer == 'j' || answer == 'ja';
  }

  void _copyDirectory(Directory source, Directory target) {
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
}
