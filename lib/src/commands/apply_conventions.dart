// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:path/path.dart' as p;

/// Copies the convention documents shipped under
/// `<target>/dna/agents/conventions/` into `<target>/.claude/conventions/`
/// and ensures the target's `CLAUDE.md` references them through
/// `@import`-lines inside a delimited block.
///
/// When the command is executed inside a Kidney workspace (a directory
/// containing `.master/`, walked up from the current working directory),
/// the workspace root is used as the target instead of the current directory.
class ApplyConventions extends Command<dynamic> {
  /// Constructor.
  ApplyConventions({required this.ggLog}) {
    argParser
      ..addOption(
        'source',
        abbr: 's',
        help: 'Folder containing the convention markdown files. Defaults to '
            '<target>/dna/agents/conventions.',
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target repo or workspace folder. Defaults to the current '
            'directory; if executed inside a Kidney workspace, the workspace '
            'root is used instead.',
      )
      ..addMultiOption(
        'only',
        abbr: 'o',
        help: 'Apply only the named convention files (basename, e.g. '
            '"code-conventions.md"). Repeat or comma-separate.',
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

  /// Marker that opens the managed `CLAUDE.md` block.
  static const String startMarker = '<!-- gg_dna:conventions:start';

  /// Marker that closes the managed `CLAUDE.md` block.
  static const String endMarker = '<!-- gg_dna:conventions:end -->';

  /// Path prefix used inside `CLAUDE.md` `@`-imports for managed conventions.
  static const String importPrefix = '.claude/conventions';

  @override
  final name = 'apply-conventions';

  @override
  final description = 'Copy Grace Cloud convention docs from '
      '<target>/dna/agents/conventions into <target>/.claude/conventions and '
      'reference them via @import-lines in <target>/CLAUDE.md.';

  @override
  Future<void> run() async {
    final target = _resolveTarget(argResults!['target'] as String?);
    final source = _resolveSource(argResults!['source'] as String?, target);
    final only = (argResults!['only'] as List<String>)
        .where((s) => s.trim().isNotEmpty)
        .toSet();
    final checkOnly = argResults!['check'] as bool;

    if (!source.existsSync()) {
      throw UsageException(
        'Conventions source folder does not exist: ${source.path}',
        usage,
      );
    }

    var docs = discoverConventions(source);
    if (only.isNotEmpty) {
      docs = docs
          .where((f) => only.contains(p.basename(f.path)))
          .toList(growable: false);
    }
    if (docs.isEmpty) {
      throw UsageException(
        'No matching convention markdown files found in ${source.path}.',
        usage,
      );
    }

    final destDir = Directory(p.join(target.path, '.claude', 'conventions'));
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
  /// `.claude/conventions/`. The block is tagged with [version] for downstream
  /// tooling.
  static String buildBlock(Iterable<String> filenames, String version) {
    final lines = <String>[
      '$startMarker v=$version -->',
      ...filenames.map((name) => '@$importPrefix/$name'),
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

  Directory _resolveSource(String? raw, Directory target) {
    if (raw != null && raw.isNotEmpty) {
      return Directory(raw);
    }
    return Directory(
      p.join(target.path, 'dna', 'agents', 'conventions'),
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

  static String _today() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }
}
