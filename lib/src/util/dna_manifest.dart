// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dna_hash.dart';

/// Sync manifest written to `<target>/dna/.dna.json` after every successful
/// `gg_dna sync`. Stores enough information for a later `--check` to verify
/// the target is still in sync with the source without re-doing the full
/// file walk.
class DnaManifest {
  /// Constructor.
  const DnaManifest({
    this.overlay,
    this.overlayCommit,
    this.overlayHash,
    this.baseVersion,
    this.baseHash,
    this.hash,
  });

  /// The overlay argument (git URL, gg_* shorthand, or local path) that was
  /// used during the last sync. `null` if no overlay was applied.
  final String? overlay;

  /// Commit SHA of the overlay that was cloned during the last sync. `null`
  /// for local-path overlays or when no overlay was applied.
  final String? overlayCommit;

  /// Content hash of the overlay's `dna/` folder at sync time. Used to detect
  /// changes when the overlay is a local path (where no commit SHA exists).
  /// `null` when no overlay was applied.
  final String? overlayHash;

  /// `version:` field of the gg_dna package that produced the last sync.
  final String? baseVersion;

  /// Content hash of the gg_dna package's `dna/` folder at sync time.
  final String? baseHash;

  /// Content hash of `<target>/dna/` after the sync (overlay merged in).
  final String? hash;

  /// Reads the manifest at `<dnaDir>/.dna.json`. Returns `null` when the
  /// file does not exist or cannot be parsed as JSON.
  static DnaManifest? read(Directory dnaDir) {
    final file = File(p.join(dnaDir.path, dnaManifestFilename));
    if (!file.existsSync()) return null;
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return DnaManifest(
        overlay: data['overlay'] as String?,
        overlayCommit: data['overlayCommit'] as String?,
        overlayHash: data['overlayHash'] as String?,
        baseVersion: data['baseVersion'] as String?,
        baseHash: data['baseHash'] as String?,
        hash: data['hash'] as String?,
      );
    } on FormatException {
      return null;
    }
  }

  /// Writes `this` to `<dnaDir>/.dna.json` as pretty-printed JSON.
  void write(Directory dnaDir) {
    final file = File(p.join(dnaDir.path, dnaManifestFilename));
    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('${encoder.convert(toJson())}\n');
  }

  /// JSON representation used by [write] and tests.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'overlay': overlay,
        'overlayCommit': overlayCommit,
        'overlayHash': overlayHash,
        'baseVersion': baseVersion,
        'baseHash': baseHash,
        'hash': hash,
      };
}

/// Returns the `version:` field from the `pubspec.yaml` at [packageRoot], or
/// `null` when the file does not exist or no version line is present.
///
/// Uses a simple regex so the package does not need a yaml dependency just
/// for this read.
String? readPackageVersion(String packageRoot) {
  final file = File(p.join(packageRoot, 'pubspec.yaml'));
  if (!file.existsSync()) return null;
  final match = RegExp(r'^version:\s*(.+)$', multiLine: true)
      .firstMatch(file.readAsStringSync());
  return match?.group(1)?.trim();
}
