// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:path/path.dart' as p;

/// Returns the directory the package is installed in.
typedef PackageRootResolver = String Function();

/// Copies the convention documents bundled in `gg_dna/claude/conventions/`
/// into a target repo's `.gg/claude/` folder and ensures the target's
/// `CLAUDE.md` references them through `@import`-lines inside a delimited
/// block.
///
/// When the command is executed inside a Kidney workspace (a directory
/// containing `.master/`, walked up from the current working directory),
/// the workspace root is used as the target instead of the current directory.
class ApplyConventions extends Command<dynamic> {
  /// Constructor.
  ApplyConventions({
    required this.ggLog,
    PackageRootResolver? packageRootResolver,
  }) : _packageRootResolver = packageRootResolver ?? _defaultPackageRoot {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'Folder containing the convention markdown files. Defaults to '
            '<package-root>/claude/conventions.',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target repo or workspace folder. Defaults to the current '
            'directory; if executed inside a Kidney workspace, the workspace '
            'root is used instead.',
      )
      ..addFlag(
        'check',
        abbr: 'c',
        help: 'Verify the target is up to date without writing anything. Exits '
            'non-zero if the conventions block or any copied document differs.',
        negatable: false,
      );
  }

  /// The log function.
  final GgLog ggLog;

  final PackageRootResolver _packageRootResolver;

  /// Marker that opens the managed `CLAUDE.md` block.
  static const String startMarker = '<!-- gg_dna:conventions:start';

  /// Marker that closes the managed `CLAUDE.md` block.
  static const String endMarker = '<!-- gg_dna:conventions:end -->';

  @override
  final name = 'apply-conventions';

  @override
  final description =
      'Copy Grace Cloud convention docs into <target>/.gg/claude and reference '
      'them via @import-lines in <target>/CLAUDE.md.';

  @override
  Future<void> run() async {
    final source = _resolveSource(argResults!['source'] as String?);
    final target = _resolveTarget(argResults!['target'] as String?);
    final checkOnly = argResults!['check'] as bool;

    if (!source.existsSync()) {
      throw UsageException(
        'Conventions source folder does not exist: ${source.path}',
        usage,
      );
    }

    final docs = discoverConventions(source);
    if (docs.isEmpty) {
      throw UsageException(
        'No convention markdown files found in ${source.path}.',
        usage,
      );
    }

    final destDir = Directory(p.join(target.path, '.gg', 'claude'));
    final claudeMd = File(p.join(target.path, 'CLAUDE.md'));
    final today = _today();
    final desiredBlock = buildBlock(docs.map((f) => p.basename(f.path)), today);

    if (checkOnly) {
      _check(docs, destDir, claudeMd, desiredBlock);
      return;
    }

    target.createSync(recursive: true);
    destDir.createSync(recursive: true);

    var copied = 0;
    for (final doc in docs) {
      final destFile = File(p.join(destDir.path, p.basename(doc.path)));
      final newContent = doc.readAsStringSync();
      final changed =
          !destFile.existsSync() || destFile.readAsStringSync() != newContent;
      destFile.writeAsStringSync(newContent);
      if (changed) {
        ggLog('  + wrote ${p.relative(destFile.path, from: target.path)}');
        copied++;
      }
    }

    final claudeChanged = _writeBlock(claudeMd, desiredBlock);
    if (claudeChanged) {
      ggLog(
        '  + updated ${p.relative(claudeMd.path, from: target.path)}',
      );
    }

    ggLog(
      'Done. Target: ${target.path}. '
      'Conventions written: ${docs.length} ($copied changed). '
      'CLAUDE.md ${claudeChanged ? "updated" : "unchanged"}.',
    );
  }

  // ===========================================================================
  // Public helpers (also used by tests)
  // ===========================================================================

  /// Locates the workspace root by walking up from [start] until a directory
  /// containing a `.master/` subfolder is found. Returns `null` when no such
  /// directory exists in the chain.
  static Directory? findKidneyWorkspaceRoot(Directory start) {
    var dir = start.absolute;
    while (true) {
      if (Directory(p.join(dir.path, '.master')).existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        return null;
      }
      dir = parent;
    }
  }

  /// Returns all `*.md` files in [source], sorted alphabetically by name.
  static List<File> discoverConventions(Directory source) {
    final result = <File>[];
    for (final entity in source.listSync()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.md')) {
        result.add(entity);
      }
    }
    result.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return result;
  }

  /// Builds the managed `CLAUDE.md` block referencing each [filename] under
  /// `.gg/claude/`. The block is tagged with [version] for downstream tooling.
  static String buildBlock(Iterable<String> filenames, String version) {
    final lines = <String>[
      '$startMarker v=$version -->',
      ...filenames.map((name) => '@.gg/claude/$name'),
      endMarker,
    ];
    return lines.join('\n');
  }

  /// Replaces the existing managed block in [content] with [block], or
  /// appends it when no block is present. Returns the new content.
  static String upsertBlock(String content, String block) {
    final start = content.indexOf(startMarker);
    if (start == -1) {
      // No existing block — append, separated by a blank line.
      final trimmed = content.trimRight();
      if (trimmed.isEmpty) {
        return '$block\n';
      }
      return '$trimmed\n\n$block\n';
    }
    final endIdx = content.indexOf(endMarker, start);
    if (endIdx == -1) {
      throw StateError(
        'Found "$startMarker" without matching "$endMarker" in CLAUDE.md.',
      );
    }
    final before = content.substring(0, start);
    final after = content.substring(endIdx + endMarker.length);
    return '$before$block$after';
  }

  // ===========================================================================
  // Private
  // ===========================================================================

  Directory _resolveSource(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    return Directory(
      p.join(_packageRootResolver(), 'claude', 'conventions'),
    );
  }

  Directory _resolveTarget(String? raw) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    final cwd = Directory.current;
    final workspace = findKidneyWorkspaceRoot(cwd);
    return workspace ?? cwd;
  }

  bool _writeBlock(File claudeMd, String block) {
    final existing = claudeMd.existsSync() ? claudeMd.readAsStringSync() : '';
    final updated = upsertBlock(existing, block);
    if (existing == updated) {
      return false;
    }
    claudeMd.writeAsStringSync(updated);
    return true;
  }

  void _check(
    List<File> docs,
    Directory destDir,
    File claudeMd,
    String desiredBlock,
  ) {
    final problems = <String>[];

    for (final doc in docs) {
      final destFile = File(p.join(destDir.path, p.basename(doc.path)));
      if (!destFile.existsSync()) {
        problems.add('missing: ${destFile.path}');
        continue;
      }
      if (destFile.readAsStringSync() != doc.readAsStringSync()) {
        problems.add('out of date: ${destFile.path}');
      }
    }

    if (!claudeMd.existsSync()) {
      problems.add('missing: ${claudeMd.path}');
    } else {
      final content = claudeMd.readAsStringSync();
      final updated = upsertBlock(content, desiredBlock);
      if (updated != content) {
        problems.add('CLAUDE.md block out of date: ${claudeMd.path}');
      }
    }

    if (problems.isEmpty) {
      ggLog('Conventions are up to date.');
      return;
    }

    for (final problem in problems) {
      ggLog('  - $problem');
    }
    throw Exception(
      'Conventions out of date — run `apply-conventions` to fix.',
    );
  }

  // coverage:ignore-start
  static String _defaultPackageRoot() {
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

  static String _today() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }
}
