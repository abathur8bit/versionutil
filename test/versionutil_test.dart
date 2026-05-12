import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('generates PHP output', () async {
    final tempDir = Directory.systemTemp.createTempSync('versionutil_php_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final versionBase = '${tempDir.path}${Platform.pathSeparator}version';
    File('$versionBase.json').writeAsStringSync(jsonEncode({
      'version': 1,
      'revision': 9,
      'patch': 1,
    }));
    File('$versionBase-build.json').writeAsStringSync(jsonEncode({
      'build': 101,
    }));

    final outputPath = '${tempDir.path}${Platform.pathSeparator}Version.php';
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        'run',
        'bin/versionutil.dart',
        '--lang=php',
        '--in=$versionBase',
        '--out=$outputPath',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), '1.09.01+0102');
    expect(File(outputPath).readAsStringSync(), '''<?php
// GENERATED FILE - DO NOT EDIT

final class Version
{
    public const APP_VERSION = '1.09.01+0102';
    public const APP_VERSIONNUMBER = 1;
    public const APP_REVISION = 9;
    public const APP_PATCH = 1;
    public const APP_BUILD = 102;
}
''');
  });
}
