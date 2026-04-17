import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:xml/xml.dart';

import 'package:versionutil/versionutil_version.dart';

bool get isCompiledExecutable {
  final exe = Platform.resolvedExecutable.toLowerCase();
  return !exe.endsWith('dart') && !exe.endsWith('dart.exe');
}
bool get isRunningFromDartRun => !isCompiledExecutable;
String executable = 'versionutil';  //default to an executable

void main(List<String> args) {
    ArgParser parser = ArgParser()
    ..addOption("lang",help:"lang=dart|java|cpp Output language (default: dart)")
    ..addOption("package",help: "package=<com.axorion> Package for java file")
    ..addOption("out",help: "out=<path> Output file path")
    ..addOption("pom",help: "pom=<pom.xml> Update pom.xml <version> tag")
    ..addOption("in",help: "in=<version> Version file <in>.json and <in>-build.json to look at. Defaults to 'version'")
    ..addFlag("build",help: "Include the build number in the version output", defaultsTo: true)
    ..addFlag("prerelease",help: "Include preRelease info in version-build.json")
    ..addFlag("clean",help: "Remove JSON and generated files",negatable: false)
    ..addFlag("show",abbr:'s', help: "Just show the formatted version, don't generate or change anything",negatable: false)
    ..addFlag("verbose",abbr:'v', help: "Output generation information",negatable: false)
    ..addFlag("strict",help:"Strict SemVer format, 1.0.0 instead of 1.00.00")
    ..addFlag("help",abbr:"h",help: "Usage help.",negatable: false);

  final flags = parser.parse(args);
  if(flags.wasParsed("help")) {
    _printUsage(parser);
    return;
  }

  final versionFilename = flags['in'] ?? 'version';
  final versionFile = File('${versionFilename}.json');
  final buildFile = File('${versionFilename}-build.json');
  final verbose = flags['verbose'];
  final lang = flags['lang'] ?? 'dart';
  final preRelease = flags['prerelease'];
  final outputPath = flags['out'] ?? _defaultOutputPath(lang);
  String? package = flags['package'];
  final pomPath = flags['pom'];

  final outputFile = File(outputPath);

  if (flags['clean']) {
    _clean(versionFile, buildFile, outputFile);
    return;
  }

  if (!versionFile.existsSync()) {
    if(verbose) stdout.writeln('Creating $versionFile');
    createVersionFile(versionFile,0,1,0);
  }
  if(!buildFile.existsSync()) {
    if(verbose) stdout.writeln('Creating $buildFile');
    createBuildFile(buildFile,0,preRelease);
  }

  final versionData = jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
  final buildData = jsonDecode(buildFile.readAsStringSync()) as Map<String, dynamic>;
  final strict = (flags.wasParsed("strict") ? flags['strict'] : null) ?? versionData['strict'] ?? false;
  final buildNumber = (flags.wasParsed("build") ? flags['build'] : null) ?? versionData['build'] ?? true;
  final int version = versionData['version'];
  final int revision = versionData['revision'];
  final int patch = versionData['patch'];
  int? prenum = buildData['preRelease'] != null ? buildData['preRelease']['num']:null;
  String? pretag = buildData['preRelease'] != null ? buildData['preRelease']['tag']:null;
  int build = buildData['build'];

  // inc the build number
  if(!flags['show']) build = incBuild(buildData, buildFile, verbose);

  //format and output the build info
  final formattedBuild = strict ? build.toString() : build.toString().padLeft(4, '0');
  final formattedRevision = strict ? revision.toString() : revision.toString().padLeft(2,"0");
  final formattedPatch = strict ? patch.toString() : patch.toString().padLeft(2,"0");
  final versionString = prenum != null && pretag != null
      ? '$version.$formattedRevision.$formattedPatch-$pretag.$prenum+$formattedBuild'
      : '$version.$formattedRevision.$formattedPatch${buildNumber ? '+$formattedBuild' : ''}';

  if(flags['show']) {
    print(versionString);
    exit(0);
  }

  outputFile.createSync(recursive: true);
  outputFile.writeAsStringSync(_generate(lang, versionString, version, revision, patch, build, package));

  if(verbose) print('Generated $outputPath');

  if (pomPath != null) {
    _updatePomVersion(File(pomPath), versionString);
    if(verbose) print('Updated ${pomPath} <version> to $versionString');
  }

  print(versionString);
}

int incBuild(Map<String, dynamic> buildData,File buildFile,bool verbose) {
  // Increment build
  buildData['build']++;
  buildFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(buildData),
  );

  if(verbose) print('Incremented build to ${buildData['build'] + 1}');

  return buildData['build'];
}

void _printUsage(ArgParser parser) {
  if(isRunningFromDartRun) {
    executable = "dart run bin/versionutil.dart"; //running from dart, not an executable
  }
  stdout.writeln("A command-line utility for generating an application version file using modified or strict SemVer numbering rules.");
  stdout.writeln("Version: $appVersion");
  stdout.writeln("");
  stdout.writeln("Homepage: https://weatheredhiker.com/pages/versionutil.html");
  stdout.writeln("Source  : https://github.com/abathur8bit/versionutil");
  stdout.writeln("Issues  : https://github.com/abathur8bit/versionutil/issues");
  stdout.writeln("");
  stdout.writeln("Usage: $executable [options]");
  stdout.writeln("");
  stdout.writeln(parser.usage);
}

void createVersionFile(File versionFile, int version, int revision, int patch) {
  Map<String, dynamic> versionData = {"version": version, "revision": revision, "patch": patch};
  versionFile.writeAsStringSync(jsonEncode(versionData).toString());
}

void createBuildFile(File buildFile, int build, bool preRelease) {
  Map<String, dynamic> versionData = {"build": build};
  if(preRelease) {
    versionData["preRelease"] = {"tag":"alpha","num":1};
  }
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

void _updatePomVersion(File pomFile, String versionString) {
  if (!pomFile.existsSync()) {
    stderr.writeln('Pom file not found: ${pomFile.path}');
    exit(2);
  }

  final contents = pomFile.readAsStringSync();
  final document = XmlDocument.parse(contents);
  final project = document.rootElement;
  if (project.name.local != 'project') {
    stderr.writeln('Root element is not <project> in ${pomFile.path}');
    exit(2);
  }

  final versionElements = project.findElements('version');
  if (versionElements.isEmpty) {
    stderr.writeln('No <project><version> tag found in ${pomFile.path}');
    exit(2);
  }

  versionElements.first.innerText = versionString;
  pomFile.writeAsStringSync(document.toXmlString(pretty: true));
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
