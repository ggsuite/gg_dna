// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_dna/src/util/dna_manifest.dart';
import 'package:test/test.dart';

void main() {
  group('DnaManifest', () {
    test('read returns null when the manifest file is missing', () {
      final tmp = Directory.systemTemp.createTempSync('gg_dna_manifest_');
      try {
        expect(DnaManifest.read(tmp), isNull);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('write and read round-trip preserves all fields', () {
      final tmp = Directory.systemTemp.createTempSync('gg_dna_manifest_');
      try {
        const original = DnaManifest(
          overlay: 'gg_foo',
          overlayCommit: 'abc123',
          overlayHash: '0xdeadbeef',
          baseVersion: '1.2.3',
          baseHash: '0xcafef00d',
          hash: '0x0000000000000001',
        );
        original.write(tmp);
        final loaded = DnaManifest.read(tmp);
        expect(loaded, isNotNull);
        expect(loaded!.toJson(), equals(original.toJson()));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('read returns null on invalid JSON', () {
      final tmp = Directory.systemTemp.createTempSync('gg_dna_manifest_');
      try {
        File('${tmp.path}/.dna.json').writeAsStringSync('not json');
        expect(DnaManifest.read(tmp), isNull);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('readPackageVersion', () {
    test('returns null when pubspec.yaml is missing', () {
      final tmp = Directory.systemTemp.createTempSync('gg_dna_version_');
      try {
        expect(readPackageVersion(tmp.path), isNull);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('returns the version field from pubspec.yaml', () {
      final tmp = Directory.systemTemp.createTempSync('gg_dna_version_');
      try {
        File('${tmp.path}/pubspec.yaml').writeAsStringSync(
          'name: foo\nversion: 4.5.6\n',
        );
        expect(readPackageVersion(tmp.path), equals('4.5.6'));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });
}
