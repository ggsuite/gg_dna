// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:interact/interact.dart' as interact;
import 'package:path/path.dart' as p;

import 'apply_conventions.dart';
import 'install_skills.dart';

/// Returns the directory the `gg_dna` package is installed in.
typedef PackageRootResolver = Future<String> Function();

/// Asks the user a yes/no question represented by [prompt] and returns `true`
/// for "yes". Used by [Sync] to decide which skills / conventions to install.
typedef YesNoSelector = bool Function(String prompt);

/// Mirrors the `dna/` folder shipped with `gg_dna` into the consuming
/// repository, then offers — per skill and per convention — to install them
/// into the project's `.claude/` folder via [InstallSkills] and
/// [ApplyConventions].
class Sync extends Command<dynamic> {
  /// Constructor.
  ///
  /// [packageRootResolver] is the source of truth for the gg_dna content;
  /// the default resolves it via [Isolate.resolvePackageUri] so the command
  /// works both inside the gg_dna repo *and* from a consumer that has
  /// gg_dna in its pub cache.
  ///
  /// [selector] is used for the interactive yes/no prompts. The default
  /// renders an [interact.Select] with two options ("yes"/"no").
  Sync({
    required this.ggLog,
    PackageRootResolver? packageRootResolver,
    YesNoSelector? selector,
  })  : _packageRootResolver = packageRootResolver ?? _defaultPackageRoot,
        _selector = selector ?? _defaultSelector {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'Source folder containing the gg_dna content. Defaults to the '
            'root of the resolved gg_dna package. The `dna/` subfolder of '
            'this path is mirrored into <target>/dna.',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target folder. Defaults to <cwd>.',
      )
      ..addFlag(
        'check',
        abbr: 'c',
        help: 'Verify <target>/dna is up to date without writing anything. '
            'Skips the interactive install/apply phase.',
        negatable: false,
      )
      ..addFlag(
        'no-install',
        help: 'Skip the post-sync install-skills / apply-conventions phase.',
        negatable: false,
      );
  }

  /// The log function.
  final GgLog ggLog;

  final PackageRootResolver _packageRootResolver;
  final YesNoSelector _selector;

  /// Subdirectory inside `<target>/dna/agents/skills` discovered for the
  /// install-skills prompt phase.
  static const String _dnaSkillsRel = 'dna/agents/skills';

  /// Subdirectory inside `<target>/dna/agents/conventions` discovered for
  /// the apply-conventions prompt phase.
  static const String _dnaConventionsRel = 'dna/agents/conventions';

  @override
  final name = 'sync';

  @override
  final description =
      'Mirror the gg_dna `dna/` folder into <target>/dna, then optionally '
      "install Claude Code skills and conventions into the project's "
      '.claude folder.';

  @override
  Future<void> run() async {
    final sourceDna = await _resolveSourceDna(argResults!['source'] as String?);
    final target = _resolveTarget(argResults!['target'] as String?);
    final checkOnly = argResults!['check'] as bool;
    final noInstall = argResults!['no-install'] as bool;

    if (!sourceDna.existsSync()) {
      throw UsageException(
        'Source dna folder does not exist: ${sourceDna.path}',
        usage,
      );
    }

    final dnaDir = Directory(p.join(target.path, 'dna'));

    if (checkOnly) {
      _check(sourceDna, dnaDir);
      return;
    }

    if (dnaDir.existsSync()) {
      dnaDir.deleteSync(recursive: true);
    }
    copyDirectory(sourceDna, dnaDir);
    ggLog('Synced ${sourceDna.path} -> ${dnaDir.path}.');

    if (noInstall) {
      return;
    }

    await _promptAndInstallSkills(target);
    await _promptAndApplyConventions(target);
  }

  // ===========================================================================
  // Public helpers (also used by tests)
  // ===========================================================================

  /// Recursively copies the contents of [source] into [target].
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

  /// Returns a sorted list of relative file paths under [dir].
  static List<String> _listFiles(Directory dir) {
    final files = <String>[];
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(p.relative(entity.path, from: dir.path));
      }
    }
    files.sort();
    return files;
  }

  // ===========================================================================
  // Private
  // ===========================================================================

  Future<Directory> _resolveSourceDna(String? raw) async {
    final root =
        (raw != null && raw.isNotEmpty) ? raw : await _packageRootResolver();
    return Directory(p.join(root, 'dna'));
  }

  Directory _resolveTarget(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    // coverage:ignore-start
    return Directory.current;
    // coverage:ignore-end
  }

  Future<void> _promptAndInstallSkills(Directory target) async {
    final skillsRoot = Directory(p.join(target.path, _dnaSkillsRel));
    if (!skillsRoot.existsSync()) {
      return;
    }
    final skills = InstallSkills.discoverSkills(skillsRoot);
    if (skills.isEmpty) {
      return;
    }

    ggLog('');
    ggLog('Claude Code Skills:');
    final selected = <String>[];
    for (final skill in skills) {
      final name = p.basename(skill.path);
      if (_selector('  Install /$name?')) {
        selected.add(name);
      }
    }

    if (selected.isEmpty) {
      ggLog('  (no skills selected)');
      return;
    }

    final dest = Directory(p.join(target.path, '.claude', 'skills'));
    final runner = CommandRunner<dynamic>('gg_dna', 'gg_dna sub-runner')
      ..addCommand(InstallSkills(ggLog: ggLog));
    await runner.run([
      'install-skills',
      '--source',
      skillsRoot.path,
      '--dest',
      dest.path,
      '--only',
      selected.join(','),
    ]);
  }

  Future<void> _promptAndApplyConventions(Directory target) async {
    final convRoot = Directory(p.join(target.path, _dnaConventionsRel));
    if (!convRoot.existsSync()) {
      return;
    }
    final docs = ApplyConventions.discoverConventions(convRoot);
    if (docs.isEmpty) {
      return;
    }

    ggLog('');
    ggLog('Claude Code Conventions:');
    final selected = <String>[];
    for (final doc in docs) {
      final name = p.basename(doc.path);
      if (_selector('  Apply $name?')) {
        selected.add(name);
      }
    }

    if (selected.isEmpty) {
      ggLog('  (no conventions selected)');
      return;
    }

    final runner = CommandRunner<dynamic>('gg_dna', 'gg_dna sub-runner')
      ..addCommand(ApplyConventions(ggLog: ggLog));
    await runner.run([
      'apply-conventions',
      '--source',
      convRoot.path,
      '--target',
      target.path,
      '--only',
      selected.join(','),
    ]);
  }

  void _check(Directory source, Directory dest) {
    if (!dest.existsSync()) {
      ggLog('  - missing: ${dest.path}');
      throw Exception('dna/ out of date — run `gg_dna sync` to fix.');
    }

    final problems = <String>[];
    final srcFiles = _listFiles(source);
    final destFiles = _listFiles(dest);
    if (!_listEquals(srcFiles, destFiles)) {
      problems.add('file set differs: ${dest.path}');
    } else {
      for (final rel in srcFiles) {
        final a = File(p.join(source.path, rel)).readAsBytesSync();
        final b = File(p.join(dest.path, rel)).readAsBytesSync();
        if (!_bytesEqual(a, b)) {
          problems.add('out of date: ${p.join(dest.path, rel)}');
        }
      }
    }

    if (problems.isEmpty) {
      ggLog('dna/ is up to date.');
      return;
    }

    for (final problem in problems) {
      ggLog('  - $problem');
    }
    throw Exception('dna/ out of date — run `gg_dna sync` to fix.');
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // coverage:ignore-start
  /// Resolves the gg_dna package root via [Isolate.resolvePackageUri] so the
  /// command works both when run from inside the gg_dna repo *and* from a
  /// consuming repo where gg_dna sits in the pub cache.
  static Future<String> _defaultPackageRoot() async {
    final libUri = await Isolate.resolvePackageUri(
      Uri.parse('package:gg_dna/gg_dna.dart'),
    );
    if (libUri != null) {
      return Directory.fromUri(libUri.resolve('../')).path;
    }
    var dir = File.fromUri(Platform.script).parent;
    for (var i = 0; i < 5; i++) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return Directory.current.path;
  }

  /// Default yes/no selector that renders a two-option [interact.Select].
  static bool _defaultSelector(String prompt) {
    final choice = interact.Select(
      prompt: prompt,
      options: const ['yes', 'no'],
      initialIndex: 0,
    ).interact();
    return choice == 0;
  }
  // coverage:ignore-end
}
