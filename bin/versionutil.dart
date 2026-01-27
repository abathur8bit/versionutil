import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

void main(List<String> args) {
  ArgParser parser = ArgParser()
    ..addOption("lang",help:"lang=dart|java|cpp Output language (default: dart)")
    ..addOption("package",help: "package=<com.axorion> Package for java file")
    ..addOption("out",help: "out=<path> Output file path")
    ..addOption("verfile",help: "path=<version.json> Version file to look at")
    ..addFlag("clean",help: "Remove JSON and generated files",negatable: false)
    ..addFlag("help",abbr:"h",help: "Usage help.",negatable: false);
  // --lang=dart|java|cpp   Output language (default: dart)
  // --out=<path>           Output file path
  // --verfile=<path>       Version file to look at
  // --clean                Remove JSON and generated files
  // --help                 Show this help

  final flags = parser.parse(args);
  if(flags.wasParsed("help")) {
    _usage(parser.usage);
    return;
  }

  final versionFile = File('version.json');
  final buildFile = File('version-build.json');

  final lang = flags['lang'] ?? 'dart';
  final outputPath = flags['out'] ?? _defaultOutputPath(lang);
  String? package = flags['package'];

  final outputFile = File(outputPath);

  if (flags['clean']) {
    _clean(versionFile, buildFile, outputFile);
    return;
  }

  if (!versionFile.existsSync()) {
    stderr.writeln('Creating $versionFile');
    createVersionFile(versionFile,0,1,0);
  }
  if(!buildFile.existsSync()) {
    stderr.writeln('Creating $buildFile');
    createBuildFile(buildFile,1);
  }

  final versionData =
  jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
  final buildData =
  jsonDecode(buildFile.readAsStringSync()) as Map<String, dynamic>;

  final int version = versionData['version'];
  final int revision = versionData['revision'];
  final int patch = versionData['patch'];
  final int build = buildData['build'];

  final formattedBuild = build.toString().padLeft(4, '0');
  final formattedRevision = revision.toString().padLeft(2,"0");
  final formattedPatch = patch.toString().padLeft(2,"0");
  final versionString = '$version.$formattedRevision.$formattedPatch.$formattedBuild';

  outputFile.createSync(recursive: true);
  outputFile.writeAsStringSync(_generate(lang, versionString, version, revision, patch, build, package));

  print('Generated $outputPath');
  print('VERSION=$versionString');

  // Increment build
  buildData['build'] = build + 1;
  buildFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(buildData),
  );

  print('Incremented build to ${build + 1}');
}

void _usage(String parserUsage) {
  print('''
Version generator

Usage:
  dart run tool/version_gen.dart [options]

Options:
$parserUsage
''');
}

void createVersionFile(File versionFile, int version, int revision, int patch) {
  Map<String, dynamic> versionData = {"version": version, "revision": revision, "patch": patch};
  versionFile.writeAsStringSync(jsonEncode(versionData).toString());
}

void createBuildFile(File buildFile, int build) {
  Map<String, dynamic> versionData = {"build": build};
  buildFile.writeAsStringSync(jsonEncode(versionData).toString());
}


void _clean(File version, File build, File output) {
  void deleteIfExists(File f) {
    if (f.existsSync()) {
      f.deleteSync();
      print('Deleted ${f.path}');
    }
  }

  deleteIfExists(version);
  deleteIfExists(build);
  deleteIfExists(output);
}

String _generate(String lang, String versionString, int version, int revision, int patch,int build,String? package) {
  switch (lang) {
    case 'dart':
      return '''
/// GENERATED FILE - DO NOT EDIT
const String appVersion = "$versionString";
const int appVersionNumber = $version;
const int appRevision = $revision;
const int appPatch = $patch;
const int appBuild = $build;
''';

    case 'java':
      return '''
${package == null ? "" : "package $package;\n"}
// GENERATED FILE - DO NOT EDIT
public final class Version {
  private Version() {}
  public static final String APP_VERSION = "$versionString";
  public static final int APP_VERSIONNUMBER = $version;
  public static final int APP_REVISION = $revision;
  public static final int APP_PATCH = $patch;
  public static final int APP_BUILD = $build;
}
''';

    case 'cpp':
      return '''
// GENERATED FILE - DO NOT EDIT
#pragma once
#define APP_VERSION "$versionString"
#define APP_VERSIONNUMBER $version;
#define APP_REVISION $revision;
#define APP_PATCH $patch;
#define APP_BUILD $build;
''';

    default:
      stderr.writeln('Unsupported language: $lang');
      exit(2);
  }
}

String _defaultOutputPath(String lang) {
  switch (lang) {
    case 'dart':
      return 'lib/version.dart';
    case 'java':
      return 'Version.java';
    case 'cpp':
      return 'version.h';
    default:
      return 'version.txt';
  }
}

