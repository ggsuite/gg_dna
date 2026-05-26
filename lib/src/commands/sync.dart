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

/// Clones the git repo at [url] into [dest]. Used by [Sync] when the overlay
/// argument is a git URL. Injected so tests can stub the network call.
typedef GitCloner = Future<void> Function(String url, Directory dest);

/// Mirrors the `dna/` folder shipped with `gg_dna` into the consuming
/// repository. When an overlay repo (local path or git URL) is passed as a
/// positional argument, its `dna/` is merged on top of the base sync —
/// files at the same relative path win from the overlay, every other file
/// from the base remains.
///
/// After the copy, the command offers — per skill and per convention — to
/// install them into the project's `.claude/` folder via [InstallSkills]
/// and [ApplyConventions].
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
  ///
  /// [gitCloner] is invoked when the overlay argument looks like a git URL.
  /// The default shells out to `git clone --depth 1 <url> <dest>`.
  Sync({
    required this.ggLog,
    PackageRootResolver? packageRootResolver,
    YesNoSelector? selector,
    GitCloner? gitCloner,
  })  : _packageRootResolver = packageRootResolver ?? _defaultPackageRoot,
        _selector = selector ?? _defaultSelector,
        _gitCloner = gitCloner ?? _defaultGitCloner {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'Source folder containing the base gg_dna content. Defaults to '
            'the root of the resolved gg_dna package. The `dna/` subfolder '
            'of this path is mirrored into <target>/dna.',
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
            'Skips the interactive install/apply phase. Cannot be combined '
            'with an overlay argument.',
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
  final GitCloner _gitCloner;

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
      'Mirror the gg_dna `dna/` folder into <target>/dna, optionally '
      'overlay a project-specific dna repo on top, then offer to install '
      "Claude Code skills and conventions into the project's .claude "
      'folder.\n'
      '\n'
      'Usage: gg_dna sync [overlay]\n'
      '  overlay  Optional. One of:\n'
      '             * `gg_*` shorthand — resolved to '
      'https://github.com/ggsuite/<name>.git and cloned.\n'
      '             * git URL (https://, http://, git@, ssh://, or '
      'anything ending in .git) — cloned.\n'
      '             * local path to a folder that contains a `dna/` '
      'subdirectory.\n'
      "           The overlay's `dna/` is merged over the base sync — "
      'overlay files win on path collisions.';

  @override
  Future<void> run() async {
    final sourceDna = await _resolveSourceDna(argResults!['source'] as String?);
    final target = _resolveTarget(argResults!['target'] as String?);
    final checkOnly = argResults!['check'] as bool;
    final noInstall = argResults!['no-install'] as bool;
    final overlayArg = _readOverlayArg(argResults!.rest);

    if (!sourceDna.existsSync()) {
      throw UsageException(
        'Source dna folder does not exist: ${sourceDna.path}',
        usage,
      );
    }

    if (checkOnly && overlayArg != null) {
      throw UsageException(
        '--check cannot be combined with an overlay argument.',
        usage,
      );
    }

    final dnaDir = Directory(p.join(target.path, 'dna'));

    if (checkOnly) {
      _check(sourceDna, dnaDir);
      return;
    }

    // Base sync: wipe <target>/dna and copy <source>/dna fresh.
    if (dnaDir.existsSync()) {
      dnaDir.deleteSync(recursive: true);
    }
    copyDirectory(sourceDna, dnaDir);
    ggLog('Synced ${sourceDna.path} -> ${dnaDir.path}.');

    // Overlay: merge <overlay>/dna on top without wiping the target first.
    if (overlayArg != null) {
      Directory? cleanup;
      try {
        final (overlayDna, tmp) = await _resolveOverlayDna(overlayArg);
        cleanup = tmp;
        if (!overlayDna.existsSync()) {
          throw UsageException(
            'Overlay does not contain a dna/ folder: ${overlayDna.path}',
            usage,
          );
        }
        copyDirectory(overlayDna, dnaDir);
        ggLog('Overlayed ${overlayDna.path} -> ${dnaDir.path}.');
      } finally {
        if (cleanup != null && cleanup.existsSync()) {
          cleanup.deleteSync(recursive: true);
        }
      }
    }

    if (noInstall) {
      return;
    }

    await _promptAndInstallSkills(target);
    await _promptAndApplyConventions(target);
  }

  // ===========================================================================
  // Public helpers (also used by tests)
  // ===========================================================================

  /// Recursively copies the contents of [source] into [target]. Existing
  /// files in [target] at colliding relative paths are overwritten; files
  /// that exist only in [target] are kept (overlay semantics).
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

  /// Heuristically classifies an overlay argument as a git URL.
  ///
  /// Accepts:
  ///   - https://… or http://…
  ///   - git@host:owner/repo(.git)
  ///   - ssh://…
  ///   - any string ending in `.git`
  static bool looksLikeGitUrl(String arg) {
    if (arg.startsWith('https://') || arg.startsWith('http://')) return true;
    if (arg.startsWith('ssh://')) return true;
    if (arg.startsWith('git@')) return true;
    if (arg.endsWith('.git')) return true;
    return false;
  }

  /// Expands a bare `gg_*` repo shorthand to its canonical github URL.
  ///
  /// Returns `https://github.com/ggsuite/<name>.git` when [arg] looks like a
  /// `gg_*` repo name (e.g. `gg_dna_ggsuite` or `gg_dna_ggsuite.git`).
  /// Returns `null` otherwise.
  ///
  /// The shape must be a bare name: it must start with `gg_`, may only
  /// contain word characters, dots, or hyphens after that, and must not
  /// contain slashes, colons, `@`, or whitespace (so real paths and URLs
  /// are never misclassified as a shorthand). A trailing `.git` is
  /// stripped before the URL is built, so callers can write either form.
  static String? expandShorthand(String arg) {
    final name = arg.endsWith('.git')
        ? arg.substring(0, arg.length - 4)
        : arg;
    if (!RegExp(r'^gg_[A-Za-z0-9._-]+$').hasMatch(name)) return null;
    return 'https://github.com/ggsuite/$name.git';
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

  String? _readOverlayArg(List<String> rest) {
    if (rest.isEmpty) return null;
    if (rest.length > 1) {
      throw UsageException(
        'Only a single overlay argument is supported, got: ${rest.join(' ')}',
        usage,
      );
    }
    final arg = rest.single.trim();
    if (arg.isEmpty) return null;
    return arg;
  }

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

  /// Resolves an overlay argument to a `dna/` source directory.
  ///
  /// Returns the dna directory and an optional cleanup directory (a temp
  /// clone) that the caller must delete after the sync is done. For local
  /// paths the cleanup is `null`.
  ///
  /// Resolution order:
  ///   1. `gg_*` shorthand — expanded via [expandShorthand] to a github
  ///      URL under the `ggsuite` org and cloned. Checked first so that
  ///      `gg_foo` and `gg_foo.git` always resolve to the same remote,
  ///      independent of the current working directory.
  ///   2. Anything else recognised by [looksLikeGitUrl] — cloned.
  ///   3. Existing local directory — used as-is.
  Future<(Directory dna, Directory? cleanup)> _resolveOverlayDna(
    String arg,
  ) async {
    final shorthand = expandShorthand(arg);
    if (shorthand != null) {
      ggLog('Resolved shorthand "$arg" -> $shorthand');
      return _cloneOverlay(shorthand);
    }
    if (looksLikeGitUrl(arg)) {
      return _cloneOverlay(arg);
    }
    final local = Directory(arg);
    if (local.existsSync()) {
      return (Directory(p.join(local.path, 'dna')), null);
    }
    throw UsageException(
      'Overlay argument is neither a `gg_*` shorthand, an existing local '
      'path, nor a recognised git URL: $arg',
      usage,
    );
  }

  /// Clones [url] into a fresh temp directory and returns the resulting
  /// `dna/` directory plus the temp directory itself, so the caller can
  /// clean it up after the overlay has been applied.
  Future<(Directory dna, Directory cleanup)> _cloneOverlay(String url) async {
    final tmp = Directory.systemTemp.createTempSync('gg_dna_overlay_');
    ggLog('Cloning $url into ${tmp.path} …');
    await _gitCloner(url, tmp);
    return (Directory(p.join(tmp.path, 'dna')), tmp);
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

  /// Default git cloner: shells out to `git clone --depth 1 <url> <dest>`.
  static Future<void> _defaultGitCloner(String url, Directory dest) async {
    final result = await Process.run(
      'git',
      ['clone', '--depth', '1', url, dest.path],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw Exception(
        'git clone failed (exit ${result.exitCode}): ${result.stderr}',
      );
    }
  }
  // coverage:ignore-end
}
