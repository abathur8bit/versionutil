Command line application that produces Semantic Versioning ([SemVer](https://semver.org/)) versions with MAJOR.MINOR.PATCH[-prerelease][+build]. Actual version string would look like a.bb.cc-alpha.N+dddd. Note that 0's are padded so output file will be sorted correctly, which goes against the SemVer rules. 

Version files based on version json and build. Every time you run `versionutil` it will update the build number in `version-build.json` and output to the version file of your choice, and optionally update a pom.xml file. 

real.json and real-build.json are for the actual project version info, as when running during testing, the normal output files are generated.

```
dart run bin/versionutil.dart --in=real --out=lib\versionutil_version.dart
```

version.json:
```
{"version":0,"revision":1,"patch":0}
```

version-build.json:
```
{"build":2}
```

- Modify pom.xml file version tag
- revision # should be padded to "00"
- Support major.minor.patch.build

If the "preRelease" exists, then the appVersion will be 