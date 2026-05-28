// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:gg_hash/gg_hash.dart';
import 'package:path/path.dart' as p;

/// Filename that holds the sync manifest inside `<target>/dna/`.
const String dnaManifestFilename = '.dna.json';

/// Computes a stable content hash for the directory tree at [dir].
///
/// The hash combines, for every regular file under [dir] (recursive, sorted
/// by relative path with forward slashes), the relative path bytes and the
/// file bytes via [fnv1].
///
/// The manifest file [dnaManifestFilename] at the root of [dir] is **always
/// excluded** so the manifest can store the hash without becoming circular.
///
/// Returns `null` when [dir] does not exist.
String? hashDnaDirectory(Directory dir) {
  if (!dir.existsSync()) return null;
  final base = dir.absolute.path;
  final entries = <(String, File)>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: base).replaceAll('\\', '/');
    if (rel == dnaManifestFilename) continue;
    entries.add((rel, entity));
  }
  entries.sort((a, b) => a.$1.compareTo(b.$1));

  final perFile = <int>[];
  for (final (rel, file) in entries) {
    final pathHash = fnv1(utf8.encode(rel));
    final contentHash = fnv1(file.readAsBytesSync());
    perFile.add(pathHash);
    perFile.add(contentHash);
  }
  final folded = fnv1(perFile);
  return _toHex(folded);
}

String _toHex(int value) {
  // Dart ints are 64 bit on the VM; mask to 64 bit before printing.
  final masked = value.toUnsigned(64);
  return '0x${masked.toRadixString(16).padLeft(16, '0')}';
}
