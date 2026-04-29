// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import './commands/install_skills.dart';
import './commands/my_command.dart';
import 'package:gg_log/gg_log.dart';

/// The command line interface for GgDna
class GgDna extends Command<dynamic> {
  /// Constructor
  GgDna({required this.ggLog}) {
    addSubcommand(MyCommand(ggLog: ggLog));
    addSubcommand(InstallSkills(ggLog: ggLog));
  }

  /// The log function
  final GgLog ggLog;

  // ...........................................................................
  @override
  final name = 'ggDna';
  @override
  final description = 'Add your description here.';
}
